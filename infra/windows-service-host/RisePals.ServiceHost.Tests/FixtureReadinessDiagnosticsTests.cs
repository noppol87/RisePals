using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class FixtureReadinessDiagnosticsTests
{
    [TestMethod]
    public void ProcessCreationFailureIsClosedAndLeavesNoDiagnosticDirectory()
    {
        var before = DiagnosticDirectories();
        var exception = Assert.ThrowsExactly<FixtureReadinessDiagnosticException>(() =>
            DiagnosticNodeFixture.Start(NewPipeName(), "normal", Path.Combine(Path.GetTempPath(), $"missing-node-{Guid.NewGuid():N}.exe")));

        Assert.AreEqual("process-not-created", exception.Category);
        Assert.AreEqual("process-not-created", exception.Stage);
        CollectionAssert.AreEquivalent(before, DiagnosticDirectories());
    }

    [TestMethod]
    public async Task ExitBeforeConnectionAttemptIsClassifiedAndCleaned()
    {
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(NewPipeName(), "diagnostic-exit-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            await fixture.Process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
            var records = fixture.Diagnostics.ReadAndValidate();
            AssertStages(records, "fixture-started", "fixture-exit-recorded");
            Assert.AreEqual("controlled-fixture-exit", records[^1].FailureCategory);
            Assert.AreEqual(74, fixture.Process.ExitCode);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task ConnectionFailureIsClassifiedAndCleaned()
    {
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(NewPipeName(), "normal"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            await fixture.Process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
            var records = fixture.Diagnostics.ReadAndValidate();
            AssertStages(records, "fixture-started", "pipe-connection-attempted", "fixture-exit-recorded");
            Assert.AreEqual("connection-failure", records[^1].FailureCategory);
            Assert.AreEqual(72, fixture.Process.ExitCode);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task ExitAfterConnectionBeforeReadyIsClassifiedAndCleaned()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-exit-after-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromSeconds(3), CancellationToken.None));
            Assert.AreEqual("controlled-fixture-exit", exception.Category);
            Assert.AreEqual("fixture-exit-recorded", exception.Stage);
            Assert.AreEqual(75, exception.ControlledExitCode);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task ReadyWriteFailureIsClassifiedAndCleaned()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-ready-write-failure"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromSeconds(3), CancellationToken.None));
            Assert.AreEqual("ready-write-failure", exception.Category);
            Assert.AreEqual("fixture-exit-recorded", exception.Stage);
            Assert.AreEqual(76, exception.ControlledExitCode);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task SuccessfullyWrittenMalformedReadyRemainsAProtocolFailureAndIsCleaned()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "malformed-ready"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromSeconds(3), CancellationToken.None));
            Assert.AreEqual("invalid-ready", exception.Category);
            Assert.AreEqual("ready-write-completed", exception.Stage);
            Assert.IsInstanceOfType<DrainProtocolException>(exception.InnerException);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task AliveFixtureAtDeadlineIsClassifiedWithoutIncreasingTheBound()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-alive-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromMilliseconds(250), CancellationToken.None));
            Assert.AreEqual("readiness-timeout-fixture-alive", exception.Category);
            Assert.AreEqual("fixture-started", exception.Stage);
            Assert.IsFalse(fixture.Process.HasExited);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task ValidReadyUsesThePipeAsAuthorityAndDiagnosticsAreCleaned()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "normal"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var records = await FixtureReadinessObserver.WaitForReadyAsync(
                transport,
                fixture,
                TimeSpan.FromSeconds(3),
                CancellationToken.None);
            AssertStages(
                records,
                "fixture-started",
                "pipe-connection-attempted",
                "pipe-connected",
                "ready-write-attempted",
                "ready-write-completed");
            var nonce = Guid.NewGuid().ToString("N");
            _ = await transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
            _ = await transport.RequestStopAsync(nonce, TimeSpan.FromSeconds(3), CancellationToken.None);
            await fixture.Process.StandardInput.WriteLineAsync("exit");
            await fixture.Process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
            Assert.AreEqual(0, fixture.Process.ExitCode);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public void WrongNonceDiagnosticEvidenceFailsClosedAndCleansUp()
    {
        string directory;
        using (var diagnostics = FixtureDiagnosticScope.Create())
        {
            directory = diagnostics.DirectoryPath;
            diagnostics.WriteSynthetic(Record("ffffffffffffffffffffffffffffffff", 1, "fixture-started", 0));
            Assert.ThrowsExactly<InvalidDataException>(() => diagnostics.ReadAndValidate());
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public void StaleMonotonicEvidenceFailsClosedAndCleansUp()
    {
        string directory;
        using (var diagnostics = FixtureDiagnosticScope.Create())
        {
            directory = diagnostics.DirectoryPath;
            diagnostics.WriteSynthetic(Record(diagnostics.Nonce, 1, "fixture-started", 10));
            diagnostics.WriteSynthetic(Record(diagnostics.Nonce, 2, "pipe-connection-attempted", 9));
            Assert.ThrowsExactly<InvalidDataException>(() => diagnostics.ReadAndValidate());
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public void ReplayedStageEvidenceFailsClosedAndCleansUp()
    {
        string directory;
        using (var diagnostics = FixtureDiagnosticScope.Create())
        {
            directory = diagnostics.DirectoryPath;
            diagnostics.WriteSynthetic(Record(diagnostics.Nonce, 1, "fixture-started", 0));
            diagnostics.WriteSynthetic(Record(diagnostics.Nonce, 2, "fixture-started", 1));
            Assert.ThrowsExactly<InvalidDataException>(() => diagnostics.ReadAndValidate());
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public void MalformedAndPartialNonAtomicEvidenceFailClosedAndCleanUp()
    {
        VerifyInvalidEvidence((diagnostics) =>
            File.WriteAllText(Path.Combine(diagnostics.DirectoryPath, "000001.json"), "{partial", new UTF8Encoding(false)));
        VerifyInvalidEvidence((diagnostics) =>
            File.WriteAllText(Path.Combine(diagnostics.DirectoryPath, $"000001.json.{diagnostics.Nonce}.tmp"), "{}", new UTF8Encoding(false)));
    }

    private static FixtureDiagnosticRecord Record(string nonce, int sequence, string stage, long elapsed) =>
        new(FixtureDiagnosticScope.SchemaVersion, nonce, sequence, stage, "none", null, elapsed);

    private static void VerifyInvalidEvidence(Action<FixtureDiagnosticScope> write)
    {
        string directory;
        using (var diagnostics = FixtureDiagnosticScope.Create())
        {
            directory = diagnostics.DirectoryPath;
            write(diagnostics);
            Assert.ThrowsExactly<InvalidDataException>(() => diagnostics.ReadAndValidate());
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    private static string[] DiagnosticDirectories() =>
        Directory.GetDirectories(Path.GetTempPath(), "risepals-servicehost-diagnostic-*", SearchOption.TopDirectoryOnly);

    private static string NewPipeName() => $"RisePals.ServiceHost.v1.{Guid.NewGuid():N}";

    private static void AssertStages(IReadOnlyList<FixtureDiagnosticRecord> records, params string[] stages) =>
        CollectionAssert.AreEqual(stages, records.Select(record => record.Stage).ToArray());
}
