using System.Diagnostics;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class NodeFixtureTests
{
    private static readonly string[] ExpectedStreamOutput = ["chunk-1", "chunk-2", "chunk-3", "work-rejected-draining"];
    private static readonly string[] ExpectedDiagnosticStages =
    [
        "fixture-started",
        "pipe-connection-attempted",
        "pipe-connected",
        "ready-write-attempted",
        "ready-write-completed",
    ];
    private static readonly string[] OutputFixtureArguments = ["output-fixture"];

    [TestMethod]
    public async Task ActiveThreeChunkStreamCompletesAndNewWorkIsRejectedDuringDrain()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        await using var fixture = DiagnosticNodeFixture.Start(pipeName, "normal");
        var process = fixture.Process;
        var diagnosticRecords = await FixtureReadinessObserver.WaitForReadyAsync(
            transport,
            fixture,
            TimeSpan.FromSeconds(3),
            CancellationToken.None);
        CollectionAssert.AreEqual(ExpectedDiagnosticStages, diagnosticRecords.Select(record => record.Stage).ToArray());

        await process.StandardInput.WriteLineAsync("stream");
        var nonce = Guid.NewGuid().ToString("N");
        var drainTask = transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
        await Task.Delay(50);
        await process.StandardInput.WriteLineAsync("stream");
        var output = new List<string>();
        while (output.Count < 4)
        {
            var line = await process.StandardOutput.ReadLineAsync().WaitAsync(TimeSpan.FromSeconds(3));
            Assert.IsNotNull(line);
            output.Add(line);
        }

        var drained = await drainTask;
        CollectionAssert.AreEquivalent(ExpectedStreamOutput, output);
        Assert.AreEqual(DrainState.Drained, drained.State);
        _ = await transport.RequestStopAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
        await process.StandardInput.WriteLineAsync("exit");
        await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
        Assert.AreEqual(0, process.ExitCode);
    }

    [TestMethod]
    public async Task FixtureStaleAcknowledgementIsRejected()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        using var process = StartFixture(pipeName, "stale-ack");
        await transport.WaitForReadyAsync(TimeSpan.FromSeconds(3), CancellationToken.None);
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.BeginDrainAsync(Guid.NewGuid().ToString("N"), TimeSpan.FromSeconds(3), CancellationToken.None));
        process.Kill(true);
        await process.WaitForExitAsync();
    }

    [TestMethod]
    public async Task FixtureMalformedReadyIsRejected()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        using var process = StartFixture(pipeName, "malformed-ready");
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.WaitForReadyAsync(TimeSpan.FromSeconds(3), CancellationToken.None));
        process.Kill(true);
        await process.WaitForExitAsync();
    }

    [TestMethod]
    public async Task PersistentStartupFailureExitsWithControlledCode()
    {
        using var process = StartFixture("unused", "startup-failure");
        await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
        Assert.AreEqual(70, process.ExitCode);
        Assert.AreEqual("controlled startup failure", await process.StandardError.ReadLineAsync());
    }

    [TestMethod]
    public async Task NodeAdapterKeepsStandardOutputAndErrorSeparated()
    {
        var pipeName = NewPipeName();
        var sink = new InMemoryEvidenceSink();
        var node = ResolveNode();
        var fixture = ResolveFixture();
        var logDirectory = Path.Combine(Path.GetTempPath(), $"risepals-servicehost-output-{Guid.NewGuid():N}");
        Directory.CreateDirectory(logDirectory);
        try
        {
            var configuration = ReleaseConfiguration.CreateForTest(node, Path.GetDirectoryName(fixture)!, fixture, logDirectory) with
            {
                Arguments = OutputFixtureArguments,
            };
            await using var transport = new NamedPipeDrainTransport(pipeName);
            await using var child = new NodeChildProcess(sink);
            await child.StartAsync(configuration, pipeName, CancellationToken.None);
            await child.ResumeAsync(CancellationToken.None);
            await transport.WaitForReadyAsync(TimeSpan.FromSeconds(3), CancellationToken.None);
            await WaitUntilAsync(() => sink.Events.Count(entry => entry.Name == ServiceEvidenceEventName.ChildStreamObserved) >= 2);
            var streams = sink.Events
                .Where(entry => entry.Name == ServiceEvidenceEventName.ChildStreamObserved)
                .Select(entry => entry.Stream)
                .ToArray();
            CollectionAssert.Contains(streams, ServiceEvidenceStreamKind.StandardOutput);
            CollectionAssert.Contains(streams, ServiceEvidenceStreamKind.StandardError);
            var nonce = Guid.NewGuid().ToString("N");
            _ = await transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
            _ = await transport.RequestStopAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
            await child.RequestExitAsync(CancellationToken.None);
            _ = await child.Completion.WaitAsync(TimeSpan.FromSeconds(3));
        }
        finally
        {
            Directory.Delete(logDirectory, true);
        }
    }

    [TestMethod]
    public async Task ChildIsAssignedToJobBeforeSuspendedPrimaryThreadResumes()
    {
        var pipeName = NewPipeName();
        var sink = new InMemoryEvidenceSink();
        var node = ResolveNode();
        var fixture = ResolveFixture();
        var logDirectory = Path.Combine(Path.GetTempPath(), $"risepals-servicehost-suspended-{Guid.NewGuid():N}");
        Directory.CreateDirectory(logDirectory);
        try
        {
            var configuration = ReleaseConfiguration.CreateForTest(node, Path.GetDirectoryName(fixture)!, fixture, logDirectory);
            await using var transport = new NamedPipeDrainTransport(pipeName);
            await using var child = new NodeChildProcess(sink);
            await using var job = new WindowsJobObject();
            await child.StartAsync(configuration, pipeName, CancellationToken.None);
            await Task.Delay(50);
            Assert.AreEqual(0, sink.Events.Count);
            await job.AssignAsync(child.ProcessId, CancellationToken.None);
            Assert.IsFalse(await job.IsEmptyAsync(CancellationToken.None));
            await child.ResumeAsync(CancellationToken.None);
            await transport.WaitForReadyAsync(TimeSpan.FromSeconds(3), CancellationToken.None);
            var nonce = Guid.NewGuid().ToString("N");
            _ = await transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
            _ = await transport.RequestStopAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
            await child.RequestExitAsync(CancellationToken.None);
            _ = await child.Completion.WaitAsync(TimeSpan.FromSeconds(3));
            await JobObjectTestAssertions.AssertEventuallyEmptyAsync(job);
        }
        finally
        {
            Directory.Delete(logDirectory, true);
        }
    }

    private static Process StartFixture(string pipeName, string mode)
    {
        var info = new ProcessStartInfo
        {
            FileName = ResolveNode(),
            WorkingDirectory = Path.GetDirectoryName(ResolveFixture())!,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        info.ArgumentList.Add(ResolveFixture());
        info.ArgumentList.Add(mode);
        info.Environment["RISEPALS_DRAIN_PIPE"] = pipeName;
        return Process.Start(info) ?? throw new InvalidOperationException("Synthetic Node fixture did not start.");
    }

    private static string ResolveNode()
    {
        var entries = (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator);
        return entries.Select(entry => Path.Combine(entry, "node.exe")).FirstOrDefault(File.Exists)
            ?? throw new AssertInconclusiveException("Pinned Node executable is unavailable.");
    }

    private static string ResolveFixture()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, "infra", "windows-service-host", "fixtures", "node-service-fixture.mjs");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException("The repository Node fixture was not found.");
    }

    private static string NewPipeName() => $"RisePals.ServiceHost.v1.{Guid.NewGuid():N}";

    private static async Task WaitUntilAsync(Func<bool> predicate)
    {
        for (var index = 0; index < 100 && !predicate(); index++)
        {
            await Task.Delay(20);
        }

        Assert.IsTrue(predicate());
    }
}
