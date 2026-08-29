namespace RisePals.ServiceHost;

public sealed class ServiceRegistrationIdentity
{
    public const string CandidateServiceName = "RisePalsServiceHostCandidate";
    public const string RetainedApplicationServiceName = "RisePalsApp";
    public const string RetainedProxyServiceName = "RisePalsProxy";

    private ServiceRegistrationIdentity(string serviceName) => ServiceName = serviceName;

    public string ServiceName { get; }

    public string DispatcherServiceName => ServiceName;

    public string HandlerServiceName => ServiceName;

    public static ServiceRegistrationIdentity Candidate { get; } = Create(CandidateServiceName);

    public static ServiceRegistrationIdentity Create(string serviceName)
    {
        if (string.Equals(serviceName, RetainedApplicationServiceName, StringComparison.OrdinalIgnoreCase) ||
            string.Equals(serviceName, RetainedProxyServiceName, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("A retained Rise Pals service name cannot identify the candidate host.");
        }

        if (!string.Equals(serviceName, CandidateServiceName, StringComparison.Ordinal))
        {
            throw new InvalidDataException("The service identity must be the exact reviewed candidate name.");
        }

        return new ServiceRegistrationIdentity(serviceName);
    }
}
