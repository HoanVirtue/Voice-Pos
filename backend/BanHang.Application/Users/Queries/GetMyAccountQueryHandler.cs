using System.Net;
using BanHang.Application.Users.Dtos;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Web;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Users.Queries;

public sealed class GetMyAccountQueryHandler(
    IReadOnlyRepository<User> userRepository,
    IReadOnlyRepository<Role> roleRepository,
    ICurrentUser currentUser)
    : IRequestHandler<GetMyAccountQuery, UserDto>
{
    public async Task<UserDto> Handle(GetMyAccountQuery request, CancellationToken cancellationToken)
    {
        if (!long.TryParse(currentUser.UserId, out var userId))
        {
            throw new CustomException("Không xác định được tài khoản đang đăng nhập.", HttpStatusCode.Unauthorized);
        }

        var item = await (from u in userRepository.Queryable
                          join r in roleRepository.Queryable on u.RoleId equals r.Id
                          where u.Id == userId
                          select new UserDto(u.Id, u.Username, u.DisplayName, r.Id, r.DisplayName, r.Key, u.Status, u.CreatedAt))
            .FirstOrDefaultAsync(cancellationToken);

        return item ?? throw new CustomException("Không tìm thấy tài khoản đang đăng nhập.", HttpStatusCode.NotFound);
    }
}
