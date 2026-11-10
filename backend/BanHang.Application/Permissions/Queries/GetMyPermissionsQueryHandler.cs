using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.Application.Authorization;
using BanHang.Application.Permissions.Dtos;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Web;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Permissions.Queries;

public sealed class GetMyPermissionsQueryHandler(
    ICurrentUser currentUser,
    IReadOnlyRepository<User> userRepository,
    IReadOnlyRepository<Role> roleRepository,
    EffectivePermissionResolver resolver) : IRequestHandler<GetMyPermissionsQuery, MyPermissionsDto>
{
    public async Task<MyPermissionsDto> Handle(GetMyPermissionsQuery request, CancellationToken cancellationToken)
    {
        if (!currentUser.IsAuthenticated || !long.TryParse(currentUser.UserId, out var userId))
        {
            throw new UnauthorizedException();
        }

        var user = await userRepository.Queryable
            .SingleOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new UnauthorizedException();

        var role = await roleRepository.Queryable
            .SingleOrDefaultAsync(r => r.Id == user.RoleId, cancellationToken)
            ?? throw new UnauthorizedException();

        // Tính lại từ DB chứ không đọc claim: quyền có thể đã đổi sau khi token được phát hành, và
        // đây chính là endpoint FE gọi để lấy trạng thái mới nhất.
        var permissions = role.IsFullBypass
            ? SystemPermissions.GetAll().ToList()
            : (await resolver.ResolveAsync(role.Id, user.Id, cancellationToken)).ToList();

        return new MyPermissionsDto(
            user.Id, user.Username, role.Id, role.Key, role.DisplayName, role.IsFullBypass, permissions);
    }
}
