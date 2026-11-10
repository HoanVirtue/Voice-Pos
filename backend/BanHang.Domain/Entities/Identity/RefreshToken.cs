using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Identity;

public sealed class RefreshToken : AuditableEntity
{
    public long UserId { get; private set; }

    /// <summary>SHA-256 hash of the raw token — chỉ giá trị thô mới được gửi cho client, DB không bao giờ lưu nó.</summary>
    public string TokenHash { get; private set; } = null!;

    public DateTime ExpiresAtUtc { get; private set; }
    public DateTime? RevokedAtUtc { get; private set; }

    /// <summary>Hash của token thay thế nó khi xoay vòng — dùng để phát hiện reuse token đã bị thu hồi.</summary>
    public string? ReplacedByTokenHash { get; private set; }

    private RefreshToken()
    {
    }

    public static RefreshToken Create(long userId, string tokenHash, DateTime expiresAtUtc)
    {
        return new RefreshToken
        {
            UserId = userId,
            TokenHash = tokenHash,
            ExpiresAtUtc = expiresAtUtc
        };
    }

    public bool IsActive => RevokedAtUtc is null && ExpiresAtUtc > DateTime.UtcNow;

    public void Revoke(string? replacedByTokenHash = null)
    {
        RevokedAtUtc = DateTime.UtcNow;
        ReplacedByTokenHash = replacedByTokenHash;
    }
}
