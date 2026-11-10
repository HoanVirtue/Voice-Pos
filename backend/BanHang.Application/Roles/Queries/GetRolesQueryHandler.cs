using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.Application.Common.Dtos;
using BanHang.Application.Roles.Dtos;
using BanHang.BuildingBlocks.Pagination;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Queries;

public sealed class GetRolesQueryHandler(
    IReadOnlyRepository<Role> repository,
    IReadOnlyRepository<RolePermission> rolePermissionRepository,
    IReadOnlyRepository<User> userRepository)
    : IRequestHandler<GetRolesQuery, PaginatedList<RoleListItemDto>>
{
    public Task<PaginatedList<RoleListItemDto>> Handle(GetRolesQuery request, CancellationToken cancellationToken)
    {
        var query = repository.Queryable;

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            query = query.Where(r => r.DisplayName.Contains(request.Keyword) || r.Key.Contains(request.Keyword));
        }

        if (request.Status.HasValue)
        {
            query = query.Where(r => r.Status == request.Status);
        }

        var rolePermissions = rolePermissionRepository.Queryable;
        var users = userRepository.Queryable;

        var projected = query
            .OrderBy(r => r.SortOrder).ThenBy(r => r.DisplayName)
            .Select(r => new RoleListItemDto(
                r.Id,
                r.Key,
                r.DisplayName,
                r.Description,
                r.IsFullBypass,
                r.IsSystem,
                r.SortOrder,
                rolePermissions.Count(rp => rp.RoleId == r.Id && rp.UserId == 0 && rp.Allow),
                users.Count(u => u.RoleId == r.Id),
                r.Status));

        return PaginatedList<RoleListItemDto>.CreateAsync(
            projected, request.PageIndex, request.PageSize, cancellationToken);
    }
}
