using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace RisePals.ServiceHost;

public sealed class DrainProtocolException(string message) : IOException(message);

public sealed record DrainMessage(
    [property: JsonPropertyName("version")] int Version,
    [property: JsonPropertyName("type")] string Type,
    [property: JsonPropertyName("nonce")] string Nonce,
    [property: JsonPropertyName("state")] string State,
    [property: JsonPropertyName("activeCount")] int ActiveCount);

public sealed class NamedPipeDrainTransport : IDrainTransport
{
    public const int ProtocolVersion = 1;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    private readonly NamedPipeServerStream _server;
    private StreamReader? _reader;
    private StreamWriter? _writer;
    private readonly HashSet<string> _completedNonces = new(StringComparer.Ordinal);
    private bool _connected;
    private string? _activeNonce;

    public NamedPipeDrainTransport(string pipeName)
    {
        if (string.IsNullOrWhiteSpace(pipeName) || pipeName.Length > 200 || pipeName.Any(character => !char.IsLetterOrDigit(character) && character is not '.' and not '-'))
        {
            throw new ArgumentException("The private pipe name is invalid.", nameof(pipeName));
        }

        _server = PrivateNamedPipeServer.Create(pipeName);
    }

    public async Task WaitForReadyAsync(TimeSpan timeout, CancellationToken cancellationToken)
    {
        try
        {
            await _server.WaitForConnectionAsync(cancellationToken).WaitAsync(timeout, cancellationToken).ConfigureAwait(false);
            _connected = true;
            _reader = new StreamReader(_server, new UTF8Encoding(false, true), false, 4096, true);
            _writer = new StreamWriter(_server, new UTF8Encoding(false), 4096, true) { AutoFlush = true };
            var ready = await ReadAsync(timeout, cancellationToken).ConfigureAwait(false);
            ValidateEnvelope(ready);
            if (ready.Type != "ack" || ready.State != "Ready" || ready.ActiveCount != 0 || ready.Nonce.Length != 0)
            {
                throw new DrainProtocolException("The first private-pipe message must be Ready with zero active work.");
            }
        }
        catch (IOException exception) when (exception is not DrainProtocolException)
        {
            throw new DrainProtocolException($"The private-pipe peer failed before Ready: {exception.GetType().Name}.");
        }
    }

    public async Task<DrainAcknowledgement> BeginDrainAsync(string nonce, TimeSpan timeout, CancellationToken cancellationToken)
    {
        ValidateNewNonce(nonce);
        _activeNonce = nonce;
        await WriteAsync(new DrainMessage(ProtocolVersion, "command", nonce, "Draining", 0), cancellationToken).ConfigureAwait(false);

        var sawDraining = false;
        while (true)
        {
            var message = await ReadAsync(timeout, cancellationToken).ConfigureAwait(false);
            ValidateAcknowledgement(message, nonce);
            if (message.State == "Draining")
            {
                sawDraining = true;
                continue;
            }

            if (message.State != "Drained" || !sawDraining || message.ActiveCount != 0)
            {
                throw new DrainProtocolException("Drain acknowledgement skipped or violated the Draining to Drained transition.");
            }

            return new DrainAcknowledgement(nonce, DrainState.Drained, 0);
        }
    }

    public async Task<DrainAcknowledgement> RequestStopAsync(string nonce, TimeSpan timeout, CancellationToken cancellationToken)
    {
        if (!string.Equals(_activeNonce, nonce, StringComparison.Ordinal))
        {
            throw new DrainProtocolException("The Stop correlation nonce does not match the active drain.");
        }

        await WriteAsync(new DrainMessage(ProtocolVersion, "command", nonce, "Stopped", 0), cancellationToken).ConfigureAwait(false);
        var message = await ReadAsync(timeout, cancellationToken).ConfigureAwait(false);
        ValidateAcknowledgement(message, nonce);
        if (message.State != "Stopped" || message.ActiveCount != 0)
        {
            throw new DrainProtocolException("The child did not acknowledge Stopped with zero active work.");
        }

        _completedNonces.Add(nonce);
        _activeNonce = null;
        return new DrainAcknowledgement(nonce, DrainState.Stopped, 0);
    }

    private void ValidateNewNonce(string nonce)
    {
        if (!_connected)
        {
            throw new DrainProtocolException("The private pipe is not connected.");
        }

        if (nonce.Length != 32 || nonce.Any(character => !Uri.IsHexDigit(character)))
        {
            throw new DrainProtocolException("The correlation nonce must be 128-bit lowercase hexadecimal text.");
        }

        if (_activeNonce is not null && !string.Equals(_activeNonce, nonce, StringComparison.Ordinal))
        {
            throw new DrainProtocolException("A drain is already active.");
        }

        if (_completedNonces.Contains(nonce))
        {
            throw new DrainProtocolException("A completed drain nonce cannot be replayed.");
        }
    }

    private static void ValidateEnvelope(DrainMessage message)
    {
        if (message.Version != ProtocolVersion || message.ActiveCount < 0 || message.Nonce.Length > 64)
        {
            throw new DrainProtocolException("The private-pipe envelope is malformed or uses an unsupported version.");
        }
    }

