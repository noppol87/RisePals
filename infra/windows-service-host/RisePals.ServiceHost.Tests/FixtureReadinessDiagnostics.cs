using System.Diagnostics;
using System.Globalization;
using System.Runtime.ExceptionServices;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

internal sealed record FixtureDiagnosticRecord(
    [property: JsonPropertyName("schemaVersion")] int SchemaVersion,
    [property: JsonPropertyName("nonce")] string Nonce,
    [property: JsonPropertyName("sequence")] int Sequence,
    [property: JsonPropertyName("stage")] string Stage,
    [property: JsonPropertyName("failureCategory")] string FailureCategory,
    [property: JsonPropertyName("exitCode")] int? ExitCode,
    [property: JsonPropertyName("elapsedMilliseconds")] long ElapsedMilliseconds);

internal sealed class FixtureReadinessDiagnosticException(
    string primaryCategory,
    string primaryStage,
    int? exitCode,
    string diagnosticValidity = "not-observed",
    string diagnosticStage = "none",
    string diagnosticFailureCategory = "none",
    Exception? innerException = null)
    : Exception(
        $"Fixture readiness failed: primaryCategory={primaryCategory}; primaryStage={primaryStage}; " +
        $"exitCode={(exitCode?.ToString(CultureInfo.InvariantCulture) ?? "none")}; " +
        $"diagnosticValidity={diagnosticValidity}; diagnosticStage={diagnosticStage}; " +
        $"diagnosticFailureCategory={diagnosticFailureCategory}.",
        innerException)
{
    public string Category { get; } = primaryCategory;

    public string PrimaryCategory { get; } = primaryCategory;

    public string Stage { get; } = primaryStage;

    public string PrimaryStage { get; } = primaryStage;

    public int? ControlledExitCode { get; } = exitCode;

    public string DiagnosticValidity { get; } = diagnosticValidity;

    public string DiagnosticStage { get; } = diagnosticStage;

    public string DiagnosticFailureCategory { get; } = diagnosticFailureCategory;
}

internal sealed record FixtureDiagnosticObservation(
    string Validity,
    IReadOnlyList<FixtureDiagnosticRecord> Records,
    string Stage,
    string FailureCategory,
    int? ExitCode);

internal enum DiagnosticFixtureStartupFailurePoint
{
    None,
    ResolveExecutable,
    ResolveFixture,
    ConstructProcessStartInfo,
    ApplyEnvironment,
}

