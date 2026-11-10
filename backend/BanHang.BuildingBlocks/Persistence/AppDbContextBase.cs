using System.Linq.Expressions;
using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Time;
using BanHang.BuildingBlocks.Web;
using BanHang.SharedKernel.Entities;

namespace BanHang.BuildingBlocks.Persistence;

/// <summary>
/// Base DbContext every module's own DbContext derives from. Each module keeps its own
/// derived context, its own schema and its own migrations — this base only centralizes the three
/// things that must stay consistent across all of them: audit stamping, soft-delete filtering and
/// domain-event dispatch.
/// </summary>
public abstract class AppDbContextBase(
    DbContextOptions options,
    ICurrentUser currentUser,
    IDateTimeProvider dateTimeProvider,
    IPublisher publisher)
    : DbContext(options)
{
    /// <summary>
    /// Every AuditableEntity is soft-deleted (see ApplyAuditInfo below), so every AuditableEntity
    /// must also be excluded from normal queries once IsDeleted is set — otherwise "deleting" an
    /// entity would have no visible effect. Applied once here instead of per IEntityTypeConfiguration
    /// so a module can never forget it for a new aggregate.
    /// </summary>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            if (!typeof(IAuditable).IsAssignableFrom(entityType.ClrType))
            {
                continue;
            }

            var parameter = Expression.Parameter(entityType.ClrType, "e");
            var notDeleted = Expression.Not(Expression.Property(parameter, nameof(IAuditable.IsDeleted)));
            modelBuilder.Entity(entityType.ClrType).HasQueryFilter(Expression.Lambda(notDeleted, parameter));
        }

        base.OnModelCreating(modelBuilder);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        ApplyAuditInfo();

        var result = await base.SaveChangesAsync(cancellationToken);

        await DispatchDomainEventsAsync(cancellationToken);

        return result;
    }

    private void ApplyAuditInfo()
    {
        var now = dateTimeProvider.Now;
        var userId = currentUser.UserId;

        // Phải chạy trước vòng bên dưới (nó đổi Deleted -> Modified): giá trị GỐC lấy từ dấu mà entity đang mang
        // (đã đọc lên hoặc client gửi về) để câu UPDATE/DELETE có điều kiện "ConcurrencyStamp = dấu cũ"; dấu mới
        // cấp lại ở đây. Entity đọc no-tracking rồi Update() vẫn chạy đúng vì dấu đọc lên chính là giá trị gốc.
        foreach (var entry in ChangeTracker.Entries<IHasConcurrencyStamp>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.ConcurrencyStamp = Guid.NewGuid().ToString("N");
            }
            else if (entry.State is EntityState.Modified or EntityState.Deleted)
            {
                entry.Property(x => x.ConcurrencyStamp).OriginalValue = entry.Entity.ConcurrencyStamp;
                entry.Entity.ConcurrencyStamp = Guid.NewGuid().ToString("N");
            }
        }

        foreach (var entry in ChangeTracker.Entries<IAuditable>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    entry.Entity.CreatedBy = userId;
                    break;
                case EntityState.Modified:
                    entry.Entity.ModifiedAt = now;
                    entry.Entity.ModifiedBy = userId;
                    break;
                case EntityState.Deleted:
                    entry.State = EntityState.Modified;
                    entry.Entity.IsDeleted = true;
                    entry.Entity.ModifiedAt = now;
                    entry.Entity.ModifiedBy = userId;
                    break;
            }
        }
    }

    private async Task DispatchDomainEventsAsync(CancellationToken cancellationToken)
    {
        var entitiesWithEvents = ChangeTracker.Entries<IHasDomainEvents>()
            .Select(e => e.Entity)
            .Where(e => e.DomainEvents.Count > 0)
            .ToList();

        var domainEvents = entitiesWithEvents.SelectMany(e => e.DomainEvents).ToList();
        entitiesWithEvents.ForEach(e => e.ClearDomainEvents());

        foreach (var domainEvent in domainEvents)
        {
            await publisher.Publish(domainEvent, cancellationToken);
        }
    }
}
