using System.Net;
using MediatR;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Web;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Users.Commands;

public sealed class ChangeMyPasswordCommandHandler(
    IRepository<User> repository,
    IPasswordHasher passwordHasher,
    ICurrentUser currentUser) : IRequestHandler<ChangeMyPasswordCommand>
{
    public async Task Handle(ChangeMyPasswordCommand request, CancellationToken cancellationToken)
    {
        if (!long.TryParse(currentUser.UserId, out var userId))
        {
            throw new CustomException("Không xác định được tài khoản đang đăng nhập.", HttpStatusCode.Unauthorized);
        }

        var user = await repository.GetAsync(userId, cancellationToken);

        if (!passwordHasher.Verify(request.CurrentPassword, user.PasswordHash))
        {
            throw new CustomException("Mật khẩu hiện tại không đúng.", HttpStatusCode.BadRequest);
        }

        if (passwordHasher.Verify(request.NewPassword, user.PasswordHash))
        {
            throw new CustomException("Mật khẩu mới không được giống mật khẩu hiện tại.", HttpStatusCode.BadRequest);
        }

        user.ChangePassword(passwordHasher.Hash(request.NewPassword));

        await repository.UpdateAsync(user, cancellationToken: cancellationToken);
    }
}