internal sealed class FixtureDiagnosticScope : IDisposable
{
    internal const int SchemaVersion = 1;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    private static readonly Regex RecordName = new("^[0-9]{6}\\.json$", RegexOptions.CultureInvariant);
    private static readonly string[] RequiredPropertyNames =
    [
        "schemaVersion",
        "nonce",
        "sequence",
        "stage",
        "failureCategory",
        "exitCode",
        "elapsedMilliseconds",
    ];
    private static readonly HashSet<string> RequiredProperties = new(RequiredPropertyNames, StringComparer.Ordinal);
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };
    private static readonly HashSet<string> AllowedStages =
    [
        "fixture-started",
        "pipe-connection-attempted",
        "pipe-connected",
        "ready-write-attempted",
        "ready-write-completed",
        "fixture-exit-recorded",
    ];
    private static readonly HashSet<string> AllowedFailureCategories =
    [
        "none",
        "connection-failure",
        "ready-write-failure",
        "controlled-fixture-exit",
    ];

    private bool _disposed;

    private FixtureDiagnosticScope(string nonce, string directoryPath)
    {
        Nonce = nonce;
        DirectoryPath = directoryPath;
    }

    public string Nonce { get; }

    public string DirectoryPath { get; }

    public static FixtureDiagnosticScope Create()
    {
        var nonce = Guid.NewGuid().ToString("N");
        var directoryPath = Path.GetFullPath(Path.Combine(Path.GetTempPath(), $"risepals-servicehost-diagnostic-{nonce}"));
        ValidateBoundPath(directoryPath, nonce, mustExist: false);
        Directory.CreateDirectory(directoryPath);
        ValidateBoundPath(directoryPath, nonce, mustExist: true);
        return new FixtureDiagnosticScope(nonce, directoryPath);
    }

    public void ApplyTo(ProcessStartInfo startInfo)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        startInfo.Environment["RISEPALS_FIXTURE_DIAGNOSTIC_DIRECTORY"] = DirectoryPath;
        startInfo.Environment["RISEPALS_FIXTURE_DIAGNOSTIC_NONCE"] = Nonce;
        startInfo.Environment["RISEPALS_FIXTURE_DIAGNOSTIC_ROOT"] = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
    }

    public IReadOnlyList<FixtureDiagnosticRecord> ReadAndValidate()
    {
        var snapshot = ReadSnapshot(allowAtomicWriteInProgress: false);
        return snapshot.Records;
    }

    internal FixtureDiagnosticObservation ObserveSnapshot()
    {
        try
        {
            return ReadSnapshot(allowAtomicWriteInProgress: true);
        }
        catch (InvalidDataException)
        {
            return new FixtureDiagnosticObservation("invalid", [], "invalid-evidence", "none", null);
        }
        catch (IOException)
        {
            return new FixtureDiagnosticObservation("incomplete", [], "atomic-publication-race", "none", null);
        }
    }

    internal void WriteSynthetic(FixtureDiagnosticRecord record)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        var finalPath = Path.Combine(DirectoryPath, $"{record.Sequence:D6}.json");
        var temporaryPath = $"{finalPath}.{Nonce}.tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(record, JsonOptions) + "\n", StrictUtf8);
        File.Move(temporaryPath, finalPath);
    }

    internal (string TemporaryPath, string FinalPath) WriteSyntheticInterrupted(FixtureDiagnosticRecord record)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        var finalPath = Path.Combine(DirectoryPath, $"{record.Sequence:D6}.json");
        var temporaryPath = $"{finalPath}.{Nonce}.tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(record, JsonOptions) + "\n", StrictUtf8);
        return (temporaryPath, finalPath);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        var files = ValidateCleanupTarget();
        foreach (var file in files)
        {
            File.Delete(file);
        }

        Directory.Delete(DirectoryPath, recursive: false);
        _disposed = true;
    }

    private FixtureDiagnosticObservation ReadSnapshot(bool allowAtomicWriteInProgress)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        var entries = new DirectoryInfo(DirectoryPath).EnumerateFileSystemInfos().OrderBy(entry => entry.Name, StringComparer.Ordinal).ToArray();
        if (entries.Length > 16)
        {
            throw new InvalidDataException("Fixture diagnostic evidence exceeded the record bound.");
        }

        var finalFiles = new List<FileInfo>(entries.Length);
        FileInfo? inProgress = null;
        foreach (var entry in entries)
        {
            if (entry is not FileInfo file || (entry.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("Fixture diagnostic evidence contained an unexpected object.");
            }

            ValidateDirectChild(file.FullName);
            if (RecordName.IsMatch(file.Name))
            {
                if (file.Length is <= 0 or > 1024)
                {
                    throw new InvalidDataException("Fixture diagnostic evidence exceeded its file bound.");
                }

                finalFiles.Add(file);
                continue;
            }

            if (!TryParseAtomicTemporaryName(file.Name, out _) || inProgress is not null || file.Length > 1024)
            {
                throw new InvalidDataException("Fixture diagnostic evidence contained an unexpected or non-atomic object.");
            }

            inProgress = file;
        }

        var records = new List<FixtureDiagnosticRecord>(finalFiles.Count);
        foreach (var file in finalFiles)
        {
            records.Add(ReadExactRecord(file));
        }

        ValidateRecords(records);
        if (inProgress is not null)
        {
            if (!allowAtomicWriteInProgress ||
                !TryParseAtomicTemporaryName(inProgress.Name, out var temporarySequence) ||
                temporarySequence != records.Count + 1)
            {
                throw new InvalidDataException("Fixture diagnostic evidence contained an invalid atomic-write remainder.");
            }

            var last = records.Count == 0 ? null : records[^1];
            return new FixtureDiagnosticObservation(
                "incomplete",
                records,
                last?.Stage ?? "atomic-write-in-progress",
                last?.FailureCategory ?? "none",
                last?.ExitCode);
        }

        var current = records.Count == 0 ? null : records[^1];
        return new FixtureDiagnosticObservation(
            "valid",
            records,
            current?.Stage ?? "no-records",
            current?.FailureCategory ?? "none",
            current?.ExitCode);
    }

    private static FixtureDiagnosticRecord ReadExactRecord(FileInfo file)
    {
        try
        {
            var text = StrictUtf8.GetString(File.ReadAllBytes(file.FullName));
            using var document = JsonDocument.Parse(text, new JsonDocumentOptions
            {
                AllowTrailingCommas = false,
                CommentHandling = JsonCommentHandling.Disallow,
            });
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidDataException("Fixture diagnostic evidence was not an object.");
            }

            var properties = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
            foreach (var property in document.RootElement.EnumerateObject())
            {
                if (!RequiredProperties.Contains(property.Name) || !properties.TryAdd(property.Name, property.Value))
                {
                    throw new InvalidDataException("Fixture diagnostic evidence violated its exact property set.");
                }
            }

            if (properties.Count != RequiredPropertyNames.Length || RequiredPropertyNames.Any(name => !properties.ContainsKey(name)))
            {
                throw new InvalidDataException("Fixture diagnostic evidence omitted a required property.");
            }

            if (properties["schemaVersion"].ValueKind != JsonValueKind.Number ||
                !properties["schemaVersion"].TryGetInt32(out var schemaVersion) ||
                properties["nonce"].ValueKind != JsonValueKind.String ||
                properties["sequence"].ValueKind != JsonValueKind.Number ||
                !properties["sequence"].TryGetInt32(out var sequence) ||
                properties["stage"].ValueKind != JsonValueKind.String ||
                properties["failureCategory"].ValueKind != JsonValueKind.String ||
                properties["elapsedMilliseconds"].ValueKind != JsonValueKind.Number ||
                !properties["elapsedMilliseconds"].TryGetInt64(out var elapsedMilliseconds))
            {
                throw new InvalidDataException("Fixture diagnostic evidence contained an incorrectly typed property.");
            }

            int? exitCode = properties["exitCode"].ValueKind switch
            {
                JsonValueKind.Null => null,
                JsonValueKind.Number when properties["exitCode"].TryGetInt32(out var value) => value,
                _ => throw new InvalidDataException("Fixture diagnostic exitCode was incorrectly typed."),
            };
            var record = new FixtureDiagnosticRecord(
                schemaVersion,
                properties["nonce"].GetString()!,
                sequence,
                properties["stage"].GetString()!,
                properties["failureCategory"].GetString()!,
                exitCode,
                elapsedMilliseconds);
            if (!string.Equals(file.Name, $"{record.Sequence:D6}.json", StringComparison.Ordinal))
            {
                throw new InvalidDataException("Fixture diagnostic filename did not match its sequence.");
            }

            return record;
        }
        catch (Exception exception) when (exception is JsonException or DecoderFallbackException)
        {
            throw new InvalidDataException("Fixture diagnostic evidence was malformed.", exception);
        }
    }

    private string[] ValidateCleanupTarget()
    {
        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        var entries = new DirectoryInfo(DirectoryPath).EnumerateFileSystemInfos().ToArray();
        if (entries.Length > 16)
        {
            throw new InvalidDataException("Fixture diagnostic cleanup exceeded the object bound.");
        }

        var files = new List<string>(entries.Length);
        foreach (var entry in entries)
        {
            if (entry is not FileInfo file || (entry.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("Fixture diagnostic cleanup rejected a directory or reparse object.");
            }

            ValidateDirectChild(file.FullName);
            if (!RecordName.IsMatch(file.Name) && !TryParseAtomicTemporaryName(file.Name, out _))
            {
                throw new InvalidDataException("Fixture diagnostic cleanup rejected an unattributable file.");
            }

            files.Add(file.FullName);
        }

        return files.ToArray();
    }

    private void ValidateDirectChild(string path)
    {
        var canonical = Path.GetFullPath(path);
        if (!string.Equals(Path.GetDirectoryName(canonical), DirectoryPath, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Fixture diagnostic object escaped its bound directory.");
        }
    }

    private bool TryParseAtomicTemporaryName(string name, out int sequence)
    {
        sequence = 0;
        var suffix = $".{Nonce}.tmp";
        if (!name.EndsWith(suffix, StringComparison.Ordinal))
        {
            return false;
        }

        var finalName = name[..^suffix.Length];
        return RecordName.IsMatch(finalName) && int.TryParse(finalName[..6], NumberStyles.None, CultureInfo.InvariantCulture, out sequence);
    }

    private static void ValidateBoundPath(string directoryPath, string nonce, bool mustExist)
    {
        if (nonce.Length != 32 || nonce.Any(character => !Uri.IsHexDigit(character) || char.IsUpper(character)))
        {
            throw new InvalidDataException("Fixture diagnostic nonce was invalid.");
        }

        var tempRoot = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar);
        var expected = Path.GetFullPath(Path.Combine(tempRoot, $"risepals-servicehost-diagnostic-{nonce}"));
        if (!string.Equals(directoryPath, expected, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(Path.GetDirectoryName(directoryPath), tempRoot, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Fixture diagnostic path escaped its task-scoped boundary.");
        }

        if (!mustExist)
        {
            if (Directory.Exists(directoryPath) || File.Exists(directoryPath))
            {
                throw new InvalidDataException("Fixture diagnostic path was replayed.");
            }

            return;
        }

        var directory = new DirectoryInfo(directoryPath);
        if (!directory.Exists || (directory.Attributes & FileAttributes.ReparsePoint) != 0)
        {
            throw new InvalidDataException("Fixture diagnostic directory was absent or a reparse point.");
        }
    }

    private void ValidateRecords(List<FixtureDiagnosticRecord> records)
    {
        long previousElapsed = -1;
        string? previousStage = null;
        for (var index = 0; index < records.Count; index++)
        {
            var record = records[index];
            if (record.SchemaVersion != SchemaVersion ||
                !string.Equals(record.Nonce, Nonce, StringComparison.Ordinal) ||
                record.Sequence != index + 1 ||
                !AllowedStages.Contains(record.Stage) ||
                !AllowedFailureCategories.Contains(record.FailureCategory) ||
                record.ElapsedMilliseconds < 0 ||
                record.ElapsedMilliseconds < previousElapsed ||
                record.ElapsedMilliseconds > 30_000)
            {
                throw new InvalidDataException("Fixture diagnostic evidence violated its closed schema or monotonic bounds.");
            }

            if (!IsAllowedTransition(previousStage, record))
            {
                throw new InvalidDataException("Fixture diagnostic evidence was stale, replayed or out of sequence.");
            }

            previousElapsed = record.ElapsedMilliseconds;
            previousStage = record.Stage;
        }
    }

    private static bool IsAllowedTransition(string? previousStage, FixtureDiagnosticRecord record)
    {
        if (record.Stage == "fixture-exit-recorded")
        {
            return record.FailureCategory switch
            {
                "controlled-fixture-exit" =>
                    (previousStage == "fixture-started" && record.ExitCode == 74) ||
                    (previousStage == "pipe-connected" && record.ExitCode == 75),
                "connection-failure" => previousStage == "pipe-connection-attempted" && record.ExitCode == 72,
                "ready-write-failure" => previousStage == "ready-write-attempted" && record.ExitCode == 76,
                _ => false,
            };
        }

        if (record.FailureCategory != "none" || record.ExitCode is not null)
        {
            return false;
        }

        return (previousStage, record.Stage) switch
        {
            (null, "fixture-started") => true,
            ("fixture-started", "pipe-connection-attempted") => true,
            ("pipe-connection-attempted", "pipe-connected") => true,
            ("pipe-connected", "ready-write-attempted") => true,
            ("ready-write-attempted", "ready-write-completed") => true,
            _ => false,
        };
    }
}

internal sealed class DiagnosticNodeFixture : IAsyncDisposable
{
    private DiagnosticNodeFixture(Process process, FixtureDiagnosticScope diagnostics)
    {
        Process = process;
        Diagnostics = diagnostics;
    }

    public Process Process { get; }

    public FixtureDiagnosticScope Diagnostics { get; }

    public static DiagnosticNodeFixture Start(
        string pipeName,
        string mode,
        string? executableOverride = null,
        DiagnosticFixtureStartupFailurePoint failurePoint = DiagnosticFixtureStartupFailurePoint.None)
    {
        var diagnostics = FixtureDiagnosticScope.Create();
        var startupStage = "diagnostic-scope-created";
        try
        {
            startupStage = "executable-resolution";
            ThrowIfInjected(failurePoint, DiagnosticFixtureStartupFailurePoint.ResolveExecutable);
            var executable = executableOverride ?? ResolveNode();

            startupStage = "fixture-resolution";
            ThrowIfInjected(failurePoint, DiagnosticFixtureStartupFailurePoint.ResolveFixture);
            var fixturePath = ResolveFixture();

            startupStage = "process-start-info-construction";
            ThrowIfInjected(failurePoint, DiagnosticFixtureStartupFailurePoint.ConstructProcessStartInfo);
            var info = new ProcessStartInfo
            {
                FileName = executable,
                WorkingDirectory = Path.GetDirectoryName(fixturePath)!,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            info.ArgumentList.Add(fixturePath);
            info.ArgumentList.Add(mode);

            startupStage = "environment-setup";
            ThrowIfInjected(failurePoint, DiagnosticFixtureStartupFailurePoint.ApplyEnvironment);
            info.Environment["RISEPALS_DRAIN_PIPE"] = pipeName;
            diagnostics.ApplyTo(info);

            startupStage = "process-start";
            var process = Process.Start(info);
            if (process is null)
            {
                throw new InvalidOperationException("Synthetic Node fixture did not start.");
            }

            return new DiagnosticNodeFixture(process, diagnostics);
        }
        catch (Exception exception)
        {
            try
            {
                diagnostics.Dispose();
            }
            catch (Exception cleanupException)
            {
                throw new FixtureReadinessDiagnosticException(
                    "process-setup-failure",
                    "startup-cleanup",
                    null,
                    innerException: new AggregateException(exception, cleanupException));
            }

            throw new FixtureReadinessDiagnosticException("process-setup-failure", startupStage, null, innerException: exception);
        }
    }

    public async ValueTask DisposeAsync()
    {
        Exception? processCleanupFailure = null;
        try
        {
            if (!Process.HasExited)
            {
                Process.Kill(true);
                await Process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3)).ConfigureAwait(false);
            }
        }
        catch (Exception exception)
        {
            processCleanupFailure = exception;
        }
        finally
        {
            Process.Dispose();
        }

        try
        {
            Diagnostics.Dispose();
        }
        catch (Exception diagnosticCleanupFailure)
        {
            if (processCleanupFailure is not null)
            {
                throw new AggregateException(processCleanupFailure, diagnosticCleanupFailure);
            }

            throw;
        }

        if (processCleanupFailure is not null)
        {
            ExceptionDispatchInfo.Capture(processCleanupFailure).Throw();
        }
    }

    private static void ThrowIfInjected(
        DiagnosticFixtureStartupFailurePoint actual,
        DiagnosticFixtureStartupFailurePoint expected)
    {
        if (actual == expected)
        {
            throw new InvalidOperationException("Controlled fixture startup setup failure.");
        }
    }

    private static string ResolveNode()
    {
        var entries = (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator);
        return entries.Select(entry => Path.Combine(entry, "node.exe")).FirstOrDefault(File.Exists)
            ?? throw new InvalidOperationException("Pinned Node executable is unavailable.");
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
}

internal static class FixtureReadinessObserver
{
    private static readonly TimeSpan DiagnosticSettlementBound = TimeSpan.FromSeconds(1);

    public static async Task<IReadOnlyList<FixtureDiagnosticRecord>> WaitForFixtureStartupAsync(
        DiagnosticNodeFixture fixture,
        TimeSpan setupTimeout,
        CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        FixtureDiagnosticObservation observation = new("incomplete", [], "no-records", "none", null);
        while (stopwatch.Elapsed < setupTimeout)
        {
            observation = fixture.Diagnostics.ObserveSnapshot();
            if (observation.Validity == "invalid")
            {
                throw Failure("fixture-setup-failure", "startup-observation", null, observation);
            }

            if (observation.Records.Count > 0 &&
                observation.Records[0].Stage == "fixture-started")
            {
                return observation.Records;
            }

            if (fixture.Process.HasExited)
            {
                throw Failure("fixture-setup-process-exit", "startup-observation", fixture.Process.ExitCode, observation);
            }

            await Task.Delay(10, cancellationToken).ConfigureAwait(false);
        }

        throw Failure(
            "fixture-setup-timeout",
            "startup-observation",
            fixture.Process.HasExited ? fixture.Process.ExitCode : null,
            observation with { Validity = "incomplete" });
    }

    public static async Task<IReadOnlyList<FixtureDiagnosticRecord>> WaitForReadyAsync(
        NamedPipeDrainTransport transport,
        DiagnosticNodeFixture fixture,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var readyTask = transport.WaitForReadyAsync(timeout, linked.Token);
        var exitTask = fixture.Process.WaitForExitAsync(linked.Token);
        var completed = await Task.WhenAny(readyTask, exitTask).ConfigureAwait(false);

        if (completed == exitTask)
        {
            await exitTask.ConfigureAwait(false);
            linked.Cancel();
            await ObserveCancellationAsync(readyTask).ConfigureAwait(false);
            var observation = await ObserveDiagnosticsAsync(fixture, requiredFinalStage: null).ConfigureAwait(false);
            throw Failure("process-exit-before-ready", "readiness-race", fixture.Process.ExitCode, observation);
        }

        linked.Cancel();
        await ObserveCancellationAsync(exitTask).ConfigureAwait(false);
        try
        {
            await readyTask.ConfigureAwait(false);
        }
        catch (TimeoutException exception)
        {
            var observation = await ObserveDiagnosticsAsync(fixture, requiredFinalStage: null).ConfigureAwait(false);
            throw Failure(
                "readiness-timeout",
                "readiness-wait",
                fixture.Process.HasExited ? fixture.Process.ExitCode : null,
                observation,
                exception);
        }
        catch (DrainProtocolException exception)
        {
            var observation = await ObserveDiagnosticsAsync(fixture, "ready-write-completed").ConfigureAwait(false);
            var controlledExit = observation.Stage == "fixture-exit-recorded" &&
                observation.FailureCategory == "controlled-fixture-exit" &&
                observation.ExitCode is not null;
            throw Failure(
                controlledExit ? "process-exit-before-ready" : "protocol-failure",
                controlledExit ? "readiness-race" : "ready-protocol",
                observation.ExitCode ?? (fixture.Process.HasExited ? fixture.Process.ExitCode : null),
                observation,
                exception);
        }

        var validated = await ObserveDiagnosticsAsync(fixture, "ready-write-completed").ConfigureAwait(false);
        if (validated.Validity != "valid" || validated.Stage != "ready-write-completed")
        {
            throw Failure(
                "diagnostic-evidence-incomplete",
                "post-ready-diagnostic",
                fixture.Process.HasExited ? fixture.Process.ExitCode : null,
                validated);
        }

        return validated.Records;
    }

    private static async Task<FixtureDiagnosticObservation> ObserveDiagnosticsAsync(
        DiagnosticNodeFixture fixture,
        string? requiredFinalStage)
    {
        var stopwatch = Stopwatch.StartNew();
        FixtureDiagnosticObservation? previous = null;
        FixtureDiagnosticObservation current = new("incomplete", [], "no-records", "none", null);
        while (stopwatch.Elapsed < DiagnosticSettlementBound)
        {
            current = fixture.Diagnostics.ObserveSnapshot();
            if (current.Validity == "invalid")
            {
                return current;
            }

            if (current.Validity == "valid" &&
                (requiredFinalStage is not null
                    ? current.Stage == requiredFinalStage || current.Stage == "fixture-exit-recorded"
                    : previous is not null && current.Records.SequenceEqual(previous.Records)))
            {
                return current;
            }

            previous = current;
            await Task.Delay(10).ConfigureAwait(false);
        }

        return current.Validity == "valid" && requiredFinalStage is null
            ? current
            : current with { Validity = "incomplete" };
    }

    private static FixtureReadinessDiagnosticException Failure(
        string primaryCategory,
        string primaryStage,
        int? exitCode,
        FixtureDiagnosticObservation observation,
        Exception? innerException = null) =>
        new(
            primaryCategory,
            primaryStage,
            exitCode,
            observation.Validity,
            observation.Stage,
            observation.FailureCategory,
            innerException);

    private static async Task ObserveCancellationAsync(Task task)
    {
        try
        {
            await task.ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            // The competing readiness or process-exit observation completed first.
        }
        catch
        {
            // The authoritative task is awaited separately by the caller.
        }
    }
}
