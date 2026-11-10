namespace BanHang.BuildingBlocks.Auth;

public interface ITokenService
{
    /// <summary>
    /// Phát hành access token. <paramref name="permissionKeys"/> được nhúng thẳng vào claim để
    /// mỗi request không phải tra lại quyền từ database; <paramref name="isFullBypass"/> đánh dấu
    /// vai trò quản trị bỏ qua mọi kiểm tra.
    /// </summary>
    AccessToken GenerateAccessToken(
        long userId,
        string username,
        string roleKey,
        IReadOnlyCollection<string> permissionKeys,
        bool isFullBypass);

    /// <summary>Sinh refresh token ngẫu nhiên mới. Chỉ <see cref="RefreshTokenResult.RawValue"/> được trả về client.</summary>
    RefreshTokenResult GenerateRefreshToken();

    /// <summary>Băm một refresh token thô để so khớp/lưu trữ — DB chỉ giữ hash, không bao giờ giữ giá trị thô.</summary>
    string HashRefreshToken(string rawToken);
}

public sealed record AccessToken(string Value, DateTime ExpiresAtUtc);

public sealed record RefreshTokenResult(string RawValue, string Hash, DateTime ExpiresAtUtc);
