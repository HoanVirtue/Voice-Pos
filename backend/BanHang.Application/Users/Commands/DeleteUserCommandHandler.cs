using System.Net;
using MediatR;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Web;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Users.Commands;

public sealed class DeleteUserCommandHandler(
    IRepository<User> repository,
    ICurrentUser currentUser) : IRequestHandler<DeleteUserCommand>
{
    public async Task Handle(DeleteUserCommand request, CancellationToken cancellationToken)
    {
        if (long.TryParse(currentUser.UserId, out var currentUserId) && currentUserId == request.Id)
        {
            throw new CustomException("Không thể tự xoá tài khoản đang đăng nhập.", HttpStatusCode.BadRequest);
        }

        var user = await repository.GetAsync(request.Id, cancellationToken);

        if (string.Equals(user.Username, "admin", StringComparison.OrdinalIgnoreCase))
        {
            throw new CustomException("Không thể xoá tài khoản quản trị hệ thống mặc định.", HttpStatusCode.Conflict);
        }

        await repository.DeleteAsync(user, cancellationToken: cancellationToken);
    }
}
