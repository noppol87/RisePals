namespace RisePals.ServiceHost;

public sealed class ServiceOrchestrator : IAsyncDisposable
{
    private const uint StopFailureCode = 0x5250_0001;
    private const uint RestartLimitCode = 0x5250_0002;
    private const uint StopBeforeReadyCode = 0x5250_0004;
    private static readonly TimeSpan StartupCleanupTimeout = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan JobEmptyProbeInterval = TimeSpan.FromMilliseconds(25);

    private readonly IServiceStatusReporter _status;
    private readonly IServiceClock _clock;
    private readonly IReleaseConfigurationResolver _configurationResolver;
    private readonly Func<INodeChildProcess> _childFactory;
    private readonly Func<IProcessTreeOwner> _jobFactory;
    private readonly Func<string, IDrainTransport> _drainFactory;
    private readonly ISanitizedEvidenceSink _evidence;
    private readonly CancellationTokenSource _lifetime = new();
    private readonly SemaphoreSlim _transition = new(1, 1);
    private ReleaseConfiguration? _configuration;
    private INodeChildProcess? _child;
    private IProcessTreeOwner? _job;
    private IDrainTransport? _drain;
    private Task? _monitorTask;
    private Task? _stopTask;
    private uint _checkpoint;
    private int _restartFailures;
    private int _stopRequested;
    private int _terminalStatusReported;
    private bool _cleanupUnproven;
    private DateTimeOffset _lastHealthyAt;

    public ServiceOrchestrator(
        IServiceStatusReporter status,
        IServiceClock clock,
        IReleaseConfigurationResolver configurationResolver,
        Func<INodeChildProcess> childFactory,
        Func<IProcessTreeOwner> jobFactory,
        Func<string, IDrainTransport> drainFactory,
        ISanitizedEvidenceSink evidence)
    {
        _status = status;
        _clock = clock;
        _configurationResolver = configurationResolver;
        _childFactory = childFactory;
        _jobFactory = jobFactory;
        _drainFactory = drainFactory;
        _evidence = evidence;
    }

