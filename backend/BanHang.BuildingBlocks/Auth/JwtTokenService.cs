using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using BanHang.BuildingBlocks.Authorization;

namespace BanHang.BuildingBlocks.Auth;

public sealed class JwtTokenService(IOptions<JwtOptions> options) : ITokenService
{
    public AccessToken GenerateAccessToken(
        long userId,
        string username,
        string roleKey,
        IReadOnlyCollection<string> permissionKeys,
        bool isFullBypass)
    {
        var jwt = options.Value;
        var expiresAtUtc = DateTime.UtcNow.AddMinutes(jwt.ExpiryMinutes);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Name, username),
            new(ClaimTypes.Role, roleKey),
            new(AuthorizationConstants.ClaimRoleKey, roleKey),
        };

        // Vai trò bypass thì danh sách quyền luôn rỗng — nhúng vào chỉ làm token phình vô ích.
        if (isFullBypass)
        {
            claims.Add(new Claim(AuthorizationConstants.ClaimFullBypass, "true"));
        }
        else
        {
            claims.Add(new Claim(AuthorizationConstants.ClaimPermissions, JsonSerializer.Serialize(permissionKeys)));
        }

        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Secret));
        var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: jwt.Issuer,
            audience: jwt.Audience,
            claims: claims,
            expires: expiresAtUtc,
            signingCredentials: credentials);

        var value = new JwtSecurityTokenHandler().WriteToken(token);

        return new AccessToken(value, expiresAtUtc);
    }

    public RefreshTokenResult GenerateRefreshToken()
    {
        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        var expiresAtUtc = DateTime.UtcNow.AddDays(options.Value.RefreshTokenExpiryDays);

        return new RefreshTokenResult(raw, HashRefreshToken(raw), expiresAtUtc);
    }

    public string HashRefreshToken(string rawToken)
    {
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawToken)));
    }
}
