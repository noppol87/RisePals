using System.Diagnostics;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class WindowsJobObjectTests
{
    [TestMethod]
    public async Task ClosingJobTerminatesOwnedChild()
    {
        using var process = StartNode("setInterval(() => {}, 1000)");
        await using (var job = new WindowsJobObject())
        {
            await job.AssignAsync(process.Id, CancellationToken.None);
            Assert.IsFalse(await job.IsEmptyAsync(CancellationToken.None));
        }

        await process.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
        Assert.IsTrue(process.HasExited);
    }

    [TestMethod]
    public async Task TerminateJobRemovesChildAndDescendant()
    {
        const string script = "const{spawn}=require('child_process');process.stdin.once('data',()=>{const c=spawn(process.execPath,['-e','setInterval(()=>{},1000)']);console.log(c.pid)});setInterval(()=>{},1000)";
        using var parent = StartNode(script, redirectOutput: true, redirectInput: true);
        await using var job = new WindowsJobObject();
        await job.AssignAsync(parent.Id, CancellationToken.None);
        await parent.StandardInput.WriteLineAsync("spawn");
        var childLine = await parent.StandardOutput.ReadLineAsync().WaitAsync(TimeSpan.FromSeconds(3));
        Assert.IsNotNull(childLine);
        var childId = int.Parse(childLine, System.Globalization.CultureInfo.InvariantCulture);
        await job.TerminateAsync(99, CancellationToken.None);
        await parent.WaitForExitAsync().WaitAsync(TimeSpan.FromSeconds(3));
        await WaitUntilExitedAsync(childId);
        Assert.IsTrue(await job.IsEmptyAsync(CancellationToken.None));
    }

    [TestMethod]
    public async Task JobCanReportEmptyBeforeAssignment()
    {
        await using var job = new WindowsJobObject();
        Assert.IsTrue(await job.IsEmptyAsync(CancellationToken.None));
    }

    private static Process StartNode(string script, bool redirectOutput = false, bool redirectInput = false)
    {
        var node = ResolveNode();
        var info = new ProcessStartInfo
        {
            FileName = node,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = redirectInput,
            RedirectStandardOutput = redirectOutput,
        };
        info.ArgumentList.Add("-e");
        info.ArgumentList.Add(script);
        return Process.Start(info) ?? throw new InvalidOperationException("Synthetic Node process did not start.");
    }

    private static string ResolveNode()
    {
        var pathEntries = (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(Path.PathSeparator);
        var node = pathEntries.Select(entry => Path.Combine(entry, "node.exe")).FirstOrDefault(File.Exists);
        return node ?? throw new AssertInconclusiveException("Pinned Node executable is unavailable for the Job Object test.");
    }

    private static async Task WaitUntilExitedAsync(int processId)
    {
        for (var index = 0; index < 100; index++)
        {
            try
            {
                using var process = Process.GetProcessById(processId);
                if (process.HasExited)
                {
                    return;
                }
            }
            catch (ArgumentException)
            {
                return;
            }

            await Task.Delay(25);
        }

        Assert.Fail("The owned descendant remained after Job Object termination.");
    }
}
