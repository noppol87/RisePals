using System.Reflection;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using RisePals.ServiceHost;

namespace RisePals.ServiceHost.Tests;

[TestClass]
public sealed class EvidenceBoundaryTests
{
    private static readonly Type[] EvidenceRecordParameterTypes = [typeof(ServiceEvidenceEvent)];
    private static readonly string[] EvidencePropertyNames = ["Count", "Name", "Outcome", "Stream"];
    private static readonly string[] ExpectedRotatedFileNames =
        ["service-host.1.jsonl", "service-host.2.jsonl", "service-host.jsonl"];

    private string _root = null!;

    [TestInitialize]
    public void Initialize()
    {
        _root = Path.Combine(Path.GetTempPath(), $"risepals-servicehost-evidence-{Guid.NewGuid():N}");
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
    public void ProductionEvidenceContractAcceptsOnlyTypedAllowlistedFields()
    {
        var method = typeof(ISanitizedEvidenceSink).GetMethod(nameof(ISanitizedEvidenceSink.Record));
        Assert.IsNotNull(method);
        CollectionAssert.AreEqual(
            EvidenceRecordParameterTypes,
            method.GetParameters().Select(parameter => parameter.ParameterType).ToArray());
        CollectionAssert.AreEqual(
            EvidencePropertyNames,
            typeof(ServiceEvidenceEvent).GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Select(property => property.Name)
                .Order()
                .ToArray());

        Assert.ThrowsExactly<InvalidDataException>(() =>
            ServiceEvidenceContract.Validate(
                new ServiceEvidenceEvent((ServiceEvidenceEventName)999, ServiceEvidenceOutcome.Observed)));
        Assert.ThrowsExactly<InvalidDataException>(() =>
            ServiceEvidenceContract.Validate(
                new ServiceEvidenceEvent(
                    ServiceEvidenceEventName.ChildStreamObserved,
                    ServiceEvidenceOutcome.Observed,
                    Count: ServiceEvidenceContract.MaximumCount + 1)));
    }

    [TestMethod]
    public void SensitiveAndOversizedNodeOutputNeverAppearsInPersistedEvidence()
    {
        var rawValues = new[]
        {
            string.Concat("person", "@", "example.test"),
            string.Concat("user", "_2syntheticclerkidentifier"),
            string.Concat("Bearer ", "synthetic-opaque-value"),
            string.Concat("sk_", "test_", new string('x', 24)),
            string.Concat("postgresql", "://synthetic:synthetic@localhost:5432/example"),
            string.Concat("https://example.test/path?", "private=value"),
            "ข้อความส่วนบุคคลภาษาไทยที่ไม่ควรถูกบันทึก",
            string.Concat("123e4567-e89b-42d3-a456-", "426614174000"),
            "first line\r\nsecond line",
            new string('z', 4096),
        };
        const int maximumBytes = 640;
        using var sink = new RotatingSanitizedFileSink(_root, maximumBytes, retainedFiles: 3);

        foreach (var rawValue in rawValues)
        {
            sink.Record(NodeChildProcess.CreateStreamEvidence("stdout", rawValue));
        }

        var files = Directory.GetFiles(_root, "service-host*.jsonl").Order().ToArray();
        Assert.IsGreaterThanOrEqualTo(1, files.Length);
        Assert.IsLessThanOrEqualTo(4, files.Length);
        Assert.IsTrue(files.All(file => new FileInfo(file).Length <= maximumBytes));
        var persisted = string.Join('\n', files.Select(File.ReadAllText));
        foreach (var rawValue in rawValues)
        {
            Assert.IsFalse(persisted.Contains(rawValue, StringComparison.Ordinal));
        }

        StringAssert.Contains(persisted, "service.child.stream-observed");
        StringAssert.Contains(persisted, "\"stream\":\"stdout\"");
        Assert.IsFalse(persisted.Contains("message", StringComparison.OrdinalIgnoreCase));
    }

    [TestMethod]
    public void EventLargerThanConfiguredFileBoundIsRejectedBeforeWrite()
    {
        using var sink = new RotatingSanitizedFileSink(_root, maximumBytes: 64, retainedFiles: 1);
        var evidence = NodeChildProcess.CreateStreamEvidence("stderr", new string('x', 4096));
        Assert.ThrowsExactly<InvalidDataException>(() => sink.Record(evidence));
        Assert.IsFalse(File.Exists(Path.Combine(_root, "service-host.jsonl")));
    }

    [TestMethod]
    public void RotationAndRetentionRemainDeterministicAndBounded()
    {
        const int maximumBytes = 320;
        const int retainedFiles = 2;
        using var sink = new RotatingSanitizedFileSink(_root, maximumBytes, retainedFiles);
        for (var index = 0; index < 20; index++)
        {
            sink.Record(
                new ServiceEvidenceEvent(
                    ServiceEvidenceEventName.ChildRestartScheduled,
                    ServiceEvidenceOutcome.RestartScheduled,
                    Count: index));
        }

        var files = Directory.GetFiles(_root, "service-host*.jsonl").Select(Path.GetFileName).Order().ToArray();
        CollectionAssert.AreEquivalent(ExpectedRotatedFileNames, files);
        Assert.IsTrue(Directory.GetFiles(_root, "service-host*.jsonl").All(file => new FileInfo(file).Length <= maximumBytes));
    }
}
