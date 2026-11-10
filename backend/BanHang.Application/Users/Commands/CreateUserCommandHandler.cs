using System.Net;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;
using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed class CreateUserCommandHandler(
    IRepository<User> repository,
    IReadOnlyRepository<Role> roleRepository,
    IPasswordHasher passwordHasher) : IRequestHandler<CreateUserCommand, long>
{
    public async Task<long> Handle(CreateUserCommand request, CancellationToken cancellationToken)
    {
        if (await repository.AnyAsync(u => u.Username == request.Username, cancellationToken))
        {
            throw new CustomException($"Tên đăng nhập '{request.Username}' đã tồn tại.", HttpStatusCode.Conflict);
        }

        if (!await roleRepository.AnyAsync(r => r.Id == request.RoleId, cancellationToken))
        {
            throw new CustomException("Vai trò không tồn tại.", HttpStatusCode.BadRequest);
        }

        var user = User.Create(request.Username, passwordHasher.Hash(request.Password), request.RoleId, request.DisplayName);
        await repository.InsertAsync(user, cancellationToken: cancellationToken);
        return user.Id;
    }
}
