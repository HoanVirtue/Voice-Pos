using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.Application.Common.Dtos;
using BanHang.Application.Roles.Dtos;
using BanHang.BuildingBlocks.Pagination;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Queries;

public sealed class GetRoleLookupQueryHandler(IReadOnlyRepository<Role> repository)
    : IRequestHandler<GetRoleLookupQuery, IReadOnlyCollection<LookupDto>>
{
    public async Task<IReadOnlyCollection<LookupDto>> Handle(
        GetRoleLookupQuery request, CancellationToken cancellationToken) =>
        await repository.Queryable
            .Where(r => r.Status == 1)
            .OrderBy(r => r.SortOrder).ThenBy(r => r.DisplayName)
            .Select(r => new LookupDto(r.Id, r.DisplayName))
            .ToListAsync(cancellationToken);
}
