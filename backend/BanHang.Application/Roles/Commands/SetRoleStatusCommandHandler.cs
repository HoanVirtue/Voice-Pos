using System.Net;
using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Commands;

public sealed class SetRoleStatusCommandHandler(IRepository<Role> repository)
    : IRequestHandler<SetRoleStatusCommand>
{
    public async Task Handle(SetRoleStatusCommand request, CancellationToken cancellationToken)
    {
        var role = await repository.GetAsync(request.Id, cancellationToken);

        // Chỉ duy nhất vai trò Admin mới không được ngừng hoạt động
        if (string.Equals(role.Key, "Admin", StringComparison.OrdinalIgnoreCase) && !request.IsActive)
        {
            throw new CustomException(
                "Không thể ngừng hoạt động vai trò quản trị viên hệ thống (Admin).", HttpStatusCode.Conflict);
        }

        if (request.IsActive)
        {
            role.Activate();
        }
        else
        {
            role.Deactivate();
        }

        await repository.UpdateAsync(role, cancellationToken: cancellationToken);
    }
}