    private static void ValidateAcknowledgement(DrainMessage message, string nonce)
    {
        ValidateEnvelope(message);
        if (message.Type != "ack" || !string.Equals(message.Nonce, nonce, StringComparison.Ordinal))
        {
            throw new DrainProtocolException("A stale, replayed or mismatched acknowledgement was rejected.");
        }
    }

    private async Task WriteAsync(DrainMessage message, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var json = JsonSerializer.Serialize(message, JsonOptions);
        await (_writer ?? throw new DrainProtocolException("The private pipe writer is unavailable."))
            .WriteLineAsync(json.AsMemory(), cancellationToken)
            .ConfigureAwait(false);
    }

    private async Task<DrainMessage> ReadAsync(TimeSpan timeout, CancellationToken cancellationToken)
    {
        var line = await (_reader ?? throw new DrainProtocolException("The private pipe reader is unavailable."))
            .ReadLineAsync(cancellationToken)
            .AsTask()
            .WaitAsync(timeout, cancellationToken)
            .ConfigureAwait(false);
        if (line is null || line.Length > 1024)
        {
            throw new DrainProtocolException("The private-pipe peer disconnected or exceeded the message bound.");
        }

        try
        {
            return JsonSerializer.Deserialize<DrainMessage>(line, JsonOptions)
                ?? throw new DrainProtocolException("The private-pipe message was empty.");
        }
        catch (JsonException exception)
        {
            throw new DrainProtocolException($"The private-pipe message was malformed: {exception.GetType().Name}.");
        }
    }

    public async ValueTask DisposeAsync()
    {
        try
        {
            if (_writer is not null)
            {
                await _writer.DisposeAsync().ConfigureAwait(false);
            }
        }
        catch (IOException)
        {
            // A broken private peer is already a fail-closed protocol outcome.
        }

        _reader?.Dispose();
        _server.Dispose();
    }
}

public static class PrivateNamedPipeServer
{
    private const uint SecurityDescriptorRevision = 1;
    private const uint PipeAccessDuplex = 0x00000003;
    private const uint FileFlagOverlapped = 0x40000000;
    private const uint PipeRejectRemoteClients = 0x00000008;

    public static NamedPipeServerStream Create(string pipeName)
    {
        var identitySid = WindowsIdentity.GetCurrent().User?.Value
            ?? throw new InvalidOperationException("The service identity SID is unavailable.");
        var sddl = BuildSecurityDescriptor(identitySid);
        if (!NativeMethods.ConvertStringSecurityDescriptorToSecurityDescriptor(
                sddl,
                SecurityDescriptorRevision,
                out var descriptor,
                IntPtr.Zero))
        {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        try
        {
            var attributes = new NativeMethods.SecurityAttributes
            {
                Length = Marshal.SizeOf<NativeMethods.SecurityAttributes>(),
                SecurityDescriptor = descriptor,
                InheritHandle = false,
            };
            var handle = NativeMethods.CreateNamedPipe(
                $"\\\\.\\pipe\\{pipeName}",
                PipeAccessDuplex | FileFlagOverlapped,
                PipeRejectRemoteClients,
                1,
                4096,
                4096,
                0,
                ref attributes);
            if (handle.IsInvalid)
            {
                handle.Dispose();
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            }

            return new NamedPipeServerStream(PipeDirection.InOut, true, false, handle);
        }
        finally
        {
            _ = NativeMethods.LocalFree(descriptor);
        }
    }

    public static string BuildSecurityDescriptor(string serviceIdentitySid)
    {
        if (!serviceIdentitySid.StartsWith("S-1-", StringComparison.Ordinal) ||
            serviceIdentitySid.Any(character => !char.IsDigit(character) && character != '-' && character != 'S'))
        {
            throw new ArgumentException("The service identity SID is invalid.", nameof(serviceIdentitySid));
        }

        // Protected DACL: GenericAll for BUILTIN\\Administrators and the exact
        // service identity only. PIPE_REJECT_REMOTE_CLIENTS adds a transport-level
        // remote-client denial.
        return $"D:P(A;;GA;;;BA)(A;;GA;;;{serviceIdentitySid})";
    }

    private static class NativeMethods
    {
        [StructLayout(LayoutKind.Sequential)]
        internal struct SecurityAttributes
        {
            internal int Length;
            internal IntPtr SecurityDescriptor;

            [MarshalAs(UnmanagedType.Bool)]
            internal bool InheritHandle;
        }

        [DllImport("advapi32.dll", EntryPoint = "ConvertStringSecurityDescriptorToSecurityDescriptorW", SetLastError = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool ConvertStringSecurityDescriptorToSecurityDescriptor(
            string stringSecurityDescriptor,
            uint stringSecurityDescriptorRevision,
            out IntPtr securityDescriptor,
            IntPtr securityDescriptorSize);

        [DllImport("kernel32.dll", EntryPoint = "CreateNamedPipeW", SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern Microsoft.Win32.SafeHandles.SafePipeHandle CreateNamedPipe(
            string name,
            uint openMode,
            uint pipeMode,
            uint maximumInstances,
            uint outputBufferSize,
            uint inputBufferSize,
            uint defaultTimeout,
            ref SecurityAttributes securityAttributes);

        [DllImport("kernel32.dll")]
        internal static extern IntPtr LocalFree(IntPtr memory);
    }
}
