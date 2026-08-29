using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

internal sealed class RecordingStatusReporter : IServiceStatusReporter
{
    public List<ServiceStatusUpdate> Updates { get; } = [];

    public void Report(ServiceStatusUpdate update) => Updates.Add(update);
}

internal sealed class FakeClock : IServiceClock
{
    public DateTimeOffset UtcNow { get; private set; } = new(2026, 8, 29, 0, 0, 0, TimeSpan.Zero);

    public List<TimeSpan> Delays { get; } = [];

    public ValueTask DelayAsync(TimeSpan delay, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Delays.Add(delay);
        UtcNow += delay;
        return ValueTask.CompletedTask;
    }

    public void Advance(TimeSpan interval) => UtcNow += interval;
}

internal sealed class StaticConfigurationResolver(ReleaseConfiguration configuration) : IReleaseConfigurationResolver
{
    public ReleaseConfiguration Resolve() => configuration;
}

internal sealed class FakeChild : INodeChildProcess
{
    private readonly TaskCompletionSource<int> _completion = new(TaskCreationOptions.RunContinuationsAsynchronously);

    public int ProcessId { get; init; } = 4242;

    public bool HasExited => _completion.Task.IsCompleted;

    public Task<int> Completion => _completion.Task;

    public int StartCount { get; private set; }

    public int ExitRequestCount { get; private set; }

    public int ResumeCount { get; private set; }

    public Action? OnExitRequested { get; init; }

    public Task StartAsync(ReleaseConfiguration configuration, string pipeName, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        StartCount++;
        return Task.CompletedTask;
    }

    public Task RequestExitAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ExitRequestCount++;
        OnExitRequested?.Invoke();
        _completion.TrySetResult(0);
        return Task.CompletedTask;
    }

    public Task ResumeAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ResumeCount++;
        return Task.CompletedTask;
    }

    public void Crash(int exitCode = 71) => _completion.TrySetResult(exitCode);

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}

internal sealed class FakeJob : IProcessTreeOwner
{
    public bool Empty { get; set; }

    public int AssignCount { get; private set; }

    public int TerminateCount { get; private set; }

    public Task AssignAsync(int processId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        AssignCount++;
        Empty = false;
        return Task.CompletedTask;
    }

    public Task<bool> IsEmptyAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(Empty);
    }

    public Task TerminateAsync(uint exitCode, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        TerminateCount++;
        Empty = true;
        return Task.CompletedTask;
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}

internal sealed class FakeDrain : IDrainTransport
{
    public int ReadyCount { get; private set; }

    public int DrainCount { get; private set; }

    public int StopCount { get; private set; }

    public Exception? DrainFailure { get; init; }

    public Task WaitForReadyAsync(TimeSpan timeout, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ReadyCount++;
        return Task.CompletedTask;
    }

    public Task<DrainAcknowledgement> BeginDrainAsync(string nonce, TimeSpan timeout, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        DrainCount++;
        if (DrainFailure is not null)
        {
            return Task.FromException<DrainAcknowledgement>(DrainFailure);
        }

        return Task.FromResult(new DrainAcknowledgement(nonce, DrainState.Drained, 0));
    }

    public Task<DrainAcknowledgement> RequestStopAsync(string nonce, TimeSpan timeout, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        StopCount++;
        return Task.FromResult(new DrainAcknowledgement(nonce, DrainState.Stopped, 0));
    }

    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}

internal static class TestConfiguration
{
    public static ReleaseConfiguration Create(int restartLimit = 2) =>
        new(
            "C:\\synthetic-node",
            "C:\\synthetic-release-root",
            "C:\\synthetic-node\\node.exe",
            "C:\\synthetic-release-root\\release-a",
            "C:\\synthetic-release-root\\release-a\\server.js",
            Array.Empty<string>(),
            "C:\\synthetic-logs",
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(30),
            restartLimit,
            TimeSpan.FromMilliseconds(10),
            TimeSpan.FromMilliseconds(40));
}
