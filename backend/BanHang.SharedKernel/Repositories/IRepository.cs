using System.Linq.Expressions;
using BanHang.SharedKernel.Entities;

namespace BanHang.SharedKernel.Repositories;

/// <summary>
/// Read-only surface of the generic repository. Query-side CQRS handlers should depend on this
/// instead of <see cref="IRepository{TEntity,TKey}"/> so a query handler can never accidentally
/// write data — the split (and the shape of its members) mirrors ABP's
/// IReadOnlyRepository/IRepository pattern, adapted to this app's simpler, no-navigation-property,
/// no-Unit-of-Work model.
/// </summary>
public interface IReadOnlyRepository<TEntity, in TKey> where TEntity : BaseEntity<TKey>
{
    Task<TEntity?> FindAsync(TKey id, CancellationToken cancellationToken = default);

    Task<TEntity> GetAsync(TKey id, CancellationToken cancellationToken = default);

    Task<bool> AnyAsync(Expression<Func<TEntity, bool>> predicate, CancellationToken cancellationToken = default);

    /// <summary>Read-only queryable for handlers to compose filters/projections on the query side.</summary>
    IQueryable<TEntity> Queryable { get; }
}

public interface IReadOnlyRepository<TEntity> : IReadOnlyRepository<TEntity, long> where TEntity : BaseEntity<long>;

public interface IRepository<TEntity, TKey> : IReadOnlyRepository<TEntity, TKey> where TEntity : BaseEntity<TKey>
{
    Task<TEntity> InsertAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default);

    Task InsertManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default);

    Task UpdateAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default);

    Task UpdateManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default);

    Task DeleteAsync(TEntity entity, bool autoSave = true, CancellationToken cancellationToken = default);

    Task DeleteManyAsync(IEnumerable<TEntity> entities, bool autoSave = true, CancellationToken cancellationToken = default);

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Bỏ toàn bộ thay đổi chưa lưu và ngừng theo dõi mọi entity của DbContext hiện tại. Dùng khi lưu thất bại
    /// vì xung đột đồng thời để nạp lại dữ liệu mới nhất và xử lý lại từ đầu.
    /// </summary>
    void ClearTracking();
}

public interface IRepository<TEntity> : IRepository<TEntity, long>, IReadOnlyRepository<TEntity> where TEntity : BaseEntity<long>;
