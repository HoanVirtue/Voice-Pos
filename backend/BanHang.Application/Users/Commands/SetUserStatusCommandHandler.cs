using System.Net;
using MediatR;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Web;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Users.Commands;

public sealed class SetUserStatusCommandHandler(
    IRepository<User> repository,
    ICurrentUser currentUser) : IRequestHandler<SetUserStatusCommand>
{
    public async Task Handle(SetUserStatusCommand request, CancellationToken cancellationToken)
    {
        if (!request.IsActive && long.TryParse(currentUser.UserId, out var currentUserId) && currentUserId == request.Id)
        {
            throw new CustomException("Không thể tự khoá tài khoản đang đăng nhập.", HttpStatusCode.BadRequest);
        }

        var user = await repository.GetAsync(request.Id, cancellationToken);

        if (!request.IsActive && string.Equals(user.Username, "admin", StringComparison.OrdinalIgnoreCase))
        {
            throw new CustomException("Không thể khoá tài khoản quản trị hệ thống mặc định.", HttpStatusCode.Conflict);
        }

        if (request.IsActive)
        {
            user.Activate();
        }
        else
        {
            user.Deactivate();
        }

        await repository.UpdateAsync(user, cancellationToken: cancellationToken);
    }
}
