using System.Net;
using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Commands;

public sealed class DeleteRoleCommandHandler(
    IRepository<Role> repository,
    IReadOnlyRepository<User> userRepository,
    IRepository<RolePermission> rolePermissionRepository) : IRequestHandler<DeleteRoleCommand>
{
    public async Task Handle(DeleteRoleCommand request, CancellationToken cancellationToken)
    {
        var role = await repository.GetAsync(request.Id, cancellationToken);

        // Chỉ duy nhất vai trò Admin mới không được xoá
        if (string.Equals(role.Key, "Admin", StringComparison.OrdinalIgnoreCase))
        {
            throw new CustomException(
                "Không thể xoá vai trò quản trị viên hệ thống (Admin).", HttpStatusCode.Conflict);
        }

        var userCount = await userRepository.Queryable.CountAsync(u => u.RoleId == role.Id, cancellationToken);
        if (userCount > 0)
        {
            throw new CustomException(
                $"Không thể xoá vai trò '{role.DisplayName}' vì đang có {userCount} tài khoản người dùng đang được gán vai trò này. Vui lòng chuyển vai trò của người dùng sang vai trò khác trước khi xoá.",
                HttpStatusCode.Conflict);
        }

        // Dọn dẹp sạch các quyền đã phân cho vai trò này
        var permissions = await rolePermissionRepository.Queryable
            .Where(rp => rp.RoleId == role.Id)
            .ToListAsync(cancellationToken);
        if (permissions.Count > 0)
        {
            await rolePermissionRepository.DeleteManyAsync(permissions, cancellationToken: cancellationToken);
        }

        await repository.DeleteAsync(role, cancellationToken: cancellationToken);
    }
}
