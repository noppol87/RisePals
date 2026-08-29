using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class OrchestrationTests
{
    [TestMethod]
    public async Task DirectStopReportsPendingDrainsExitsAndThenStops()
    {
        var status = new RecordingStatusReporter();
        var job = new FakeJob();
        var child = new FakeChild { OnExitRequested = () => job.Empty = true };
        var drain = new FakeDrain();
        await using var orchestrator = Create(status, child, job, drain);

        await orchestrator.StartAsync(CancellationToken.None);
        await orchestrator.StopAsync(false, CancellationToken.None);

        CollectionAssert.AreEqual(
            new[] { ServiceLifecycleState.StartPending, ServiceLifecycleState.Running, ServiceLifecycleState.StopPending, ServiceLifecycleState.StopPending, ServiceLifecycleState.Stopped },
            status.Updates.Select(update => update.State).ToArray());
        Assert.AreEqual(1, drain.DrainCount);
        Assert.AreEqual(1, drain.StopCount);
        Assert.AreEqual(1, child.ExitRequestCount);
        Assert.IsTrue(job.Empty);
    }

    [TestMethod]
    public async Task DuplicateConcurrentStopSharesOneDrain()
    {
        var status = new RecordingStatusReporter();
        var job = new FakeJob();
        var child = new FakeChild { OnExitRequested = () => job.Empty = true };
        var drain = new FakeDrain();
        await using var orchestrator = Create(status, child, job, drain);
        await orchestrator.StartAsync(CancellationToken.None);

        var first = orchestrator.StopAsync(false, CancellationToken.None);
        var second = orchestrator.StopAsync(false, CancellationToken.None);
        Assert.AreSame(first, second);
        await Task.WhenAll(first, second);
        Assert.AreEqual(1, drain.DrainCount);
    }

    [TestMethod]
    public async Task PreshutdownUsesTheSameBoundedDrainContract()
    {
        var status = new RecordingStatusReporter();
        var job = new FakeJob();
        var child = new FakeChild { OnExitRequested = () => job.Empty = true };
        var drain = new FakeDrain();
        await using var orchestrator = Create(status, child, job, drain);
        await orchestrator.StartAsync(CancellationToken.None);
        await orchestrator.StopAsync(true, CancellationToken.None);
        Assert.AreEqual(ServiceLifecycleState.Stopped, status.Updates[^1].State);
    }

    [TestMethod]
    public async Task DrainTimeoutTerminatesOnlyTheOwnedJobAndReportsFailure()
    {
        var status = new RecordingStatusReporter();
        var job = new FakeJob();
        var child = new FakeChild();
        var drain = new FakeDrain { DrainFailure = new TimeoutException("synthetic") };
        await using var orchestrator = Create(status, child, job, drain);
        await orchestrator.StartAsync(CancellationToken.None);
        await orchestrator.StopAsync(false, CancellationToken.None);
        Assert.AreEqual(1, job.TerminateCount);
        Assert.AreEqual(1u, status.Updates[^1].Win32ExitCode);
        Assert.AreNotEqual(0u, status.Updates[^1].ServiceSpecificExitCode);
    }

    [TestMethod]
    public async Task StartReportsMonotonicPendingCheckpoint()
    {
        var status = new RecordingStatusReporter();
        var job = new FakeJob();
        var child = new FakeChild { OnExitRequested = () => job.Empty = true };
        await using var orchestrator = Create(status, child, job, new FakeDrain());
        await orchestrator.StartAsync(CancellationToken.None);
        await orchestrator.StopAsync(false, CancellationToken.None);
        var pending = status.Updates.Where(update => update.State is ServiceLifecycleState.StartPending or ServiceLifecycleState.StopPending).ToArray();
        Assert.IsTrue(pending.Zip(pending.Skip(1), (left, right) => left.Checkpoint < right.Checkpoint).All(value => value));
        Assert.IsTrue(pending.All(update => update.WaitHint > TimeSpan.Zero));
    }

    [TestMethod]
    public async Task UnexpectedCrashRestartsWithDeterministicBackoff()
    {
        var status = new RecordingStatusReporter();
        var clock = new FakeClock();
        var job = new FakeJob();
        var first = new FakeChild();
        var second = new FakeChild { OnExitRequested = () => job.Empty = true };
        var children = new Queue<FakeChild>([first, second]);
        var drains = new Queue<FakeDrain>([new FakeDrain(), new FakeDrain()]);
        await using var orchestrator = new ServiceOrchestrator(
            status,
            clock,
            new StaticConfigurationResolver(TestConfiguration.Create()),
            () => children.Dequeue(),
            () => job,
            _ => drains.Dequeue(),
            new InMemoryEvidenceSink());
        await orchestrator.StartAsync(CancellationToken.None);

        first.Crash();
        await WaitUntilAsync(() => second.StartCount == 1);
        Assert.AreEqual(TimeSpan.FromMilliseconds(10), clock.Delays[0]);
        await orchestrator.StopAsync(false, CancellationToken.None);
    }

    [TestMethod]
    public async Task StopDuringBackoffPreventsRestart()
    {
        var status = new RecordingStatusReporter();
        var clock = new BlockingClock();
        var job = new FakeJob();
        var first = new FakeChild { OnExitRequested = () => job.Empty = true };
        var second = new FakeChild();
        var children = new Queue<FakeChild>([first, second]);
        await using var orchestrator = new ServiceOrchestrator(
            status,
            clock,
            new StaticConfigurationResolver(TestConfiguration.Create()),
            () => children.Dequeue(),
            () => job,
            _ => new FakeDrain(),
            new InMemoryEvidenceSink());
        await orchestrator.StartAsync(CancellationToken.None);
        first.Crash();
        await clock.DelayStarted.Task.WaitAsync(TimeSpan.FromSeconds(1));
        job.Empty = true;
        await orchestrator.StopAsync(false, CancellationToken.None);
        Assert.AreEqual(0, second.StartCount);
    }

    [TestMethod]
    public async Task PersistentChildFailureReachesTerminalState()
    {
        var status = new RecordingStatusReporter();
        var clock = new FakeClock();
        var job = new FakeJob();
        var first = new FakeChild();
        var second = new FakeChild();
        var children = new Queue<FakeChild>([first, second]);
        await using var orchestrator = new ServiceOrchestrator(
            status,
            clock,
            new StaticConfigurationResolver(TestConfiguration.Create(restartLimit: 1)),
            () => children.Dequeue(),
            () => job,
            _ => new FakeDrain(),
            new InMemoryEvidenceSink());
        await orchestrator.StartAsync(CancellationToken.None);
        first.Crash();
        await WaitUntilAsync(() => second.StartCount == 1);
        second.Crash();
        await WaitUntilAsync(() => status.Updates.Any(update => update.State == ServiceLifecycleState.Stopped));
        Assert.AreEqual(0x5250_0002u, status.Updates[^1].ServiceSpecificExitCode);
    }

    [TestMethod]
    public async Task NormalUnexpectedExitUsesTheBoundedRestartPolicy()
    {
        var status = new RecordingStatusReporter();
        var clock = new FakeClock();
        var job = new FakeJob();
        var first = new FakeChild();
        var second = new FakeChild { OnExitRequested = () => job.Empty = true };
        var children = new Queue<FakeChild>([first, second]);
        await using var orchestrator = new ServiceOrchestrator(
            status,
            clock,
            new StaticConfigurationResolver(TestConfiguration.Create()),
            () => children.Dequeue(),
            () => job,
            _ => new FakeDrain(),
            new InMemoryEvidenceSink());
        await orchestrator.StartAsync(CancellationToken.None);
        first.Crash(0);
        await WaitUntilAsync(() => second.StartCount == 1);
        Assert.AreEqual(1, clock.Delays.Count);
        await orchestrator.StopAsync(false, CancellationToken.None);
    }

    private static ServiceOrchestrator Create(RecordingStatusReporter status, FakeChild child, FakeJob job, FakeDrain drain) =>
        new(
            status,
            new FakeClock(),
            new StaticConfigurationResolver(TestConfiguration.Create()),
            () => child,
            () => job,
            _ => drain,
            new InMemoryEvidenceSink());

    private static async Task WaitUntilAsync(Func<bool> predicate)
    {
        for (var index = 0; index < 100 && !predicate(); index++)
        {
            await Task.Delay(10);
        }

        Assert.IsTrue(predicate());
    }

    private sealed class BlockingClock : IServiceClock
    {
        public DateTimeOffset UtcNow { get; } = DateTimeOffset.UtcNow;

        public TaskCompletionSource DelayStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async ValueTask DelayAsync(TimeSpan delay, CancellationToken cancellationToken)
        {
            DelayStarted.TrySetResult();
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
        }
    }
}
