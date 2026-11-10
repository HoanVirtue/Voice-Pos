using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.Application.Common.Dtos;
using BanHang.Application.Roles.Dtos;
using BanHang.BuildingBlocks.Pagination;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Queries;

public sealed class GetRoleByIdQueryHandler(IReadOnlyRepository<Role> repository)
    : IRequestHandler<GetRoleByIdQuery, RoleDto>
{
    public async Task<RoleDto> Handle(GetRoleByIdQuery request, CancellationToken cancellationToken)
    {
        var role = await repository.GetAsync(request.Id, cancellationToken);

        return new RoleDto(
            role.Id, role.Key, role.DisplayName, role.Description,
            role.IsFullBypass, role.IsSystem, role.SortOrder, role.Status);
    }
}
