using System.Text;
using System.Text.Json.Nodes;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
[DoNotParallelize]
public sealed class FixtureReadinessDiagnosticsTests
{
    [TestMethod]
    public void ProcessCreationFailureIsClosedAndLeavesNoDiagnosticDirectory()
    {
        var before = DiagnosticDirectories();
        var exception = Assert.ThrowsExactly<FixtureReadinessDiagnosticException>(() =>
            DiagnosticNodeFixture.Start(NewPipeName(), "normal", Path.Combine(Path.GetTempPath(), $"missing-node-{Guid.NewGuid():N}.exe")));

        Assert.AreEqual("process-setup-failure", exception.PrimaryCategory);
        Assert.AreEqual("process-start", exception.PrimaryStage);
        Assert.AreEqual("not-observed", exception.DiagnosticValidity);
        CollectionAssert.AreEquivalent(before, DiagnosticDirectories());
    }

    [TestMethod]
    public async Task ExitBeforeConnectionAttemptIsClassifiedAndCleaned()
    {
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(NewPipeName(), "diagnostic-exit-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            _ = await FixtureReadinessObserver.WaitForFixtureStartupAsync(
                fixture,
                TimeSpan.FromSeconds(5),
                CancellationToken.None);
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
            Assert.AreEqual("process-exit-before-ready", exception.PrimaryCategory);
            Assert.AreEqual("readiness-race", exception.PrimaryStage);
            Assert.AreEqual("valid", exception.DiagnosticValidity);
            Assert.AreEqual("fixture-exit-recorded", exception.DiagnosticStage);
            Assert.AreEqual("controlled-fixture-exit", exception.DiagnosticFailureCategory);
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
            Assert.AreEqual("protocol-failure", exception.PrimaryCategory);
            Assert.AreEqual("ready-protocol", exception.PrimaryStage);
            Assert.AreEqual("valid", exception.DiagnosticValidity);
            Assert.AreEqual("fixture-exit-recorded", exception.DiagnosticStage);
            Assert.AreEqual("ready-write-failure", exception.DiagnosticFailureCategory);
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
            Assert.AreEqual("protocol-failure", exception.PrimaryCategory);
            Assert.AreEqual("ready-protocol", exception.PrimaryStage);
            Assert.AreEqual("valid", exception.DiagnosticValidity);
            Assert.AreEqual("ready-write-completed", exception.DiagnosticStage);
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
            var startup = await FixtureReadinessObserver.WaitForFixtureStartupAsync(
                fixture,
                TimeSpan.FromSeconds(3),
                CancellationToken.None);
            AssertStages(startup, "fixture-started");
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromMilliseconds(250), CancellationToken.None));
            Assert.AreEqual("readiness-timeout", exception.PrimaryCategory);
            Assert.AreEqual("readiness-wait", exception.PrimaryStage);
            Assert.AreEqual("valid", exception.DiagnosticValidity);
            Assert.AreEqual("fixture-started", exception.DiagnosticStage);
            Assert.IsFalse(fixture.Process.HasExited);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task FixtureStartupObservationHasItsOwnBoundAndReportsFailureTruthfully()
    {
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(NewPipeName(), "diagnostic-no-startup-record"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForFixtureStartupAsync(
                    fixture,
                    TimeSpan.FromMilliseconds(150),
                    CancellationToken.None));
            Assert.AreEqual("fixture-setup-timeout", exception.PrimaryCategory);
            Assert.AreEqual("startup-observation", exception.PrimaryStage);
            Assert.AreEqual("incomplete", exception.DiagnosticValidity);
            Assert.AreEqual("no-records", exception.DiagnosticStage);
            Assert.IsFalse(fixture.Process.HasExited);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task InterruptedAtomicWriteDoesNotEraseThePrimaryReadinessTimeout()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-alive-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            _ = await FixtureReadinessObserver.WaitForFixtureStartupAsync(fixture, TimeSpan.FromSeconds(3), CancellationToken.None);
            _ = fixture.Diagnostics.WriteSyntheticInterrupted(Record(
                fixture.Diagnostics.Nonce,
                2,
                "pipe-connection-attempted",
                30_000));

            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromMilliseconds(100), CancellationToken.None));
            Assert.AreEqual("readiness-timeout", exception.PrimaryCategory);
            Assert.AreEqual("readiness-wait", exception.PrimaryStage);
            Assert.AreEqual("incomplete", exception.DiagnosticValidity);
            Assert.AreEqual("fixture-started", exception.DiagnosticStage);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task MalformedEvidenceDoesNotEraseThePrimaryReadinessTimeout()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-alive-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            _ = await FixtureReadinessObserver.WaitForFixtureStartupAsync(fixture, TimeSpan.FromSeconds(3), CancellationToken.None);
            File.WriteAllText(Path.Combine(directory, "000002.json"), "{malformed", new UTF8Encoding(false));

            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromMilliseconds(100), CancellationToken.None));
            Assert.AreEqual("readiness-timeout", exception.PrimaryCategory);
            Assert.AreEqual("readiness-wait", exception.PrimaryStage);
            Assert.AreEqual("invalid", exception.DiagnosticValidity);
            Assert.AreEqual("invalid-evidence", exception.DiagnosticStage);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task InvalidEvidenceDoesNotEraseThePrimaryProcessExit()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-exit-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            await fixture.Process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
            File.WriteAllText(Path.Combine(directory, "000001.json"), "{malformed", new UTF8Encoding(false));

            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromSeconds(3), CancellationToken.None));
            Assert.AreEqual("process-exit-before-ready", exception.PrimaryCategory);
            Assert.AreEqual("readiness-race", exception.PrimaryStage);
            Assert.AreEqual("invalid", exception.DiagnosticValidity);
            Assert.AreEqual(74, exception.ControlledExitCode);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task InvalidEvidenceDoesNotEraseThePrimaryProtocolFailure()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(
                         pipeName,
                         "diagnostic-malformed-evidence-at-protocol-failure"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromSeconds(3), CancellationToken.None));
            Assert.AreEqual("protocol-failure", exception.PrimaryCategory);
            Assert.AreEqual("ready-protocol", exception.PrimaryStage);
            Assert.AreEqual("invalid", exception.DiagnosticValidity);
            Assert.IsInstanceOfType<DrainProtocolException>(exception.InnerException);
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    [TestMethod]
    public async Task ConcurrentAtomicPublicationSettlesWithinTheDiagnosticWindow()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        string directory;
        await using (var fixture = DiagnosticNodeFixture.Start(pipeName, "diagnostic-alive-before-connect"))
        {
            directory = fixture.Diagnostics.DirectoryPath;
            _ = await FixtureReadinessObserver.WaitForFixtureStartupAsync(fixture, TimeSpan.FromSeconds(3), CancellationToken.None);
            var paths = fixture.Diagnostics.WriteSyntheticInterrupted(Record(
                fixture.Diagnostics.Nonce,
                2,
                "pipe-connection-attempted",
                30_000));
            var publish = Task.Run(async () =>
            {
                await Task.Delay(200);
                File.Move(paths.TemporaryPath, paths.FinalPath);
            });

            var exception = await Assert.ThrowsExactlyAsync<FixtureReadinessDiagnosticException>(() =>
                FixtureReadinessObserver.WaitForReadyAsync(transport, fixture, TimeSpan.FromMilliseconds(100), CancellationToken.None));
            await publish;
            Assert.AreEqual("readiness-timeout", exception.PrimaryCategory);
            Assert.AreEqual("valid", exception.DiagnosticValidity);
            Assert.AreEqual("pipe-connection-attempted", exception.DiagnosticStage);
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

    [TestMethod]
    public void EveryDiagnosticPropertyIsRequiredExactlyOnce()
    {
        var required = new[]
        {
            "schemaVersion",
            "nonce",
            "sequence",
            "stage",
            "failureCategory",
            "exitCode",
            "elapsedMilliseconds",
        };
        foreach (var property in required)
        {
            VerifyInvalidJson(diagnostics =>
            {
                var record = ValidRecordObject(diagnostics);
                Assert.IsTrue(record.Remove(property));
                return record.ToJsonString();
            });
        }

        VerifyInvalidJson(diagnostics =>
            ValidRecordObject(diagnostics).ToJsonString().Replace(
                "\"stage\":\"fixture-started\"",
                "\"stage\":\"fixture-started\",\"stage\":\"fixture-started\"",
                StringComparison.Ordinal));
    }

    [TestMethod]
    public void UnknownAndIncorrectlyTypedDiagnosticPropertiesFailClosed()
    {
        VerifyInvalidJson(diagnostics =>
        {
            var record = ValidRecordObject(diagnostics);
            record["unexpected"] = true;
            return record.ToJsonString();
        });

        foreach (var property in new[]
                 {
                     "schemaVersion",
                     "nonce",
                     "sequence",
                     "stage",
                     "failureCategory",
                     "exitCode",
                     "elapsedMilliseconds",
                 })
        {
            VerifyInvalidJson(diagnostics =>
            {
                var record = ValidRecordObject(diagnostics);
                record[property] = property switch
                {
                    "schemaVersion" => "1",
                    "nonce" => 1,
                    "sequence" => true,
                    "stage" => 1,
                    "failureCategory" => false,
                    "exitCode" => "none",
                    "elapsedMilliseconds" => "0",
                    _ => throw new InvalidOperationException(),
                };
                return record.ToJsonString();
            });
        }
    }

    [TestMethod]
    public void NegativeElapsedAndFilenameSequenceMismatchFailClosed()
    {
        VerifyInvalidJson(diagnostics =>
        {
            var record = ValidRecordObject(diagnostics);
            record["elapsedMilliseconds"] = -1;
            return record.ToJsonString();
        });
        VerifyInvalidJson(diagnostics => ValidRecordObject(diagnostics).ToJsonString(), fileSequence: 2);
    }

    [TestMethod]
    [DataRow((int)DiagnosticFixtureStartupFailurePoint.ResolveExecutable, "executable-resolution")]
    [DataRow((int)DiagnosticFixtureStartupFailurePoint.ResolveFixture, "fixture-resolution")]
    [DataRow((int)DiagnosticFixtureStartupFailurePoint.ConstructProcessStartInfo, "process-start-info-construction")]
    [DataRow((int)DiagnosticFixtureStartupFailurePoint.ApplyEnvironment, "environment-setup")]
    public void EveryPostScopeStartupSetupFailureCleansItsExactDirectory(
        int failurePoint,
        string expectedStage)
    {
        var before = DiagnosticDirectories();
        var exception = Assert.ThrowsExactly<FixtureReadinessDiagnosticException>(() =>
            DiagnosticNodeFixture.Start(
                NewPipeName(),
                "normal",
                failurePoint: (DiagnosticFixtureStartupFailurePoint)failurePoint));

        Assert.AreEqual("process-setup-failure", exception.PrimaryCategory);
        Assert.AreEqual(expectedStage, exception.PrimaryStage);
        Assert.AreEqual("not-observed", exception.DiagnosticValidity);
        CollectionAssert.AreEquivalent(before, DiagnosticDirectories());
    }

    [TestMethod]
    public void UnexpectedChildDirectoryRejectsCleanupBeforeAnyDeletion()
    {
        var diagnostics = FixtureDiagnosticScope.Create();
        var directory = diagnostics.DirectoryPath;
        diagnostics.WriteSynthetic(Record(diagnostics.Nonce, 1, "fixture-started", 0));
        var evidencePath = Path.Combine(directory, "000001.json");
        var unexpectedDirectory = Path.Combine(directory, "unexpected");
        Directory.CreateDirectory(unexpectedDirectory);

        try
        {
            Assert.ThrowsExactly<InvalidDataException>(() => diagnostics.Dispose());
            Assert.IsTrue(File.Exists(evidencePath));
            Assert.IsTrue(Directory.Exists(unexpectedDirectory));
        }
        finally
        {
            if (Directory.Exists(unexpectedDirectory))
            {
                Directory.Delete(unexpectedDirectory, recursive: false);
            }

            if (Directory.Exists(directory))
            {
                diagnostics.Dispose();
            }
        }

        Assert.IsFalse(Directory.Exists(directory));
    }

    private static FixtureDiagnosticRecord Record(string nonce, int sequence, string stage, long elapsed) =>
        new(FixtureDiagnosticScope.SchemaVersion, nonce, sequence, stage, "none", null, elapsed);

    private static JsonObject ValidRecordObject(FixtureDiagnosticScope diagnostics) =>
        new()
        {
            ["schemaVersion"] = FixtureDiagnosticScope.SchemaVersion,
            ["nonce"] = diagnostics.Nonce,
            ["sequence"] = 1,
            ["stage"] = "fixture-started",
            ["failureCategory"] = "none",
            ["exitCode"] = null,
            ["elapsedMilliseconds"] = 0,
        };

    private static void VerifyInvalidJson(
        Func<FixtureDiagnosticScope, string> createJson,
        int fileSequence = 1) =>
        VerifyInvalidEvidence(diagnostics =>
            File.WriteAllText(
                Path.Combine(diagnostics.DirectoryPath, $"{fileSequence:D6}.json"),
                createJson(diagnostics),
                new UTF8Encoding(false)));

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
