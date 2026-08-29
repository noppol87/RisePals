using System.Diagnostics;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Win32.SafeHandles;

namespace RisePals.ServiceHost;

public sealed partial class RotatingSanitizedFileSink : ISanitizedEvidenceSink, IDisposable
{
    private readonly string _directory;
    private readonly long _maximumBytes;
    private readonly int _retainedFiles;
    private readonly object _gate = new();

    public RotatingSanitizedFileSink(string directory, long maximumBytes = 1_048_576, int retainedFiles = 3)
    {
        _directory = Path.GetFullPath(directory);
        _maximumBytes = maximumBytes > 0 ? maximumBytes : throw new ArgumentOutOfRangeException(nameof(maximumBytes));
        _retainedFiles = retainedFiles is >= 1 and <= 10 ? retainedFiles : throw new ArgumentOutOfRangeException(nameof(retainedFiles));
        Directory.CreateDirectory(_directory);
    }

    public void Record(string eventName, IReadOnlyDictionary<string, object?> fields)
    {
        var safeName = Sanitize(eventName);
        var safeFields = fields.ToDictionary(entry => Sanitize(entry.Key), entry => Sanitize(entry.Value?.ToString() ?? string.Empty));
        var json = JsonSerializer.Serialize(new { timestampUtc = DateTimeOffset.UtcNow, eventName = safeName, fields = safeFields });

        lock (_gate)
        {
            RotateIfRequired(json.Length + Environment.NewLine.Length);
            File.AppendAllText(Path.Combine(_directory, "service-host.jsonl"), json + Environment.NewLine, new System.Text.UTF8Encoding(false));
        }
    }

    public static string Sanitize(string value) =>
        CredentialPattern().Replace(
            EmailPattern().Replace(
                UuidPattern().Replace(value.Replace('\r', ' ').Replace('\n', ' '), "[redacted-id]"),
                "[redacted-email]"),
            "$1=[redacted]");

    private void RotateIfRequired(int additionalBytes)
    {
        var active = Path.Combine(_directory, "service-host.jsonl");
        if (!File.Exists(active) || new FileInfo(active).Length + additionalBytes <= _maximumBytes)
        {
            return;
        }

        var oldest = Path.Combine(_directory, $"service-host.{_retainedFiles}.jsonl");
        if (File.Exists(oldest))
        {
            File.Delete(oldest);
        }

        for (var index = _retainedFiles - 1; index >= 1; index--)
        {
            var source = Path.Combine(_directory, $"service-host.{index}.jsonl");
            var destination = Path.Combine(_directory, $"service-host.{index + 1}.jsonl");
            if (File.Exists(source))
            {
                File.Move(source, destination);
            }
        }

        File.Move(active, Path.Combine(_directory, "service-host.1.jsonl"));
    }

    public void Dispose()
    {
        // Files are opened per write so no persistent handle is retained.
    }

    [GeneratedRegex(@"(?i)\b(token|secret|password|authorization|cookie)\s*[:=]\s*[^\s,;]+", RegexOptions.CultureInvariant)]
    private static partial Regex CredentialPattern();

    [GeneratedRegex(@"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b", RegexOptions.CultureInvariant)]
    private static partial Regex UuidPattern();

