namespace RisePals.ServiceHost;

public static class Program
{
    public static async Task<int> Main(string[] arguments)
    {
        if (arguments.Length == 2 && arguments[0] == "--validate-config")
        {
            _ = new JsonReleaseConfigurationResolver(arguments[1]).Resolve();
            return 0;
        }

        if (arguments.Length != 2 || arguments[0] != "--config")
        {
            Console.Error.WriteLine("Usage: RisePals.ServiceHost --config <exact-json-path>");
            return 64;
        }

        var configPath = Path.GetFullPath(arguments[1]);
        if (Environment.UserInteractive)
        {
            return await RunConsoleSimulationAsync(configPath).ConfigureAwait(false);
        }

        NativeScmServiceAdapter.Run(ServiceRegistrationIdentity.Candidate, reporter => CreateOrchestrator(configPath, reporter));
        return 0;
    }

    private static async Task<int> RunConsoleSimulationAsync(string configPath)
    {
        var reporter = new ConsoleStatusReporter();
        await using var orchestrator = CreateOrchestrator(configPath, reporter);
        using var cancellation = new CancellationTokenSource();
        Console.CancelKeyPress += (_, eventArgs) =>
        {
            eventArgs.Cancel = true;
            cancellation.Cancel();
        };

        try
        {
            await orchestrator.StartAsync(cancellation.Token).ConfigureAwait(false);
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellation.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
            await orchestrator.StopAsync(false, CancellationToken.None).ConfigureAwait(false);
        }

        return reporter.LastExitCode == 0 ? 0 : 1;
    }

    private static ServiceOrchestrator CreateOrchestrator(string configPath, IServiceStatusReporter reporter)
    {
        var resolver = new JsonReleaseConfigurationResolver(configPath);
        var config = resolver.Resolve();
        var sink = new RotatingSanitizedFileSink(config.LogDirectory);
        return new ServiceOrchestrator(
            reporter,
            new SystemServiceClock(),
            resolver,
            () => new NodeChildProcess(sink),
            () => new WindowsJobObject(),
            pipeName => new NamedPipeDrainTransport(pipeName),
            sink);
    }

    private sealed class ConsoleStatusReporter : IServiceStatusReporter
    {
        public uint LastExitCode { get; private set; }

        public void Report(ServiceStatusUpdate update)
        {
            LastExitCode = update.Win32ExitCode;
            Console.WriteLine($"service-state={update.State};checkpoint={update.Checkpoint};waitHintMs={update.WaitHint.TotalMilliseconds:0}");
        }
    }
}
