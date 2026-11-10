using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.SharedKernel.Entities;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Infrastructure.Persistence;

/// <summary>
/// The only implementation of IRepository&lt;TEntity, TKey&gt; in the app. Works against any
/// aggregate purely via DbContext.Set&lt;TEntity&gt;() — adding a new aggregate never requires a
/// new repository class, which is the whole point of the ABP-style generic-repository approach.
/// </summary>
public sealed class EfCoreRepository<TEntity, TKey>(BanHangDbContext dbContext) : IRepository<TEntity, TKey>
    where TEntity : BaseEntity<TKey>
{
    private DbSet<TEntity> Set => dbContext.Set<TEntity>();

    public IQueryable<TEntity> Queryable => Set.AsNoTracking();

    public async Task<TEntity?> FindAsync(TKey id, CancellationToken cancellationToken = default) =>
        // Kiểm tra bộ nhớ trước (đang track), rồi tìm trong DB bỏ qua query filter để thấy cả bản ghi xóa mềm.
        await Set.FindAsync([id], cancellationToken) is { } tracked
            ? tracked
            : await Set.IgnoreQueryFilters().FirstOrDefaultAsync(e => e.Id!.Equals(id), cancellationToken);

    public async Task<TEntity> GetAsync(TKey id, CancellationToken cancellationToken = default) =>
        await FindAsync(id, cancellationToken)
        ?? throw new NotFoundException(typeof(TEntity).Name, id!);

    public Task<bool> AnyAsync(Expression<Func<TEntity, bool>> predicate, CancellationToken cancellationToken = default) =>
        Set.AnyAsync(predicate, cancellationToken);

    public async Task<TEntity> InsertAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default)
    {
        var entry = await Set.AddAsync(entity, cancellationToken);

        if (autoSave)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return entry.Entity;
    }

    public async Task InsertManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default)
    {
        await Set.AddRangeAsync(entities, cancellationToken);

        if (autoSave)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task UpdateAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default)
    {
        Set.Update(entity);

        if (autoSave)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task UpdateManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default)
    {
        Set.UpdateRange(entities);

        if (autoSave)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task DeleteAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default)
    {
        Set.Remove(entity);

        if (autoSave)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task DeleteManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default)
    {
        Set.RemoveRange(entities);

        if (autoSave)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default) =>
        dbContext.SaveChangesAsync(cancellationToken);

    public void ClearTracking() => dbContext.ChangeTracker.Clear();
}

/// <summary>Shorthand implementation registered for the common long-keyed aggregates.</summary>
public sealed class EfCoreRepository<TEntity>(BanHangDbContext dbContext) : IRepository<TEntity>
    where TEntity : BaseEntity<long>
{
    private readonly EfCoreRepository<TEntity, long> _inner = new(dbContext);

    public IQueryable<TEntity> Queryable => _inner.Queryable;
    public Task<TEntity?> FindAsync(long id, CancellationToken cancellationToken = default) => _inner.FindAsync(id, cancellationToken);
    public Task<TEntity> GetAsync(long id, CancellationToken cancellationToken = default) => _inner.GetAsync(id, cancellationToken);
    public Task<bool> AnyAsync(Expression<Func<TEntity, bool>> predicate, CancellationToken cancellationToken = default) => _inner.AnyAsync(predicate, cancellationToken);
    public Task<TEntity> InsertAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default) => _inner.InsertAsync(entity, autoSave, cancellationToken);
    public Task InsertManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default) => _inner.InsertManyAsync(entities, autoSave, cancellationToken);
    public Task UpdateAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default) => _inner.UpdateAsync(entity, autoSave, cancellationToken);
    public Task UpdateManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default) => _inner.UpdateManyAsync(entities, autoSave, cancellationToken);
    public Task DeleteAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default) => _inner.DeleteAsync(entity, autoSave, cancellationToken);
    public Task DeleteManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default) => _inner.DeleteManyAsync(entities, autoSave, cancellationToken);
    public Task<int> SaveChangesAsync(CancellationToken cancellationToken = default) => _inner.SaveChangesAsync(cancellationToken);
    public void ClearTracking() => _inner.ClearTracking();
}
