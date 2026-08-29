namespace RisePals.ServiceHost;

public sealed class ServiceOrchestrator : IAsyncDisposable
{
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

    public bool IsStopping => _stopTask is not null;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        ReportPending(ServiceLifecycleState.StartPending, TimeSpan.FromSeconds(30));
        _configuration = _configurationResolver.Resolve();
        _job = _jobFactory();
        await StartChildAsync(cancellationToken).ConfigureAwait(false);
        _lastHealthyAt = _clock.UtcNow;
        _status.Report(new ServiceStatusUpdate(ServiceLifecycleState.Running, 0, TimeSpan.Zero));
        _monitorTask = MonitorChildAsync(_lifetime.Token);
    }

    public Task StopAsync(bool preshutdown, CancellationToken cancellationToken)
    {
        lock (_lifetime)
        {
            return _stopTask ??= StopCoreAsync(preshutdown, cancellationToken);
        }
    }

    private async Task StopCoreAsync(bool preshutdown, CancellationToken cancellationToken)
    {
        _lifetime.Cancel();
        var configuration = _configuration ?? throw new InvalidOperationException("The service has not started.");
        var child = _child ?? throw new InvalidOperationException("The service has no owned child.");
        var job = _job ?? throw new InvalidOperationException("The service has no Job Object.");
        var drain = _drain ?? throw new InvalidOperationException("The service has no drain transport.");

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
        catch (Exception exception) when (exception is TimeoutException or IOException or DrainProtocolException)
        {
            _evidence.Record(
                "service.stop.timeout",
                new Dictionary<string, object?> { ["preshutdown"] = preshutdown, ["category"] = exception.GetType().Name });
            await job.TerminateAsync(0x5250_0001, CancellationToken.None).ConfigureAwait(false);
        }

        if (!await WaitForEmptyJobAsync(job, configuration.ExitTimeout).ConfigureAwait(false))
        {
            _evidence.Record("service.stop.owned-processes-remain", new Dictionary<string, object?>());
            throw new InvalidOperationException("Stopped cannot be reported while the owned Job Object is non-empty.");
        }

        _status.Report(
            new ServiceStatusUpdate(
                ServiceLifecycleState.Stopped,
                0,
                TimeSpan.Zero,
                graceful ? 0u : 1u,
                graceful ? 0u : 0x5250_0001));
    }

    private async Task StartChildAsync(CancellationToken cancellationToken)
    {
        var configuration = _configuration ?? throw new InvalidOperationException("Configuration is unavailable.");
        var job = _job ?? throw new InvalidOperationException("Job Object is unavailable.");
        var pipeName = $"RisePals.ServiceHost.v1.{Guid.NewGuid():N}";
        var child = _childFactory();
        var drain = _drainFactory(pipeName);

        await child.StartAsync(configuration, pipeName, cancellationToken).ConfigureAwait(false);
        await job.AssignAsync(child.ProcessId, cancellationToken).ConfigureAwait(false);
        await child.ResumeAsync(cancellationToken).ConfigureAwait(false);
        await drain.WaitForReadyAsync(configuration.StartTimeout, cancellationToken).ConfigureAwait(false);

        _child = child;
        _drain = drain;
        _evidence.Record("service.child.ready", new Dictionary<string, object?> { ["attempt"] = _restartFailures + 1 });
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
                var exitCode = await child.Completion.WaitAsync(cancellationToken).ConfigureAwait(false);
                if (cancellationToken.IsCancellationRequested)
                {
                    return;
                }

                _evidence.Record("service.child.unexpected-exit", new Dictionary<string, object?> { ["exitCode"] = exitCode });
                if (_clock.UtcNow - _lastHealthyAt >= configuration.HealthyResetInterval)
                {
                    _restartFailures = 0;
                }

                _restartFailures++;
                if (_restartFailures > configuration.RestartLimit)
                {
                    _status.Report(new ServiceStatusUpdate(ServiceLifecycleState.Stopped, 0, TimeSpan.Zero, 1, 0x5250_0002));
                    return;
                }

                var delayMilliseconds = Math.Min(
                    configuration.InitialRestartDelay.TotalMilliseconds * Math.Pow(2, _restartFailures - 1),
                    configuration.MaximumRestartDelay.TotalMilliseconds);
                await _clock.DelayAsync(TimeSpan.FromMilliseconds(delayMilliseconds), cancellationToken).ConfigureAwait(false);

                await _transition.WaitAsync(cancellationToken).ConfigureAwait(false);
                try
                {
                    if (IsStopping || cancellationToken.IsCancellationRequested)
                    {
                        return;
                    }

                    await child.DisposeAsync().ConfigureAwait(false);
                    if (_drain is not null)
                    {
                        await _drain.DisposeAsync().ConfigureAwait(false);
                    }

                    await StartChildAsync(cancellationToken).ConfigureAwait(false);
                    _lastHealthyAt = _clock.UtcNow;
                }
                finally
                {
                    _transition.Release();
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                _evidence.Record("service.child.restart-failed", new Dictionary<string, object?> { ["category"] = exception.GetType().Name });
            }
        }
    }

    private void ReportPending(ServiceLifecycleState state, TimeSpan waitHint)
    {
        _checkpoint++;
        _status.Report(new ServiceStatusUpdate(state, _checkpoint, waitHint));
    }

    private async Task<bool> WaitForEmptyJobAsync(IProcessTreeOwner job, TimeSpan timeout)
    {
        using var deadline = new CancellationTokenSource(timeout);
        while (!deadline.IsCancellationRequested)
        {
            if (await job.IsEmptyAsync(CancellationToken.None).ConfigureAwait(false))
            {
                return true;
            }

            try
            {
                await _clock.DelayAsync(TimeSpan.FromMilliseconds(25), deadline.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
        }

        return await job.IsEmptyAsync(CancellationToken.None).ConfigureAwait(false);
    }

    public async ValueTask DisposeAsync()
    {
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

        if (_drain is not null)
        {
            await _drain.DisposeAsync().ConfigureAwait(false);
        }

        if (_child is not null)
        {
            await _child.DisposeAsync().ConfigureAwait(false);
        }

        if (_job is not null)
        {
            await _job.DisposeAsync().ConfigureAwait(false);
        }

        _transition.Dispose();
        _lifetime.Dispose();
    }
}
