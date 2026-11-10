using System.Net;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;
using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed class UpdateUserCommandHandler(
    IRepository<User> repository,
    IReadOnlyRepository<Role> roleRepository) : IRequestHandler<UpdateUserCommand>
{
    public async Task Handle(UpdateUserCommand request, CancellationToken cancellationToken)
    {
        var user = await repository.GetAsync(request.Id, cancellationToken);

        if (!await roleRepository.AnyAsync(r => r.Id == request.RoleId, cancellationToken))
        {
            throw new CustomException("Vai trò không tồn tại.", HttpStatusCode.BadRequest);
        }

        user.Update(request.RoleId, request.DisplayName);
        await repository.UpdateAsync(user, cancellationToken: cancellationToken);
    }
}
