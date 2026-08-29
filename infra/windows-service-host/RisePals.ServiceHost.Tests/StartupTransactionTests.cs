using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class StartupTransactionTests
{
    [TestMethod]
    public async Task ChildCreationFailureDisposesEveryLocalAdapterBeforeTerminalState()
    {
        var child = new FakeChild { StartFailure = new InvalidOperationException("synthetic") };
        var job = new FakeJob();
        var drain = new FakeDrain();
        var status = new RecordingStatusReporter();
        await using var orchestrator = Create(status, [child], [job], [drain], restartLimit: 0);

        await Assert.ThrowsExactlyAsync<ServiceHostTerminalException>(() => orchestrator.StartAsync(CancellationToken.None));

        Assert.AreEqual(1, child.TerminateCount);
        Assert.AreEqual(1, child.DisposeCount);
        Assert.AreEqual(0, job.TerminateCount);
        Assert.AreEqual(1, job.DisposeCount);
        Assert.AreEqual(1, drain.DisposeCount);
        Assert.IsTrue(job.Empty);
        Assert.AreEqual(ServiceLifecycleState.Stopped, status.Updates[^1].State);
    }

    [TestMethod]
    public async Task JobAssignmentFailureTerminatesPossiblyAssignedJobExactlyOnce()
    {
        var child = new FakeChild();
        var job = new FakeJob
        {
            AssignFailure = new InvalidOperationException("synthetic"),
            PossiblyAssignedOnFailure = true,
        };
        var drain = new FakeDrain();
        var status = new RecordingStatusReporter();
        await using var orchestrator = Create(status, [child], [job], [drain], restartLimit: 0);

        await Assert.ThrowsExactlyAsync<ServiceHostTerminalException>(() => orchestrator.StartAsync(CancellationToken.None));

        AssertAttemptWasDisposed(child, job, drain, expectedJobTerminations: 1);
        Assert.IsTrue(job.Empty);
        Assert.AreEqual(ServiceLifecycleState.Stopped, status.Updates[^1].State);
    }

    [TestMethod]
    public async Task ResumeFailureTerminatesOwnedJobAndDisposesAttemptExactlyOnce()
    {
        var child = new FakeChild { ResumeFailure = new InvalidOperationException("synthetic") };
        var job = new FakeJob();
        var drain = new FakeDrain();
        var status = new RecordingStatusReporter();
        await using var orchestrator = Create(status, [child], [job], [drain], restartLimit: 0);

        await Assert.ThrowsExactlyAsync<ServiceHostTerminalException>(() => orchestrator.StartAsync(CancellationToken.None));

        AssertAttemptWasDisposed(child, job, drain, expectedJobTerminations: 1);
        Assert.IsTrue(job.Empty);
    }

    [TestMethod]
    public async Task ReadyTimeoutTerminatesOwnedJobAndNeverPublishesPartialState()
    {
        var child = new FakeChild();
        var job = new FakeJob();
        var drain = new FakeDrain { ReadyFailure = new TimeoutException("synthetic") };
        var status = new RecordingStatusReporter();
        await using var orchestrator = Create(status, [child], [job], [drain], restartLimit: 0);

        await Assert.ThrowsExactlyAsync<ServiceHostTerminalException>(() => orchestrator.StartAsync(CancellationToken.None));

        AssertAttemptWasDisposed(child, job, drain, expectedJobTerminations: 1);
        Assert.IsFalse(status.Updates.Any(update => update.State == ServiceLifecycleState.Running));
        Assert.AreEqual(ServiceLifecycleState.Stopped, status.Updates[^1].State);
    }

    [TestMethod]
    public async Task MalformedAndDisconnectedReadyBothFailClosedWithTransactionalCleanup()
    {
        await AssertReadyFailureIsTransactionalAsync(new DrainProtocolException("synthetic malformed Ready"));
        await AssertReadyFailureIsTransactionalAsync(new IOException("synthetic disconnected Ready"));
    }

    [TestMethod]
    public async Task RepeatedStartupFailureCountsEveryAttemptAndStopsOnlyAfterVerifiedEmptyJobs()
    {
        var children = Enumerable.Range(0, 3)
            .Select(_ => new FakeChild { StartFailure = new InvalidOperationException("synthetic") })
            .ToArray();
        var jobs = Enumerable.Range(0, 3).Select(_ => new FakeJob()).ToArray();
        var drains = Enumerable.Range(0, 3).Select(_ => new FakeDrain()).ToArray();
        var status = new RecordingStatusReporter();
        var evidence = new InMemoryEvidenceSink();
        var clock = new FakeClock();
        await using var orchestrator = Create(status, children, jobs, drains, restartLimit: 2, clock, evidence);

        await Assert.ThrowsExactlyAsync<ServiceHostTerminalException>(() => orchestrator.StartAsync(CancellationToken.None));

        Assert.IsTrue(children.All(child => child.StartCount == 1 && child.TerminateCount == 1 && child.DisposeCount == 1));
        Assert.IsTrue(jobs.All(job => job.Empty && job.TerminateCount == 0 && job.DisposeCount == 1));
        Assert.IsTrue(drains.All(drain => drain.DisposeCount == 1));
        Assert.AreEqual(3, evidence.Events.Count(item => item.Name == ServiceEvidenceEventName.ChildStartupFailed));
        Assert.AreEqual(1, evidence.Events.Count(item => item.Outcome == ServiceEvidenceOutcome.RestartLimitReached));
        CollectionAssert.AreEqual(
            new[] { TimeSpan.FromMilliseconds(10), TimeSpan.FromMilliseconds(20) },
            clock.Delays.Take(2).ToArray());
        Assert.AreEqual(1, status.Updates.Count(update => update.State == ServiceLifecycleState.Stopped));
    }

    [TestMethod]
    public async Task StopConcurrentWithFailedRestartCleansAttemptAndPreventsAnotherRetry()
    {
        var firstChild = new FakeChild();
        var firstJob = new FakeJob();
        var firstDrain = new FakeDrain();
        var secondChild = new FakeChild();
        var secondJob = new FakeJob();
        var blockedReady = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var secondDrain = new FakeDrain { ReadyRelease = blockedReady };
        var unusedThirdChild = new FakeChild();
        var status = new RecordingStatusReporter();
        await using var orchestrator = Create(
            status,
            [firstChild, secondChild, unusedThirdChild],
            [firstJob, secondJob, new FakeJob()],
            [firstDrain, secondDrain, new FakeDrain()],
            restartLimit: 3);
        await orchestrator.StartAsync(CancellationToken.None);

        firstChild.Crash();
        await secondDrain.ReadyStarted.Task.WaitAsync(TimeSpan.FromSeconds(1));
        await orchestrator.StopAsync(false, CancellationToken.None).WaitAsync(TimeSpan.FromSeconds(1));

        Assert.AreEqual(1, firstJob.TerminateCount);
        Assert.AreEqual(1, secondJob.TerminateCount);
        Assert.AreEqual(1, secondChild.TerminateCount);
        Assert.AreEqual(1, secondChild.DisposeCount);
        Assert.AreEqual(1, secondDrain.DisposeCount);
        Assert.AreEqual(0, unusedThirdChild.StartCount);
        Assert.IsTrue(firstJob.Empty);
        Assert.IsTrue(secondJob.Empty);
        Assert.AreEqual(ServiceLifecycleState.Stopped, status.Updates[^1].State);
    }

    [TestMethod]
    public async Task CleanupUnprovenNeverReportsStoppedAndUsesFixedFailureClassification()
    {
        var child = new FakeChild { ResumeFailure = new InvalidOperationException("synthetic") };
        var job = new FakeJob { RemainNonEmptyAfterTerminate = true };
        var drain = new FakeDrain();
        var status = new RecordingStatusReporter();
        var evidence = new InMemoryEvidenceSink();
        await using var orchestrator = Create(status, [child], [job], [drain], restartLimit: 0, evidence: evidence);

        await Assert.ThrowsExactlyAsync<ServiceHostCleanupException>(() => orchestrator.StartAsync(CancellationToken.None));

        Assert.AreEqual(1, job.TerminateCount);
        Assert.IsFalse(job.Empty);
        Assert.AreEqual(1, child.DisposeCount);
        Assert.AreEqual(1, drain.DisposeCount);
        Assert.IsFalse(status.Updates.Any(update => update.State == ServiceLifecycleState.Stopped));
        CollectionAssert.AreEqual(
            new[] { ServiceEvidenceOutcome.CleanupUnproven },
            evidence.Events.Where(item => item.Name == ServiceEvidenceEventName.OwnedProcessCleanupFailed)
                .Select(item => item.Outcome)
                .ToArray());
    }

    private static async Task AssertReadyFailureIsTransactionalAsync(Exception failure)
    {
        var child = new FakeChild();
        var job = new FakeJob();
        var drain = new FakeDrain { ReadyFailure = failure };
        var status = new RecordingStatusReporter();
        await using var orchestrator = Create(status, [child], [job], [drain], restartLimit: 0);
        await Assert.ThrowsExactlyAsync<ServiceHostTerminalException>(() => orchestrator.StartAsync(CancellationToken.None));
        AssertAttemptWasDisposed(child, job, drain, expectedJobTerminations: 1);
        Assert.IsFalse(status.Updates.Any(update => update.State == ServiceLifecycleState.Running));
    }

    private static void AssertAttemptWasDisposed(
        FakeChild child,
        FakeJob job,
        FakeDrain drain,
        int expectedJobTerminations)
    {
        Assert.AreEqual(1, child.TerminateCount);
        Assert.AreEqual(1, child.DisposeCount);
        Assert.AreEqual(expectedJobTerminations, job.TerminateCount);
        Assert.AreEqual(1, job.DisposeCount);
        Assert.AreEqual(1, drain.DisposeCount);
    }

    private static ServiceOrchestrator Create(
        RecordingStatusReporter status,
        IEnumerable<FakeChild> children,
        IEnumerable<FakeJob> jobs,
        IEnumerable<FakeDrain> drains,
        int restartLimit,
        FakeClock? clock = null,
        InMemoryEvidenceSink? evidence = null)
    {
        var childQueue = new Queue<FakeChild>(children);
        var jobQueue = new Queue<FakeJob>(jobs);
        var drainQueue = new Queue<FakeDrain>(drains);
        return new ServiceOrchestrator(
            status,
            clock ?? new FakeClock(),
            new StaticConfigurationResolver(TestConfiguration.Create(restartLimit)),
            () => childQueue.Dequeue(),
            () => jobQueue.Dequeue(),
            _ => drainQueue.Dequeue(),
            evidence ?? new InMemoryEvidenceSink());
    }
}