    [GeneratedRegex(@"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex EmailPattern();
}

public sealed class NodeChildProcess(ISanitizedEvidenceSink evidence) : INodeChildProcess
{
    private Process? _process;
    private Task<int>? _completion;
    private SafeFileHandle? _primaryThread;
    private AnonymousPipeServerStream? _standardInput;
    private AnonymousPipeServerStream? _standardOutput;
    private AnonymousPipeServerStream? _standardError;
    private StreamWriter? _inputWriter;
    private StreamReader? _outputReader;
    private StreamReader? _errorReader;
    private bool _resumed;

    public int ProcessId => _process?.Id ?? throw new InvalidOperationException("The child has not started.");

    public bool HasExited => _process?.HasExited ?? true;

    public Task<int> Completion => _completion ?? throw new InvalidOperationException("The child has not started.");

    public Task StartAsync(ReleaseConfiguration configuration, string pipeName, CancellationToken cancellationToken)
    {
        ConfigurationValidator.Validate(configuration);
        cancellationToken.ThrowIfCancellationRequested();
        if (_process is not null)
        {
            throw new InvalidOperationException("This child-process adapter has already been used.");
        }

        _standardInput = new AnonymousPipeServerStream(PipeDirection.Out, HandleInheritability.Inheritable);
        _standardOutput = new AnonymousPipeServerStream(PipeDirection.In, HandleInheritability.Inheritable);
        _standardError = new AnonymousPipeServerStream(PipeDirection.In, HandleInheritability.Inheritable);
        var startup = new NativeProcess.StartupInfo
        {
            Size = Marshal.SizeOf<NativeProcess.StartupInfo>(),
            Flags = NativeProcess.StartfUseStdHandles,
            StandardInput = ParseHandle(_standardInput.GetClientHandleAsString()),
            StandardOutput = ParseHandle(_standardOutput.GetClientHandleAsString()),
            StandardError = ParseHandle(_standardError.GetClientHandleAsString()),
        };

        var arguments = new List<string> { configuration.NodeExecutable, configuration.Entrypoint };
        arguments.AddRange(configuration.Arguments);
        arguments.Add("--rise-pals-drain-pipe");
        arguments.Add(pipeName);
        var commandLine = new StringBuilder(string.Join(' ', arguments.Select(QuoteWindowsArgument)));

        try
        {
            if (!NativeProcess.CreateProcess(
                    Path.GetFullPath(configuration.NodeExecutable),
                    commandLine,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    true,
                    NativeProcess.CreateSuspended | NativeProcess.CreateNoWindow,
                    IntPtr.Zero,
                    Path.GetFullPath(configuration.ReleaseDirectory),
                    ref startup,
                    out var processInformation))
            {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }

            using (var initialProcessHandle = new SafeFileHandle(processInformation.Process, true))
            {
                _process = Process.GetProcessById(checked((int)processInformation.ProcessId));
            }

            _primaryThread = new SafeFileHandle(processInformation.Thread, true);
        }
        finally
        {
            _standardInput.DisposeLocalCopyOfClientHandle();
            _standardOutput.DisposeLocalCopyOfClientHandle();
            _standardError.DisposeLocalCopyOfClientHandle();
        }

        _inputWriter = new StreamWriter(_standardInput, new UTF8Encoding(false), 4096, true) { AutoFlush = true };
        _outputReader = new StreamReader(_standardOutput, new UTF8Encoding(false, true), false, 4096, true);
        _errorReader = new StreamReader(_standardError, new UTF8Encoding(false, true), false, 4096, true);
        _completion = ObserveCompletionAsync(_process);
        _ = PumpAsync(_outputReader, "stdout", cancellationToken);
        _ = PumpAsync(_errorReader, "stderr", cancellationToken);
        return Task.CompletedTask;
    }

    public Task ResumeAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (_resumed)
        {
            return Task.CompletedTask;
        }

        var thread = _primaryThread ?? throw new InvalidOperationException("The child has not been created suspended.");
        if (NativeProcess.ResumeThread(thread) == uint.MaxValue)
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        _resumed = true;
        thread.Dispose();
        _primaryThread = null;
        return Task.CompletedTask;
    }

    public async Task RequestExitAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (_process is { HasExited: false } && _inputWriter is not null)
        {
            await _inputWriter.WriteLineAsync("exit").ConfigureAwait(false);
        }
    }

    private static async Task<int> ObserveCompletionAsync(Process process)
    {
        await process.WaitForExitAsync().ConfigureAwait(false);
        return process.ExitCode;
    }

    private async Task PumpAsync(StreamReader reader, string stream, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            var line = await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false);
            if (line is null)
            {
                return;
            }

