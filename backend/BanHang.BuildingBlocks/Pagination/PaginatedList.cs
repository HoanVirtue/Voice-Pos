using Microsoft.EntityFrameworkCore;

namespace BanHang.BuildingBlocks.Pagination;

public sealed class PaginatedQuery
{
    public int PageIndex { get; init; } = 1;
    public int PageSize { get; init; } = 20;
}

public sealed class PaginatedList<T>(IReadOnlyCollection<T> items, int totalCount, int pageIndex, int pageSize)
{
    public IReadOnlyCollection<T> Items { get; } = items;
    public int PageIndex { get; } = pageIndex;
    public int PageSize { get; } = pageSize;
    public int TotalItems { get; } = totalCount;
    public int TotalPages { get; } = (int)Math.Ceiling(totalCount / (double)pageSize);

    public static async Task<PaginatedList<T>> CreateAsync(
        IQueryable<T> source, int pageIndex, int pageSize, CancellationToken cancellationToken = default)
    {
        var totalCount = await source.CountAsync(cancellationToken);
        var items = await source
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedList<T>(items, totalCount, pageIndex, pageSize);
    }
}
