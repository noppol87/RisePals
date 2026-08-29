using System.Runtime.InteropServices;

namespace RisePals.ServiceHost;

public sealed class WindowsScmStatusReporter : IServiceStatusReporter
{
    private readonly IntPtr _statusHandle;

    public WindowsScmStatusReporter(IntPtr statusHandle) => _statusHandle = statusHandle;

    public void Report(ServiceStatusUpdate update)
    {
        var status = new NativeScm.ServiceStatus
        {
            ServiceType = NativeScm.ServiceWin32OwnProcess,
            CurrentState = update.State switch
            {
                ServiceLifecycleState.Stopped => NativeScm.ServiceStopped,
                ServiceLifecycleState.StartPending => NativeScm.ServiceStartPending,
                ServiceLifecycleState.StopPending => NativeScm.ServiceStopPending,
                ServiceLifecycleState.Running => NativeScm.ServiceRunning,
                _ => throw new ArgumentOutOfRangeException(nameof(update)),
            },
            ControlsAccepted = update.State == ServiceLifecycleState.Running
                ? NativeScm.ServiceAcceptStop | NativeScm.ServiceAcceptShutdown | NativeScm.ServiceAcceptPreshutdown
                : 0,
            Win32ExitCode = update.ServiceSpecificExitCode == 0 ? update.Win32ExitCode : NativeScm.ErrorServiceSpecificError,
            ServiceSpecificExitCode = update.ServiceSpecificExitCode,
            CheckPoint = update.Checkpoint,
            WaitHint = checked((uint)Math.Clamp(update.WaitHint.TotalMilliseconds, 0, uint.MaxValue)),
        };

        if (!NativeScm.SetServiceStatus(_statusHandle, ref status))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}

public static class NativeScmServiceAdapter
{
    private static readonly ManualResetEventSlim Finished = new(false);
    private static readonly NativeScm.ServiceMainFunction ServiceMainDelegate = ServiceMain;
    private static readonly NativeScm.HandlerFunction HandlerDelegate = Handler;
    private static Func<IServiceStatusReporter, ServiceOrchestrator>? _factory;
    private static ServiceOrchestrator? _orchestrator;
    private static int _stopDispatched;

    public static void Run(string serviceName, Func<IServiceStatusReporter, ServiceOrchestrator> factory)
    {
        _factory = factory;
        var table = new[]
        {
            new NativeScm.ServiceTableEntry { ServiceName = serviceName, ServiceMain = ServiceMainDelegate },
            new NativeScm.ServiceTableEntry(),
        };

        if (!NativeScm.StartServiceCtrlDispatcher(table))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
    }

    private static void ServiceMain(uint argumentCount, IntPtr arguments)
    {
        _ = argumentCount;
        _ = arguments;
        var statusHandle = NativeScm.RegisterServiceControlHandler("RisePalsApp", HandlerDelegate, IntPtr.Zero);
        if (statusHandle == IntPtr.Zero)
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        var reporter = new WindowsScmStatusReporter(statusHandle);
        _orchestrator = (_factory ?? throw new InvalidOperationException("SCM factory is unavailable."))(reporter);
        try
        {
            _orchestrator.StartAsync(CancellationToken.None).GetAwaiter().GetResult();
            Finished.Wait();
        }
        catch
        {
            reporter.Report(new ServiceStatusUpdate(ServiceLifecycleState.Stopped, 0, TimeSpan.Zero, 1, 0x5250_0003));
            throw;
        }
        finally
        {
            _orchestrator.DisposeAsync().AsTask().GetAwaiter().GetResult();
        }
    }

    private static uint Handler(uint control, uint eventType, IntPtr eventData, IntPtr context)
    {
        _ = eventType;
        _ = eventData;
        _ = context;
        var preshutdown = control == NativeScm.ServiceControlPreshutdown;
        if (control is not (NativeScm.ServiceControlStop or NativeScm.ServiceControlShutdown or NativeScm.ServiceControlPreshutdown))
        {
            return NativeScm.ErrorCallNotImplemented;
        }

        if (Interlocked.Exchange(ref _stopDispatched, 1) != 0)
        {
            return 0;
        }

        _ = Task.Run(async () =>
        {
            try
            {
                await (_orchestrator ?? throw new InvalidOperationException("The SCM stop arrived before service initialization."))
                    .StopAsync(preshutdown, CancellationToken.None)
                    .ConfigureAwait(false);
            }
            finally
            {
                Finished.Set();
            }
        });
        return 0;
    }
}

public static class NativeScm
{
    public const uint ServiceWin32OwnProcess = 0x00000010;
    public const uint ServiceStopped = 0x00000001;
    public const uint ServiceStartPending = 0x00000002;
    public const uint ServiceStopPending = 0x00000003;
    public const uint ServiceRunning = 0x00000004;
    public const uint ServiceControlStop = 0x00000001;
    public const uint ServiceControlShutdown = 0x00000005;
    public const uint ServiceControlPreshutdown = 0x0000000F;
    public const uint ServiceAcceptStop = 0x00000001;
    public const uint ServiceAcceptShutdown = 0x00000004;
    public const uint ServiceAcceptPreshutdown = 0x00000100;
    public const uint ServiceConfigPreshutdownInfo = 7;
    public const uint ErrorCallNotImplemented = 120;
    public const uint ErrorServiceSpecificError = 1066;

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    public delegate void ServiceMainFunction(uint argumentCount, IntPtr arguments);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    public delegate uint HandlerFunction(uint control, uint eventType, IntPtr eventData, IntPtr context);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct ServiceTableEntry
    {
        [MarshalAs(UnmanagedType.LPWStr)]
        public string? ServiceName;

        public ServiceMainFunction? ServiceMain;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ServiceStatus
    {
        public uint ServiceType;
        public uint CurrentState;
        public uint ControlsAccepted;
        public uint Win32ExitCode;
        public uint ServiceSpecificExitCode;
        public uint CheckPoint;
        public uint WaitHint;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ServicePreshutdownInfo
    {
        public uint PreshutdownTimeoutMilliseconds;
    }

    [DllImport("advapi32.dll", EntryPoint = "StartServiceCtrlDispatcherW", SetLastError = true, CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool StartServiceCtrlDispatcher([In] ServiceTableEntry[] serviceTable);

    [DllImport("advapi32.dll", EntryPoint = "RegisterServiceCtrlHandlerExW", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern IntPtr RegisterServiceControlHandler(string serviceName, HandlerFunction handler, IntPtr context);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetServiceStatus(IntPtr statusHandle, ref ServiceStatus serviceStatus);
}
