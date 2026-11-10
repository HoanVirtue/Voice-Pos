using MediatR;

namespace BanHang.SharedKernel.Entities;

/// <summary>
/// Marker for domain events. Extends MediatR's INotification (contracts-only, no infrastructure
/// dependency) so AppDbContextBase can dispatch them through IPublisher after SaveChanges without
/// every module having to know MediatR exists.
/// </summary>
public interface IDomainEvent : INotification
{
    DateTime OccurredOn { get; }
}
