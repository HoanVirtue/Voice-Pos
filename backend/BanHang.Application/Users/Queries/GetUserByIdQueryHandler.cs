using System.Net;
using BanHang.Application.Users.Dtos;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Users.Queries;

public sealed class GetUserByIdQueryHandler(
    IReadOnlyRepository<User> userRepository,
    IReadOnlyRepository<Role> roleRepository)
    : IRequestHandler<GetUserByIdQuery, UserDto>
{
    public async Task<UserDto> Handle(GetUserByIdQuery request, CancellationToken cancellationToken)
    {
        var item = await (from u in userRepository.Queryable
                          join r in roleRepository.Queryable on u.RoleId equals r.Id
                          where u.Id == request.Id
                          select new UserDto(u.Id, u.Username, u.DisplayName, r.Id, r.DisplayName, r.Key, u.Status, u.CreatedAt))
            .FirstOrDefaultAsync(cancellationToken);

        return item ?? throw new CustomException($"Không tìm thấy tài khoản #{request.Id}.", HttpStatusCode.NotFound);
    }
}
