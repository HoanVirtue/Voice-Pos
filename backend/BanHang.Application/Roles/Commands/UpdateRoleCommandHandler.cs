using System.Net;
using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Roles.Commands;

public sealed class UpdateRoleCommandHandler(IRepository<Role> repository) : IRequestHandler<UpdateRoleCommand>
{
    public async Task Handle(UpdateRoleCommand request, CancellationToken cancellationToken)
    {
        var role = await repository.GetAsync(request.Id, cancellationToken);

        // Key cố ý không cho sửa: nó nằm trong token đã phát hành và trong dữ liệu seed.
        role.Update(request.DisplayName, request.Description, request.SortOrder);

        await repository.UpdateAsync(role, cancellationToken: cancellationToken);
    }
}
