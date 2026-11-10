using MediatR;
using Microsoft.EntityFrameworkCore;
using BanHang.BuildingBlocks.Auth;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Auth.Commands;

/// <summary>Thu hồi refresh token phía server khi người dùng đăng xuất chủ động.</summary>
public sealed class LogoutCommandHandler(
    IRepository<RefreshToken> refreshTokenRepository,
    ITokenService tokenService) : IRequestHandler<LogoutCommand>
{
    public async Task Handle(LogoutCommand request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            return;
        }

        var hash = tokenService.HashRefreshToken(request.RefreshToken);
        var existing = await refreshTokenRepository.Queryable
            .SingleOrDefaultAsync(x => x.TokenHash == hash, cancellationToken);

        if (existing is null || !existing.IsActive)
        {
            return;
        }

        existing.Revoke();
        await refreshTokenRepository.UpdateAsync(existing, autoSave: true, cancellationToken);
    }
}
