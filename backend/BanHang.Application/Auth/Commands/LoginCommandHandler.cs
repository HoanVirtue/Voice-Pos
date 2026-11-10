using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.Application.Auth.Dtos;
using BanHang.Application.Authorization;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Identity;
using BanHang.Domain.Enums;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Auth.Commands;

public sealed class LoginCommandHandler(
    IReadOnlyRepository<User> repository,
    IReadOnlyRepository<Role> roleRepository,
    IRepository<RefreshToken> refreshTokenRepository,
    EffectivePermissionResolver permissionResolver,
    IPasswordHasher passwordHasher,
    ITokenService tokenService) : IRequestHandler<LoginCommand, LoginResultDto>
{
    public async Task<LoginResultDto> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        var user = await repository.Queryable
            .SingleOrDefaultAsync(u => u.Username == request.Username, cancellationToken);

        if (user is null || !passwordHasher.Verify(request.Password, user.PasswordHash))
        {
            throw new UnauthorizedException();
        }

        if (user.Status != (int)RecordStatus.Active)
        {
            throw new UnauthorizedException("Tài khoản đã bị khóa cần liên hệ quản trị viên để mở lại");
        }

        var role = await roleRepository.Queryable
            .SingleOrDefaultAsync(r => r.Id == user.RoleId, cancellationToken);

        if (role is null || role.Status != (int)RecordStatus.Active)
        {
            // Vai trò bị xoá hoặc ngừng hoạt động: không suy ra được quyền nào, từ chối đăng nhập
            // thay vì phát hành token rỗng quyền khiến người dùng thấy màn hình trắng khó hiểu.
            throw new UnauthorizedException();
        }

        var permissions = role.IsFullBypass
            ? []
            : await permissionResolver.ResolveAsync(role.Id, user.Id, cancellationToken);

        var token = tokenService.GenerateAccessToken(
            user.Id, user.Username, role.Key, permissions, role.IsFullBypass);
        var refreshToken = tokenService.GenerateRefreshToken();

        await refreshTokenRepository.InsertAsync(
            RefreshToken.Create(user.Id, refreshToken.Hash, refreshToken.ExpiresAtUtc),
            autoSave: true,
            cancellationToken);

        return new LoginResultDto(
            user.Id, user.Username, role.Key, token.Value, token.ExpiresAtUtc,
            refreshToken.RawValue, refreshToken.ExpiresAtUtc, user.DisplayName);
    }
}
