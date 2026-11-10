namespace BanHang.Application.Auth.Dtos;

public sealed record LoginResultDto(
    long UserId,
    string Username,
    string Role,
    string AccessToken,
    DateTime ExpiresAtUtc,
    string RefreshToken,
    DateTime RefreshTokenExpiresAtUtc,
    string? DisplayName = null);
