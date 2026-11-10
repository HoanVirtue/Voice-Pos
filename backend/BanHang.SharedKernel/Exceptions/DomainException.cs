namespace BanHang.SharedKernel.Exceptions;

/// <summary>
/// Base type for business-rule violations raised from inside the domain model
/// (entities, value objects, domain services) — never from controllers or handlers directly.
/// </summary>
public abstract class DomainException : Exception
{
    protected DomainException(string message) : base(message)
    {
    }
}
