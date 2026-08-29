using System.Text.Json;

namespace RisePals.ServiceHost;

public sealed class JsonReleaseConfigurationResolver(string configPath) : IReleaseConfigurationResolver
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = false,
        UnmappedMemberHandling = System.Text.Json.Serialization.JsonUnmappedMemberHandling.Disallow,
    };

    public ReleaseConfiguration Resolve()
    {
        var exactConfigPath = Path.GetFullPath(configPath);
        var payload = File.ReadAllText(exactConfigPath);
        var document = JsonSerializer.Deserialize<ConfigurationDocument>(payload, JsonOptions)
            ?? throw new InvalidDataException("The service-host configuration is empty.");

        var configuration = new ReleaseConfiguration(
            document.ApprovedNodeRoot,
            document.ApprovedReleaseRoot,
            document.NodeExecutable,
            document.ReleaseDirectory,
            document.Entrypoint,
            document.Arguments ?? Array.Empty<string>(),
            document.LogDirectory,
            TimeSpan.FromSeconds(document.StartTimeoutSeconds),
            TimeSpan.FromSeconds(document.DrainTimeoutSeconds),
            TimeSpan.FromSeconds(document.ExitTimeoutSeconds),
            TimeSpan.FromSeconds(document.HealthyResetSeconds),
            document.RestartLimit,
            TimeSpan.FromMilliseconds(document.InitialRestartDelayMilliseconds),
            TimeSpan.FromMilliseconds(document.MaximumRestartDelayMilliseconds));

        ConfigurationValidator.Validate(configuration);
        return configuration;
    }

    private sealed record ConfigurationDocument(
        string ApprovedNodeRoot,
        string ApprovedReleaseRoot,
        string NodeExecutable,
        string ReleaseDirectory,
        string Entrypoint,
        string LogDirectory,
        string[]? Arguments,
        int StartTimeoutSeconds,
        int DrainTimeoutSeconds,
        int ExitTimeoutSeconds,
        int HealthyResetSeconds,
        int RestartLimit,
        int InitialRestartDelayMilliseconds,
        int MaximumRestartDelayMilliseconds);
}

public static class ConfigurationValidator
{
    public static void Validate(ReleaseConfiguration configuration)
    {
        var nodeRoot = RequireDirectory(configuration.ApprovedNodeRoot, "approved Node root");
        var releaseRoot = RequireDirectory(configuration.ApprovedReleaseRoot, "approved release root");
        var nodeExecutable = RequireFile(configuration.NodeExecutable, "Node executable");
        var releaseDirectory = RequireDirectory(configuration.ReleaseDirectory, "release directory");
        var entrypoint = RequireFile(configuration.Entrypoint, "Node entrypoint");
        var logDirectory = Path.GetFullPath(configuration.LogDirectory);

        RequireChild(nodeExecutable, nodeRoot, "Node executable");
        RequireChild(releaseDirectory, releaseRoot, "release directory");
        RequireChild(entrypoint, releaseDirectory, "Node entrypoint");

        if (IsChildOf(logDirectory, releaseDirectory))
        {
            throw new InvalidDataException("The mutable log directory must remain outside the immutable release.");
        }

        if (!string.Equals(Path.GetFileName(nodeExecutable), "node.exe", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("The configured runtime must be the exact node.exe, not npm or a shell.");
        }

        if (configuration.Arguments.Any(argument => argument.Contains('\r') || argument.Contains('\n')))
        {
            throw new InvalidDataException("Runtime arguments must be structured single-line values.");
        }

        if (configuration.StartTimeout <= TimeSpan.Zero ||
            configuration.DrainTimeout <= TimeSpan.Zero ||
            configuration.ExitTimeout <= TimeSpan.Zero ||
            configuration.RestartLimit < 0 ||
            configuration.InitialRestartDelay < TimeSpan.Zero ||
            configuration.MaximumRestartDelay < configuration.InitialRestartDelay)
        {
            throw new InvalidDataException("Service-host timing and restart bounds are invalid.");
        }
    }

    public static bool IsChildOf(string candidate, string root)
    {
        var exactCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var exactRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return exactCandidate.StartsWith(exactRoot, StringComparison.OrdinalIgnoreCase);
    }

    private static string RequireFile(string path, string label)
    {
        var exact = Path.GetFullPath(path);
        if (!File.Exists(exact))
        {
            throw new FileNotFoundException($"The configured {label} does not exist.", exact);
        }

        return exact;
    }

    private static string RequireDirectory(string path, string label)
    {
        var exact = Path.GetFullPath(path);
        if (!Directory.Exists(exact))
        {
            throw new DirectoryNotFoundException($"The configured {label} does not exist: {exact}");
        }

        return exact;
    }

    private static void RequireChild(string candidate, string root, string label)
    {
        if (!IsChildOf(candidate, root))
        {
            throw new InvalidDataException($"The configured {label} is outside its approved root.");
        }
    }
}
