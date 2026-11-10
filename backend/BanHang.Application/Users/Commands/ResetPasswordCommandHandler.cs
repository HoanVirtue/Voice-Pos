using System.Net;
using MediatR;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Web;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Users.Commands;

public sealed class ResetPasswordCommandHandler(
    IRepository<User> repository,
    IPasswordHasher passwordHasher) : IRequestHandler<ResetPasswordCommand>
{
    public async Task Handle(ResetPasswordCommand request, CancellationToken cancellationToken)
    {
        var user = await repository.GetAsync(request.UserId, cancellationToken);
        var passwordHash = passwordHasher.Hash(request.NewPassword);
        user.ChangePassword(passwordHash);

        await repository.UpdateAsync(user, cancellationToken: cancellationToken);
    }
}
