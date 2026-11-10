using System.Net;
using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Commands;

public sealed class CreateRoleCommandHandler(IRepository<Role> repository)
    : IRequestHandler<CreateRoleCommand, long>
{
    public async Task<long> Handle(CreateRoleCommand request, CancellationToken cancellationToken)
    {
        if (await repository.AnyAsync(r => r.Key == request.Key, cancellationToken))
        {
            throw new CustomException($"Mã vai trò '{request.Key}' đã tồn tại.", HttpStatusCode.Conflict);
        }

        // Vai trò tạo từ giao diện không bao giờ được bypass — nếu không, bất kỳ ai có quyền sửa
        // phân quyền đều có thể tự nâng mình lên toàn quyền chỉ bằng cách tạo một vai trò mới.
        var role = Role.Create(
            request.Key,
            request.DisplayName,
            request.Description,
            isFullBypass: false,
            isSystem: false,
            request.SortOrder);

        await repository.InsertAsync(role, cancellationToken: cancellationToken);

        return role.Id;
    }
}
