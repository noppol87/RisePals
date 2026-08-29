using System.Collections.ObjectModel;

namespace RisePals.ServiceHost;

public enum ServiceLifecycleState
{
    StartPending,
    Running,
    StopPending,
    Stopped,
}

public sealed record ServiceStatusUpdate(
    ServiceLifecycleState State,
    uint Checkpoint,
    TimeSpan WaitHint,
    uint Win32ExitCode = 0,
    uint ServiceSpecificExitCode = 0);

public interface IServiceStatusReporter
{
    void Report(ServiceStatusUpdate update);
}

public interface IServiceClock
{
    DateTimeOffset UtcNow { get; }

    ValueTask DelayAsync(TimeSpan delay, CancellationToken cancellationToken);
}

public interface INodeChildProcess : IAsyncDisposable
{
    int ProcessId { get; }

    bool HasExited { get; }

    Task<int> Completion { get; }

    Task StartAsync(ReleaseConfiguration configuration, string pipeName, CancellationToken cancellationToken);

    Task ResumeAsync(CancellationToken cancellationToken);

    Task RequestExitAsync(CancellationToken cancellationToken);
}

public interface IProcessTreeOwner : IAsyncDisposable
{
    Task AssignAsync(int processId, CancellationToken cancellationToken);

    Task<bool> IsEmptyAsync(CancellationToken cancellationToken);

    Task TerminateAsync(uint exitCode, CancellationToken cancellationToken);
}

public interface IDrainTransport : IAsyncDisposable
{
    Task WaitForReadyAsync(TimeSpan timeout, CancellationToken cancellationToken);

    Task<DrainAcknowledgement> BeginDrainAsync(string nonce, TimeSpan timeout, CancellationToken cancellationToken);

    Task<DrainAcknowledgement> RequestStopAsync(string nonce, TimeSpan timeout, CancellationToken cancellationToken);
}

public interface IReleaseConfigurationResolver
{
    ReleaseConfiguration Resolve();
}

public interface ISanitizedEvidenceSink
{
    void Record(string eventName, IReadOnlyDictionary<string, object?> fields);
}

public sealed record ReleaseConfiguration(
    string ApprovedNodeRoot,
    string ApprovedReleaseRoot,
    string NodeExecutable,
    string ReleaseDirectory,
    string Entrypoint,
    IReadOnlyList<string> Arguments,
    string LogDirectory,
    TimeSpan StartTimeout,
    TimeSpan DrainTimeout,
    TimeSpan ExitTimeout,
    TimeSpan HealthyResetInterval,
    int RestartLimit,
    TimeSpan InitialRestartDelay,
    TimeSpan MaximumRestartDelay)
{
    public static ReleaseConfiguration CreateForTest(
        string nodeExecutable,
        string releaseDirectory,
        string entrypoint,
        string logDirectory,
        int restartLimit = 2) =>
        new(
            Path.GetDirectoryName(nodeExecutable)!,
            releaseDirectory,
            nodeExecutable,
            releaseDirectory,
            entrypoint,
            Array.Empty<string>(),
            logDirectory,
            TimeSpan.FromSeconds(5),
            TimeSpan.FromSeconds(5),
            TimeSpan.FromSeconds(5),
            TimeSpan.FromSeconds(30),
            restartLimit,
            TimeSpan.FromMilliseconds(50),
            TimeSpan.FromMilliseconds(200));
}

public sealed record DrainAcknowledgement(string Nonce, DrainState State, int ActiveCount);

public enum DrainState
{
    Ready,
    Draining,
    Drained,
    Stopped,
}

public sealed class SystemServiceClock : IServiceClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;

    public async ValueTask DelayAsync(TimeSpan delay, CancellationToken cancellationToken) =>
        await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
}

public sealed class InMemoryEvidenceSink : ISanitizedEvidenceSink
{
    private readonly List<(string Name, IReadOnlyDictionary<string, object?> Fields)> _events = [];
    private readonly object _gate = new();

    public ReadOnlyCollection<(string Name, IReadOnlyDictionary<string, object?> Fields)> Events
    {
        get
        {
            lock (_gate)
            {
                return _events.ToList().AsReadOnly();
            }
        }
    }

    public void Record(string eventName, IReadOnlyDictionary<string, object?> fields)
    {
        lock (_gate)
        {
            _events.Add((eventName, fields));
        }
    }
}
