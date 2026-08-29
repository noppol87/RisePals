using System.Runtime.InteropServices;
using System.Security.Principal;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class ConfigurationAndSecurityTests
{
    private static readonly string[] UnsafeArguments = ["ok\nunsafe"];
    private static readonly string[] ExpectedProtocolProperties = ["ActiveCount", "Nonce", "State", "Type", "Version"];
    private static readonly string[] RuntimeFiles = ["ProcessAdapters.cs", "Program.cs", "ServiceOrchestrator.cs", "WindowsScmAdapter.cs"];
    private string _root = null!;

    [TestInitialize]
    public void Initialize()
    {
        _root = Path.Combine(Path.GetTempPath(), $"risepals-servicehost-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_root);
    }

    [TestCleanup]
    public void Cleanup()
    {
        if (Directory.Exists(_root))
        {
            Directory.Delete(_root, true);
        }
    }

    [TestMethod]
    public void ValidExactNodeAndReleasePathsPass()
    {
        var configuration = CreatePhysicalConfiguration();
        ConfigurationValidator.Validate(configuration);
    }

    [TestMethod]
    public void NodeOutsideApprovedRootIsRejected()
    {
        var configuration = CreatePhysicalConfiguration();
        var outside = Path.Combine(_root, "outside", "node.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(outside)!);
        File.WriteAllText(outside, "synthetic");
        Assert.ThrowsExactly<InvalidDataException>(() => ConfigurationValidator.Validate(configuration with { NodeExecutable = outside }));
    }

    [TestMethod]
    public void ReleaseOutsideApprovedRootIsRejected()
    {
        var configuration = CreatePhysicalConfiguration();
        var outside = Path.Combine(_root, "outside-release");
        Directory.CreateDirectory(outside);
        var entrypoint = Path.Combine(outside, "server.js");
        File.WriteAllText(entrypoint, "synthetic");
        Assert.ThrowsExactly<InvalidDataException>(() => ConfigurationValidator.Validate(configuration with { ReleaseDirectory = outside, Entrypoint = entrypoint }));
    }

    [TestMethod]
    public void ShellOrNpmExecutableIsRejected()
    {
        var configuration = CreatePhysicalConfiguration();
        var npm = Path.Combine(configuration.ApprovedNodeRoot, "npm.cmd");
        File.WriteAllText(npm, "synthetic");
        Assert.ThrowsExactly<InvalidDataException>(() => ConfigurationValidator.Validate(configuration with { NodeExecutable = npm }));
    }

    [TestMethod]
    public void MutableLogsInsideReleaseAreRejected()
    {
        var configuration = CreatePhysicalConfiguration();
        Assert.ThrowsExactly<InvalidDataException>(() => ConfigurationValidator.Validate(configuration with { LogDirectory = Path.Combine(configuration.ReleaseDirectory, "logs") }));
    }

    [TestMethod]
    public void RuntimeArgumentsRejectControlCharacters()
    {
        var configuration = CreatePhysicalConfiguration();
        Assert.ThrowsExactly<InvalidDataException>(() => ConfigurationValidator.Validate(configuration with { Arguments = UnsafeArguments }));
    }

    [TestMethod]
    public void CandidateServiceIdentityCannotDivergeBetweenDispatcherAndHandler()
    {
        var identity = ServiceRegistrationIdentity.Candidate;
        Assert.AreEqual("RisePalsServiceHostCandidate", identity.ServiceName);
        Assert.AreEqual(identity.DispatcherServiceName, identity.HandlerServiceName);
        Assert.AreSame(identity, ServiceRegistrationIdentity.Candidate);
    }

    [TestMethod]
    public void RetainedServiceNamesAreRejectedForCandidateRegistration()
    {
        Assert.ThrowsExactly<InvalidDataException>(() =>
            ServiceRegistrationIdentity.Create(ServiceRegistrationIdentity.RetainedApplicationServiceName));
        Assert.ThrowsExactly<InvalidDataException>(() =>
            ServiceRegistrationIdentity.Create(ServiceRegistrationIdentity.RetainedProxyServiceName));
        Assert.ThrowsExactly<InvalidDataException>(() => ServiceRegistrationIdentity.Create("risepalsapp"));
    }

    [TestMethod]
    public void UnexpectedCandidateServiceNameIsRejected()
    {
        Assert.ThrowsExactly<InvalidDataException>(() => ServiceRegistrationIdentity.Create("RisePalsServiceHostCandidate2"));
    }

    [TestMethod]
    [DataRow(0x0000000Fu, 0x00000100u, 7u)]
    public void ScmConstantsRepresentNativePreshutdownContract(uint expectedControl, uint expectedAccept, uint expectedInfoClass)
    {
        Assert.AreEqual(NativeScm.ServiceControlPreshutdown, expectedControl);
        Assert.AreEqual(NativeScm.ServiceAcceptPreshutdown, expectedAccept);
        Assert.AreEqual(NativeScm.ServiceConfigPreshutdownInfo, expectedInfoClass);
        Assert.AreEqual(4, Marshal.SizeOf<NativeScm.ServicePreshutdownInfo>());
    }

    [TestMethod]
    public void PrivatePipeNamesRejectPathAndWildcardCharacters()
    {
        Assert.ThrowsExactly<ArgumentException>(() => new NamedPipeDrainTransport("unsafe\\pipe"));
        Assert.ThrowsExactly<ArgumentException>(() => new NamedPipeDrainTransport("unsafe*pipe"));
    }

    [TestMethod]
    public void PrivatePipeDaclAllowsOnlyServiceIdentityAndAdministrators()
    {
        var identity = WindowsIdentity.GetCurrent().User?.Value ?? throw new AssertInconclusiveException("Current Windows SID unavailable.");
        var descriptor = PrivateNamedPipeServer.BuildSecurityDescriptor(identity);
        StringAssert.Contains(descriptor, "(A;;GA;;;BA)");
        StringAssert.Contains(descriptor, $"(A;;GA;;;{identity})");
        Assert.IsFalse(descriptor.Contains(";;;WD", StringComparison.Ordinal));
        Assert.IsFalse(descriptor.Contains(";;;AN", StringComparison.Ordinal));
        Assert.IsFalse(descriptor.Contains(";;;BU", StringComparison.Ordinal));
    }

    [TestMethod]
    public void ProtocolEnvelopeHasNoRequestOrIdentityFields()
    {
        var properties = typeof(DrainMessage).GetProperties().Select(property => property.Name).Order().ToArray();
        CollectionAssert.AreEqual(ExpectedProtocolProperties, properties);
    }

    [TestMethod]
    public void WindowsArgumentQuotingPreservesSpacesQuotesAndTrailingSlashes()
    {
        Assert.AreEqual("plain", NodeChildProcess.QuoteWindowsArgument("plain"));
        Assert.AreEqual("\"two words\"", NodeChildProcess.QuoteWindowsArgument("two words"));
        Assert.AreEqual("\"quote\\\"value\"", NodeChildProcess.QuoteWindowsArgument("quote\"value"));
        Assert.AreEqual("\"C:\\path with space\\\\\"", NodeChildProcess.QuoteWindowsArgument("C:\\path with space\\"));
    }

    [TestMethod]
    public void RuntimeSourceContainsNoShellOrWindowsPowerShellLaunch()
    {
        var sourceRoot = ResolveServiceHostSource();
        var source = string.Join('\n', RuntimeFiles.Select(file => File.ReadAllText(Path.Combine(sourceRoot, file))));
        Assert.IsFalse(source.Contains("powershell", StringComparison.OrdinalIgnoreCase));
        Assert.IsFalse(source.Contains("cmd.exe", StringComparison.OrdinalIgnoreCase));
        Assert.IsFalse(source.Contains("npm", StringComparison.OrdinalIgnoreCase));
        StringAssert.Contains(source, "CreateSuspended");
        StringAssert.Contains(source, "AssignProcessToJobObject");
    }

    private ReleaseConfiguration CreatePhysicalConfiguration()
    {
        var nodeRoot = Path.Combine(_root, "node");
        var releaseRoot = Path.Combine(_root, "releases");
        var release = Path.Combine(releaseRoot, "release-a");
        var log = Path.Combine(_root, "logs");
        Directory.CreateDirectory(nodeRoot);
        Directory.CreateDirectory(release);
        Directory.CreateDirectory(log);
        var node = Path.Combine(nodeRoot, "node.exe");
        var entrypoint = Path.Combine(release, "server.js");
        File.WriteAllText(node, "synthetic");
        File.WriteAllText(entrypoint, "synthetic");
        return ReleaseConfiguration.CreateForTest(node, release, entrypoint, log);
    }

    private static string ResolveServiceHostSource()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, "infra", "windows-service-host", "RisePals.ServiceHost");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException("The service-host source directory was not found.");
    }
}
