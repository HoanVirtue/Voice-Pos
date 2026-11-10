using BanHang.Application.Customers.Dtos;
using BanHang.BuildingBlocks.Pagination;
using BanHang.Domain.Entities.Customers;
using BanHang.SharedKernel.Repositories;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Customers.Queries;

public sealed class GetCustomersQueryHandler(IReadOnlyRepository<Customer, Guid> repository)
    : IRequestHandler<GetCustomersQuery, PaginatedList<CustomerDto>>
{
    public async Task<PaginatedList<CustomerDto>> Handle(GetCustomersQuery request, CancellationToken cancellationToken)
    {
        var query = repository.Queryable;

        if (request.IncludeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim();
            query = query.Where(c => c.Name.Contains(keyword)
                                     || (c.Alias != null && c.Alias.Contains(keyword))
                                     || (c.Phone != null && c.Phone.Contains(keyword)));
        }

        if (request.UpdatedSince.HasValue)
        {
            var since = ToUtc(request.UpdatedSince.Value);
            query = query.Where(c => c.UpdatedAt > since)
                .OrderBy(c => c.UpdatedAt).ThenBy(c => c.Id);
        }
        else
        {
            query = query.OrderBy(c => c.Name).ThenBy(c => c.Id);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var entities = await query
            .Skip((request.PageIndex - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedList<CustomerDto>(
            entities.Select(CustomerDto.From).ToList(), totalCount, request.PageIndex, request.PageSize);
    }

    // Model binding có thể đổi chuỗi "...Z" thành giờ local; chuẩn hóa về UTC để so với cột UpdatedAt (UTC).
    private static DateTime ToUtc(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
    };
}