            evidence.Record("service.child.output", new Dictionary<string, object?> { ["stream"] = stream, ["message"] = line });
        }
    }

    private static IntPtr ParseHandle(string value) =>
        new(long.Parse(value, System.Globalization.CultureInfo.InvariantCulture));

    public static string QuoteWindowsArgument(string argument)
    {
        if (argument.Length > 0 && argument.All(character => !char.IsWhiteSpace(character) && character != '"'))
        {
            return argument;
        }

        var builder = new StringBuilder(argument.Length + 2).Append('"');
        var backslashes = 0;
        foreach (var character in argument)
        {
            if (character == '\\')
            {
                backslashes++;
                continue;
            }

            if (character == '"')
            {
                builder.Append('\\', (backslashes * 2) + 1).Append('"');
                backslashes = 0;
                continue;
            }

            builder.Append('\\', backslashes).Append(character);
            backslashes = 0;
        }

        return builder.Append('\\', backslashes * 2).Append('"').ToString();
    }

    public async ValueTask DisposeAsync()
    {
        _primaryThread?.Dispose();
        if (_inputWriter is not null)
        {
            await _inputWriter.DisposeAsync().ConfigureAwait(false);
        }

        _outputReader?.Dispose();
        _errorReader?.Dispose();
        _standardInput?.Dispose();
        _standardOutput?.Dispose();
        _standardError?.Dispose();
        _process?.Dispose();
    }

    private static class NativeProcess
    {
        internal const uint CreateSuspended = 0x00000004;
        internal const uint CreateNoWindow = 0x08000000;
        internal const uint StartfUseStdHandles = 0x00000100;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct StartupInfo
        {
            internal int Size;
            internal string? Reserved;
            internal string? Desktop;
            internal string? Title;
            internal uint X;
            internal uint Y;
            internal uint XSize;
            internal uint YSize;
            internal uint XCountChars;
            internal uint YCountChars;
            internal uint FillAttribute;
            internal uint Flags;
            internal ushort ShowWindow;
            internal ushort Reserved2Size;
            internal IntPtr Reserved2;
            internal IntPtr StandardInput;
            internal IntPtr StandardOutput;
            internal IntPtr StandardError;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct ProcessInformation
        {
            internal IntPtr Process;
            internal IntPtr Thread;
            internal uint ProcessId;
            internal uint ThreadId;
        }

        [DllImport("kernel32.dll", EntryPoint = "CreateProcessW", SetLastError = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreateProcess(
            string applicationName,
            StringBuilder commandLine,
            IntPtr processAttributes,
            IntPtr threadAttributes,
            [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
            uint creationFlags,
            IntPtr environment,
            string currentDirectory,
            ref StartupInfo startupInfo,
            out ProcessInformation processInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        internal static extern uint ResumeThread(SafeFileHandle thread);
    }
}

public sealed class WindowsJobObject : IProcessTreeOwner
{
    private readonly SafeFileHandle _handle;

    public WindowsJobObject()
    {
        _handle = NativeMethods.CreateJobObject(IntPtr.Zero, null);
        if (_handle.IsInvalid)
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        var information = new NativeMethods.JobObjectExtendedLimitInformation
        {
            BasicLimitInformation = new NativeMethods.JobObjectBasicLimitInformation
            {
                LimitFlags = NativeMethods.JobObjectLimitKillOnJobClose,
            },
        };
        var size = Marshal.SizeOf<NativeMethods.JobObjectExtendedLimitInformation>();
        var pointer = Marshal.AllocHGlobal(size);
        try
        {
            Marshal.StructureToPtr(information, pointer, false);
            if (!NativeMethods.SetInformationJobObject(_handle, 9, pointer, (uint)size))
            {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }
        }
        finally
        {
            Marshal.FreeHGlobal(pointer);
        }
    }

    public Task AssignAsync(int processId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        using var process = Process.GetProcessById(processId);
        if (!NativeMethods.AssignProcessToJobObject(_handle, process.SafeHandle))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        return Task.CompletedTask;
    }

    public Task<bool> IsEmptyAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var accounting = new NativeMethods.JobObjectBasicAccountingInformation();
        var size = Marshal.SizeOf<NativeMethods.JobObjectBasicAccountingInformation>();
        var pointer = Marshal.AllocHGlobal(size);
        try
        {
            if (!NativeMethods.QueryInformationJobObject(_handle, 1, pointer, (uint)size, out _))
            {
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }

            accounting = Marshal.PtrToStructure<NativeMethods.JobObjectBasicAccountingInformation>(pointer);
            return Task.FromResult(accounting.ActiveProcesses == 0);
        }
        finally
        {
            Marshal.FreeHGlobal(pointer);
        }
    }

    public Task TerminateAsync(uint exitCode, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!NativeMethods.TerminateJobObject(_handle, exitCode))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        return Task.CompletedTask;
    }

    public ValueTask DisposeAsync()
    {
        _handle.Dispose();
        return ValueTask.CompletedTask;
    }

    private static class NativeMethods
    {
        internal const uint JobObjectLimitKillOnJobClose = 0x00002000;

        [DllImport("kernel32.dll", EntryPoint = "CreateJobObjectW", SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern SafeFileHandle CreateJobObject(IntPtr securityAttributes, string? name);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetInformationJobObject(SafeFileHandle job, int informationClass, IntPtr information, uint informationLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool AssignProcessToJobObject(SafeFileHandle job, SafeProcessHandle process);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool QueryInformationJobObject(SafeFileHandle job, int informationClass, IntPtr information, uint informationLength, out uint returnLength);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool TerminateJobObject(SafeFileHandle job, uint exitCode);

        [StructLayout(LayoutKind.Sequential)]
        internal struct JobObjectBasicLimitInformation
        {
            internal long PerProcessUserTimeLimit;
            internal long PerJobUserTimeLimit;
            internal uint LimitFlags;
            internal UIntPtr MinimumWorkingSetSize;
            internal UIntPtr MaximumWorkingSetSize;
            internal uint ActiveProcessLimit;
            internal UIntPtr Affinity;
            internal uint PriorityClass;
            internal uint SchedulingClass;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct IoCounters
        {
            internal ulong ReadOperationCount;
            internal ulong WriteOperationCount;
            internal ulong OtherOperationCount;
            internal ulong ReadTransferCount;
            internal ulong WriteTransferCount;
            internal ulong OtherTransferCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct JobObjectExtendedLimitInformation
        {
            internal JobObjectBasicLimitInformation BasicLimitInformation;
            internal IoCounters IoInfo;
            internal UIntPtr ProcessMemoryLimit;
            internal UIntPtr JobMemoryLimit;
            internal UIntPtr PeakProcessMemoryUsed;
            internal UIntPtr PeakJobMemoryUsed;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct JobObjectBasicAccountingInformation
        {
            internal long TotalUserTime;
            internal long TotalKernelTime;
            internal long ThisPeriodTotalUserTime;
            internal long ThisPeriodTotalKernelTime;
            internal uint TotalPageFaultCount;
            internal uint TotalProcesses;
            internal uint ActiveProcesses;
            internal uint TotalTerminatedProcesses;
        }
    }
}
