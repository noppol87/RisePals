using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class DrainProtocolTests
{
    [TestMethod]
    public async Task ReadyDrainingDrainedStoppedSequencePasses()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        var peer = RunPeerAsync(pipeName, PeerMode.Normal);
        await transport.WaitForReadyAsync(TimeSpan.FromSeconds(2), CancellationToken.None);
        var nonce = Guid.NewGuid().ToString("N");
        var drained = await transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(2), CancellationToken.None);
        var stopped = await transport.RequestStopAsync(nonce, TimeSpan.FromSeconds(2), CancellationToken.None);
        await peer;
        Assert.AreEqual(DrainState.Drained, drained.State);
        Assert.AreEqual(DrainState.Stopped, stopped.State);
    }

    [TestMethod]
    public async Task StaleAcknowledgementIsRejected()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        var peer = RunPeerAsync(pipeName, PeerMode.Stale);
        await transport.WaitForReadyAsync(TimeSpan.FromSeconds(2), CancellationToken.None);
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.BeginDrainAsync(Guid.NewGuid().ToString("N"), TimeSpan.FromSeconds(2), CancellationToken.None));
        await peer;
    }

    [TestMethod]
    public async Task MalformedReadyFailsClosed()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        var peer = RunPeerAsync(pipeName, PeerMode.Malformed);
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.WaitForReadyAsync(TimeSpan.FromSeconds(2), CancellationToken.None));
        await peer;
    }

    [TestMethod]
    public async Task DisconnectDuringDrainFailsClosed()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        var peer = RunPeerAsync(pipeName, PeerMode.Disconnect);
        await transport.WaitForReadyAsync(TimeSpan.FromSeconds(2), CancellationToken.None);
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.BeginDrainAsync(Guid.NewGuid().ToString("N"), TimeSpan.FromSeconds(2), CancellationToken.None));
        await peer;
    }

    [TestMethod]
    public async Task CompletedNonceReplayIsRejected()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        var peer = RunPeerAsync(pipeName, PeerMode.Normal);
        await transport.WaitForReadyAsync(TimeSpan.FromSeconds(2), CancellationToken.None);
        var nonce = Guid.NewGuid().ToString("N");
        _ = await transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(2), CancellationToken.None);
        _ = await transport.RequestStopAsync(nonce, TimeSpan.FromSeconds(2), CancellationToken.None);
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.BeginDrainAsync(nonce, TimeSpan.FromSeconds(2), CancellationToken.None));
        await peer;
    }

    [TestMethod]
    public async Task WrongVersionReadyIsRejected()
    {
        var pipeName = NewPipeName();
        await using var transport = new NamedPipeDrainTransport(pipeName);
        var peer = RunPeerAsync(pipeName, PeerMode.WrongVersion);
        await Assert.ThrowsExactlyAsync<DrainProtocolException>(() =>
            transport.WaitForReadyAsync(TimeSpan.FromSeconds(2), CancellationToken.None));
        await peer;
    }

    private static string NewPipeName() => $"RisePals.ServiceHost.v1.{Guid.NewGuid():N}";

    private static async Task RunPeerAsync(string pipeName, PeerMode mode)
    {
        await using var client = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
        await client.ConnectAsync(2000);
        using var reader = new StreamReader(client, new UTF8Encoding(false, true), false, 1024, true);
        await using var writer = new StreamWriter(client, new UTF8Encoding(false), 1024, true) { AutoFlush = true };

        if (mode == PeerMode.Malformed)
        {
            await writer.WriteLineAsync("not-json");
            return;
        }

        await WriteAsync(writer, new DrainMessage(mode == PeerMode.WrongVersion ? 2 : 1, "ack", "", "Ready", 0));
        if (mode == PeerMode.WrongVersion)
        {
            return;
        }

        var line = await reader.ReadLineAsync();
        if (line is null)
        {
            return;
        }

        var command = JsonSerializer.Deserialize<DrainMessage>(line)!;
        if (mode == PeerMode.Disconnect)
        {
            return;
        }

        var nonce = mode == PeerMode.Stale ? new string('0', 32) : command.Nonce;
        await WriteAsync(writer, new DrainMessage(1, "ack", nonce, "Draining", 1));
        if (mode == PeerMode.Stale)
        {
            return;
        }

        await WriteAsync(writer, new DrainMessage(1, "ack", nonce, "Drained", 0));
        var stopLine = await reader.ReadLineAsync();
        if (stopLine is null)
        {
            return;
        }

        await WriteAsync(writer, new DrainMessage(1, "ack", nonce, "Stopped", 0));
    }

    private static Task WriteAsync(StreamWriter writer, DrainMessage message) =>
        writer.WriteLineAsync(JsonSerializer.Serialize(message));

    private enum PeerMode
    {
        Normal,
        Stale,
        Malformed,
        Disconnect,
        WrongVersion,
    }
}