    public bool IsStopping => Volatile.Read(ref _stopRequested) != 0;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        ReportPending(ServiceLifecycleState.StartPending, TimeSpan.FromSeconds(30));
        _configuration = _configurationResolver.Resolve();
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, _lifetime.Token);
        try
        {
            await StartWithRestartPolicyAsync(linked.Token).ConfigureAwait(false);
            if (IsStopping)
            {
                return;
            }

            _lastHealthyAt = _clock.UtcNow;
            _status.Report(new ServiceStatusUpdate(ServiceLifecycleState.Running, 0, TimeSpan.Zero));
            _monitorTask = MonitorChildAsync(_lifetime.Token);
        }
        catch (OperationCanceledException) when (IsStopping)
        {
            // StopCoreAsync owns the terminal transition after the failed local
            // startup transaction has completed its cleanup.
        }
    }

    public Task StopAsync(bool preshutdown, CancellationToken cancellationToken)
    {
        lock (_lifetime)
        {
            if (_stopTask is not null)
            {
                return _stopTask;
            }

            Interlocked.Exchange(ref _stopRequested, 1);
            _lifetime.Cancel();
            return _stopTask = StopCoreAsync(preshutdown, cancellationToken);
        }
    }

    private async Task StopCoreAsync(bool preshutdown, CancellationToken cancellationToken)
    {
        var configuration = _configuration ?? throw new InvalidOperationException("The service has not started.");
        await _transition.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_cleanupUnproven)
            {
                throw new ServiceHostCleanupException();
            }

            if (_child is null || _job is null || _drain is null)
            {
                if (Volatile.Read(ref _terminalStatusReported) == 0)
                {
                    ReportPending(ServiceLifecycleState.StopPending, StartupCleanupTimeout);
                    ReportTerminalStopped(StopBeforeReadyCode);
                }

                return;
            }

            var child = _child;
            var job = _job;
            var drain = _drain;
            ReportPending(ServiceLifecycleState.StopPending, configuration.DrainTimeout + configuration.ExitTimeout);
            var nonce = Guid.NewGuid().ToString("N");
            var graceful = false;

            try
            {
                var acknowledgement = await drain.BeginDrainAsync(nonce, configuration.DrainTimeout, cancellationToken)
                    .ConfigureAwait(false);
                if (acknowledgement.State != DrainState.Drained || acknowledgement.ActiveCount != 0)
                {
                    throw new DrainProtocolException("Drain acknowledgement did not prove zero active work.");
                }

                ReportPending(ServiceLifecycleState.StopPending, configuration.ExitTimeout);
                var stopped = await drain.RequestStopAsync(nonce, configuration.ExitTimeout, cancellationToken)
                    .ConfigureAwait(false);
                if (stopped.State != DrainState.Stopped)
                {
                    throw new DrainProtocolException("The child did not acknowledge Stopped.");
                }

                await child.RequestExitAsync(cancellationToken).ConfigureAwait(false);
                await child.Completion.WaitAsync(configuration.ExitTimeout, cancellationToken).ConfigureAwait(false);
                graceful = true;
            }
            catch (Exception exception) when (exception is not OperationCanceledException || !cancellationToken.IsCancellationRequested)
            {
                _evidence.Record(
                    new ServiceEvidenceEvent(
                        ServiceEvidenceEventName.StopFailed,
                        ClassifyOperationalFailure(exception),
                        Count: 1));
                await job.TerminateAsync(StopFailureCode, CancellationToken.None).ConfigureAwait(false);
                await child.TerminateAsync(StopFailureCode, CancellationToken.None).ConfigureAwait(false);
            }

            if (!await WaitForEmptyJobAsync(job, configuration.ExitTimeout).ConfigureAwait(false))
            {
                _cleanupUnproven = true;
                _evidence.Record(
                    new ServiceEvidenceEvent(
                        ServiceEvidenceEventName.OwnedProcessCleanupFailed,
                        ServiceEvidenceOutcome.CleanupUnproven,
                        Count: 1));
                throw new ServiceHostCleanupException();
            }

            _child = null;
            _job = null;
            _drain = null;
            await drain.DisposeAsync().ConfigureAwait(false);
            await child.DisposeAsync().ConfigureAwait(false);
            await job.DisposeAsync().ConfigureAwait(false);
            _status.Report(
                new ServiceStatusUpdate(
                    ServiceLifecycleState.Stopped,
                    0,
                    TimeSpan.Zero,
                    graceful ? 0u : 1u,
                    graceful ? 0u : StopFailureCode));
            Interlocked.Exchange(ref _terminalStatusReported, 1);
        }
        finally
        {
            _transition.Release();
        }
    }

    private async Task StartWithRestartPolicyAsync(CancellationToken cancellationToken)
    {
        var configuration = _configuration ?? throw new InvalidOperationException("Configuration is unavailable.");
        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                await _transition.WaitAsync(cancellationToken).ConfigureAwait(false);
                try
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    if (IsStopping)
                    {
                        throw new OperationCanceledException(cancellationToken);
                    }

                    await StartChildTransactionAsync(cancellationToken).ConfigureAwait(false);
                    return;
                }
                finally
                {
                    _transition.Release();
                }
            }
            catch (StartupAttemptException exception)
            {
                _restartFailures++;
                _evidence.Record(
                    new ServiceEvidenceEvent(
                        ServiceEvidenceEventName.ChildStartupFailed,
                        exception.Outcome,
                        Count: _restartFailures));
                if (_restartFailures > configuration.RestartLimit)
                {
                    _evidence.Record(
                        new ServiceEvidenceEvent(
                            ServiceEvidenceEventName.ChildTerminalFailure,
                            ServiceEvidenceOutcome.RestartLimitReached,
                            Count: _restartFailures));
                    ReportTerminalStopped(RestartLimitCode);
                    throw new ServiceHostTerminalException("The bounded child-startup restart limit was reached.");
                }

                await DelayForRestartAsync(configuration, cancellationToken).ConfigureAwait(false);
            }
        }
    }

    private async Task StartChildTransactionAsync(CancellationToken cancellationToken)
    {
        var configuration = _configuration ?? throw new InvalidOperationException("Configuration is unavailable.");
        var pipeName = $"RisePals.ServiceHost.v1.{Guid.NewGuid():N}";
        INodeChildProcess? child = null;
        IProcessTreeOwner? job = null;
        IDrainTransport? drain = null;
        var stage = StartupStage.ChildCreation;
        var assignmentAttempted = false;

        try
        {
            job = _jobFactory();
            child = _childFactory();
            drain = _drainFactory(pipeName);
            await child.StartAsync(configuration, pipeName, cancellationToken).ConfigureAwait(false);

            stage = StartupStage.JobAssignment;
            assignmentAttempted = true;
            await job.AssignAsync(child.ProcessId, cancellationToken).ConfigureAwait(false);

            stage = StartupStage.Resume;
            await child.ResumeAsync(cancellationToken).ConfigureAwait(false);

            stage = StartupStage.Ready;
            await drain.WaitForReadyAsync(configuration.StartTimeout, cancellationToken).ConfigureAwait(false);
            cancellationToken.ThrowIfCancellationRequested();
            if (IsStopping)
            {
                throw new OperationCanceledException(cancellationToken);
            }

            _child = child;
            _job = job;
            _drain = drain;
            _evidence.Record(
                new ServiceEvidenceEvent(
                    ServiceEvidenceEventName.ChildReady,
                    ServiceEvidenceOutcome.Ready,
                    Count: _restartFailures + 1));
        }
        catch (Exception exception)
        {
            var cleanupProven = await CleanupAttemptAsync(child, job, drain, assignmentAttempted).ConfigureAwait(false);
            if (!cleanupProven)
            {
                _cleanupUnproven = true;
                _evidence.Record(
                    new ServiceEvidenceEvent(
                        ServiceEvidenceEventName.OwnedProcessCleanupFailed,
                        ServiceEvidenceOutcome.CleanupUnproven,
                        Count: 1));
                throw new ServiceHostCleanupException();
            }

            if (exception is OperationCanceledException)
            {
                throw;
            }

            throw new StartupAttemptException(ToEvidenceOutcome(stage));
        }
    }

    private async Task<bool> CleanupAttemptAsync(
        INodeChildProcess? child,
        IProcessTreeOwner? job,
        IDrainTransport? drain,
        bool assignmentAttempted)
    {
        var cleanupSucceeded = true;
        if (drain is not null)
        {
            try
            {
                await drain.DisposeAsync().ConfigureAwait(false);
            }
            catch
            {
                cleanupSucceeded = false;
            }
        }

        if (assignmentAttempted && job is not null)
        {
            try
            {
                await job.TerminateAsync(RestartLimitCode, CancellationToken.None).ConfigureAwait(false);
            }
            catch
            {
                cleanupSucceeded = false;
            }
        }

        if (child is not null)
        {
            try
            {
                await child.TerminateAsync(RestartLimitCode, CancellationToken.None).ConfigureAwait(false);
            }
            catch
            {
                cleanupSucceeded = false;
            }
        }

        var empty = job is null || await WaitForEmptyJobAsync(job, StartupCleanupTimeout).ConfigureAwait(false);

        if (child is not null)
        {
            try
            {
                await child.DisposeAsync().ConfigureAwait(false);
            }
            catch
            {
                cleanupSucceeded = false;
            }
        }

        if (job is not null)
        {
            try
            {
                await job.DisposeAsync().ConfigureAwait(false);
            }
            catch
            {
                cleanupSucceeded = false;
            }
        }

        return cleanupSucceeded && empty;
    }

    private async Task MonitorChildAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            var child = _child;
            var configuration = _configuration;
            if (child is null || configuration is null)
            {
                return;
            }

            try
            {
                _ = await child.Completion.WaitAsync(cancellationToken).ConfigureAwait(false);
                if (cancellationToken.IsCancellationRequested || IsStopping)
                {
                    return;
                }

                await _transition.WaitAsync(cancellationToken).ConfigureAwait(false);
                try
                {
                    if (cancellationToken.IsCancellationRequested || IsStopping)
                    {
                        return;
                    }

                    var activeChild = _child ?? throw new InvalidOperationException("The active child disappeared during restart cleanup.");
                    var activeJob = _job ?? throw new InvalidOperationException("The active Job Object disappeared during restart cleanup.");
                    var activeDrain = _drain ?? throw new InvalidOperationException("The active drain disappeared during restart cleanup.");
                    _child = null;
                    _job = null;
                    _drain = null;
                    if (!await CleanupAttemptAsync(activeChild, activeJob, activeDrain, true).ConfigureAwait(false))
                    {
                        _cleanupUnproven = true;
                        _evidence.Record(
                            new ServiceEvidenceEvent(
                                ServiceEvidenceEventName.OwnedProcessCleanupFailed,
                                ServiceEvidenceOutcome.CleanupUnproven,
                                Count: 1));
                        throw new ServiceHostCleanupException();
                    }
                }
                finally
                {
                    _transition.Release();
                }

                _evidence.Record(
                    new ServiceEvidenceEvent(
                        ServiceEvidenceEventName.ChildUnexpectedExit,
                        ServiceEvidenceOutcome.UnexpectedExit,
                        Count: 1));
                if (_clock.UtcNow - _lastHealthyAt >= configuration.HealthyResetInterval)
                {
                    _restartFailures = 0;
                }

                _restartFailures++;
                if (_restartFailures > configuration.RestartLimit)
                {
                    _evidence.Record(
                        new ServiceEvidenceEvent(
                            ServiceEvidenceEventName.ChildTerminalFailure,
                            ServiceEvidenceOutcome.RestartLimitReached,
                            Count: _restartFailures));
                    ReportTerminalStopped(RestartLimitCode);
                    return;
                }

                await DelayForRestartAsync(configuration, cancellationToken).ConfigureAwait(false);
                await StartWithRestartPolicyAsync(cancellationToken).ConfigureAwait(false);
                _lastHealthyAt = _clock.UtcNow;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested || IsStopping)
            {
                return;
            }
            catch (ServiceHostTerminalException)
            {
                return;
            }
            catch (ServiceHostCleanupException)
            {
                return;
            }
        }
    }

    private async Task DelayForRestartAsync(ReleaseConfiguration configuration, CancellationToken cancellationToken)
    {
        var delayMilliseconds = Math.Min(
            configuration.InitialRestartDelay.TotalMilliseconds * Math.Pow(2, Math.Max(0, _restartFailures - 1)),
            configuration.MaximumRestartDelay.TotalMilliseconds);
        _evidence.Record(
            new ServiceEvidenceEvent(
                ServiceEvidenceEventName.ChildRestartScheduled,
                ServiceEvidenceOutcome.RestartScheduled,
                Count: _restartFailures));
        await _clock.DelayAsync(TimeSpan.FromMilliseconds(delayMilliseconds), cancellationToken).ConfigureAwait(false);
    }

    private void ReportPending(ServiceLifecycleState state, TimeSpan waitHint)
    {
        _checkpoint++;
        _status.Report(new ServiceStatusUpdate(state, _checkpoint, waitHint));
    }

    private void ReportTerminalStopped(uint serviceSpecificExitCode)
    {
        if (_cleanupUnproven)
        {
            throw new ServiceHostCleanupException();
        }

        if (Interlocked.Exchange(ref _terminalStatusReported, 1) == 0)
        {
            _status.Report(new ServiceStatusUpdate(ServiceLifecycleState.Stopped, 0, TimeSpan.Zero, 1, serviceSpecificExitCode));
        }
    }

    private async Task<bool> WaitForEmptyJobAsync(IProcessTreeOwner job, TimeSpan timeout)
    {
        var probes = Math.Max(1, checked((int)Math.Ceiling(timeout.TotalMilliseconds / JobEmptyProbeInterval.TotalMilliseconds)));
        for (var probe = 0; probe < probes; probe++)
        {
            if (await job.IsEmptyAsync(CancellationToken.None).ConfigureAwait(false))
            {
                return true;
            }

            await _clock.DelayAsync(JobEmptyProbeInterval, CancellationToken.None).ConfigureAwait(false);
        }

        return await job.IsEmptyAsync(CancellationToken.None).ConfigureAwait(false);
    }

    private static ServiceEvidenceOutcome ToEvidenceOutcome(StartupStage stage) => stage switch
    {
        StartupStage.ChildCreation => ServiceEvidenceOutcome.ChildCreationFailed,
        StartupStage.JobAssignment => ServiceEvidenceOutcome.JobAssignmentFailed,
        StartupStage.Resume => ServiceEvidenceOutcome.ResumeFailed,
        StartupStage.Ready => ServiceEvidenceOutcome.ReadyFailed,
        _ => throw new ArgumentOutOfRangeException(nameof(stage)),
    };

    private static ServiceEvidenceOutcome ClassifyOperationalFailure(Exception exception) => exception switch
    {
        TimeoutException => ServiceEvidenceOutcome.Timeout,
        DrainProtocolException => ServiceEvidenceOutcome.ProtocolFailed,
        IOException => ServiceEvidenceOutcome.ProtocolFailed,
        _ => ServiceEvidenceOutcome.ProcessFailed,
    };

    public async ValueTask DisposeAsync()
    {
        Interlocked.Exchange(ref _stopRequested, 1);
        _lifetime.Cancel();
        if (_monitorTask is not null)
        {
            try
            {
                await _monitorTask.ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                // Expected during controlled disposal.
            }
        }

        await _transition.WaitAsync(CancellationToken.None).ConfigureAwait(false);
        try
        {
            if (_child is not null || _job is not null || _drain is not null)
            {
                _ = await CleanupAttemptAsync(_child, _job, _drain, _job is not null).ConfigureAwait(false);
                _child = null;
                _job = null;
                _drain = null;
            }
        }
        finally
        {
            _transition.Release();
            _transition.Dispose();
            _lifetime.Dispose();
        }
    }

    private enum StartupStage
    {
        ChildCreation,
        JobAssignment,
        Resume,
        Ready,
    }

    private sealed class StartupAttemptException(ServiceEvidenceOutcome outcome) : Exception
    {
        public ServiceEvidenceOutcome Outcome { get; } = outcome;
    }
}
