using System.Diagnostics;
using System.Globalization;
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
    string category,
    string stage,
    int? exitCode,
    Exception? innerException = null)
    : Exception($"Fixture readiness failed: category={category}; stage={stage}; exitCode={(exitCode?.ToString(CultureInfo.InvariantCulture) ?? "none")}.", innerException)
{
    public string Category { get; } = category;

    public string Stage { get; } = stage;

    public int? ControlledExitCode { get; } = exitCode;
}

internal sealed class FixtureDiagnosticScope : IDisposable
{
    internal const int SchemaVersion = 1;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    private static readonly Regex RecordName = new("^[0-9]{6}\\.json$", RegexOptions.CultureInvariant);
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
        ObjectDisposedException.ThrowIf(_disposed, this);
        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        var entries = new DirectoryInfo(DirectoryPath).EnumerateFileSystemInfos().OrderBy(entry => entry.Name, StringComparer.Ordinal).ToArray();
        if (entries.Length > 16)
        {
            throw new InvalidDataException("Fixture diagnostic evidence exceeded the record bound.");
        }

        var records = new List<FixtureDiagnosticRecord>(entries.Length);
        foreach (var entry in entries)
        {
            if (entry is not FileInfo file ||
                (entry.Attributes & FileAttributes.ReparsePoint) != 0 ||
                !RecordName.IsMatch(entry.Name) ||
                file.Length is <= 0 or > 1024)
            {
                throw new InvalidDataException("Fixture diagnostic evidence contained an unexpected or non-atomic object.");
            }

            var expectedPath = Path.GetFullPath(Path.Combine(DirectoryPath, entry.Name));
            if (!string.Equals(expectedPath, file.FullName, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("Fixture diagnostic evidence escaped its bound directory.");
            }

            FixtureDiagnosticRecord record;
            try
            {
                var bytes = File.ReadAllBytes(expectedPath);
                var text = StrictUtf8.GetString(bytes);
                record = JsonSerializer.Deserialize<FixtureDiagnosticRecord>(text, JsonOptions)
                    ?? throw new InvalidDataException("Fixture diagnostic evidence was empty.");
            }
            catch (Exception exception) when (exception is JsonException or DecoderFallbackException)
            {
                throw new InvalidDataException("Fixture diagnostic evidence was malformed.", exception);
            }

            records.Add(record);
        }

        ValidateRecords(records);
        return records;
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

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        ValidateBoundPath(DirectoryPath, Nonce, mustExist: true);
        foreach (var entry in new DirectoryInfo(DirectoryPath).EnumerateFileSystemInfos())
        {
            if ((entry.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("Fixture diagnostic cleanup rejected a reparse point.");
            }
        }

        Directory.Delete(DirectoryPath, true);
        _disposed = true;
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

    public static DiagnosticNodeFixture Start(string pipeName, string mode, string? executableOverride = null)
    {
        var diagnostics = FixtureDiagnosticScope.Create();
        var info = new ProcessStartInfo
        {
            FileName = executableOverride ?? ResolveNode(),
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
        diagnostics.ApplyTo(info);

        try
        {
            var process = Process.Start(info);
            if (process is null)
            {
                throw new InvalidOperationException("Synthetic Node fixture did not start.");
            }

            return new DiagnosticNodeFixture(process, diagnostics);
        }
        catch (Exception exception)
        {
            diagnostics.Dispose();
            throw new FixtureReadinessDiagnosticException("process-not-created", "process-not-created", null, exception);
        }
    }

    public async ValueTask DisposeAsync()
    {
        try
        {
            if (!Process.HasExited)
            {
                Process.Kill(true);
                await Process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3)).ConfigureAwait(false);
            }
        }
        finally
        {
            Process.Dispose();
            Diagnostics.Dispose();
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
            var records = fixture.Diagnostics.ReadAndValidate();
            var last = records.Count == 0 ? null : records[^1];
            throw new FixtureReadinessDiagnosticException(
                last?.FailureCategory == "none" ? "fixture-exited-before-ready" : last?.FailureCategory ?? "fixture-exited-before-ready",
                last?.Stage ?? "process-created",
                fixture.Process.ExitCode);
        }

        linked.Cancel();
        await ObserveCancellationAsync(exitTask).ConfigureAwait(false);
        try
        {
            await readyTask.ConfigureAwait(false);
        }
        catch (TimeoutException exception)
        {
            var records = fixture.Diagnostics.ReadAndValidate();
            var last = records.Count == 0 ? null : records[^1];
            throw new FixtureReadinessDiagnosticException(
                fixture.Process.HasExited ? "fixture-exited-before-ready" : "readiness-timeout-fixture-alive",
                last?.Stage ?? "process-created",
                fixture.Process.HasExited ? fixture.Process.ExitCode : null,
                exception);
        }
        catch (DrainProtocolException exception)
        {
            var records = await WaitForReadyWriteEvidenceAsync(fixture).ConfigureAwait(false);
            var last = records.Count == 0 ? null : records[^1];
            throw new FixtureReadinessDiagnosticException(
                last?.FailureCategory is not null and not "none" ? last.FailureCategory : "invalid-ready",
                last?.Stage ?? "process-created",
                last?.ExitCode ?? (fixture.Process.HasExited ? fixture.Process.ExitCode : null),
                exception);
        }

        var validated = await WaitForReadyWriteEvidenceAsync(fixture).ConfigureAwait(false);
        var lastValidated = validated.Count == 0 ? null : validated[^1];
        if (lastValidated?.Stage != "ready-write-completed")
        {
            throw new FixtureReadinessDiagnosticException(
                "diagnostic-evidence-incomplete",
                lastValidated?.Stage ?? "process-created",
                fixture.Process.HasExited ? fixture.Process.ExitCode : null);
        }

        return validated;
    }

    private static async Task<IReadOnlyList<FixtureDiagnosticRecord>> WaitForReadyWriteEvidenceAsync(DiagnosticNodeFixture fixture)
    {
        var stopwatch = Stopwatch.StartNew();
        Exception? lastFailure = null;
        while (stopwatch.Elapsed < DiagnosticSettlementBound)
        {
            try
            {
                var records = fixture.Diagnostics.ReadAndValidate();
                var last = records.Count == 0 ? null : records[^1];
                if (last?.Stage is "ready-write-completed" or "fixture-exit-recorded")
                {
                    return records;
                }
            }
            catch (InvalidDataException exception)
            {
                lastFailure = exception;
            }

            await Task.Delay(10).ConfigureAwait(false);
        }

        throw new FixtureReadinessDiagnosticException(
            "diagnostic-evidence-incomplete",
            "diagnostic-settlement-timeout",
            fixture.Process.HasExited ? fixture.Process.ExitCode : null,
            lastFailure);
    }

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
