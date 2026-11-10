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

public sealed class RefreshTokenCommandHandler(
    IRepository<RefreshToken> refreshTokenRepository,
    IReadOnlyRepository<User> userRepository,
    IReadOnlyRepository<Role> roleRepository,
    EffectivePermissionResolver permissionResolver,
    ITokenService tokenService) : IRequestHandler<RefreshTokenCommand, LoginResultDto>
{
    public async Task<LoginResultDto> Handle(RefreshTokenCommand request, CancellationToken cancellationToken)
    {
        var hash = tokenService.HashRefreshToken(request.RefreshToken);
        var existing = await refreshTokenRepository.Queryable
            .SingleOrDefaultAsync(x => x.TokenHash == hash, cancellationToken);

        if (existing is null || !existing.IsActive)
        {
            throw new UnauthorizedException("Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.");
        }

        var user = await userRepository.FindAsync(existing.UserId, cancellationToken);
        if (user is null || user.Status != (int)RecordStatus.Active)
        {
            throw new UnauthorizedException("Tài khoản đã bị khóa cần liên hệ quản trị viên để mở lại");
        }

        var role = await roleRepository.Queryable
            .SingleOrDefaultAsync(r => r.Id == user.RoleId, cancellationToken);

        if (role is null || role.Status != (int)RecordStatus.Active)
        {
            throw new UnauthorizedException();
        }

        var permissions = role.IsFullBypass
            ? []
            : await permissionResolver.ResolveAsync(role.Id, user.Id, cancellationToken);

        var accessToken = tokenService.GenerateAccessToken(
            user.Id, user.Username, role.Key, permissions, role.IsFullBypass);
        var newRefreshToken = tokenService.GenerateRefreshToken();

        // Xoay vòng: token cũ bị thu hồi ngay khi cấp token mới, refresh token chỉ dùng được một lần.
        existing.Revoke(newRefreshToken.Hash);
        await refreshTokenRepository.UpdateAsync(existing, autoSave: false, cancellationToken);
        await refreshTokenRepository.InsertAsync(
            RefreshToken.Create(user.Id, newRefreshToken.Hash, newRefreshToken.ExpiresAtUtc),
            autoSave: true,
            cancellationToken);

        return new LoginResultDto(
            user.Id, user.Username, role.Key, accessToken.Value, accessToken.ExpiresAtUtc,
            newRefreshToken.RawValue, newRefreshToken.ExpiresAtUtc, user.DisplayName);
    }
}
