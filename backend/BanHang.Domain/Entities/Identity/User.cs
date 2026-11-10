using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Identity;

public sealed class User : AuditableEntity
{
    public string Username { get; private set; } = null!;

    /// <summary>Tên hiển thị trong app (ví dụ "Bố", "Mẹ").</summary>
    public string? DisplayName { get; private set; }

    public string PasswordHash { get; private set; } = null!;

    public long RoleId { get; private set; }

    /// <summary>1 = đang hoạt động, 0 = bị khoá (xem <c>RecordStatus</c>).</summary>
    public int Status { get; private set; } = 1;

    private User()
    {
    }

    public static User Create(string username, string passwordHash, long roleId, string? displayName = null)
    {
        if (string.IsNullOrWhiteSpace(username))
            throw new ArgumentException("Username is required.", nameof(username));
        if (string.IsNullOrWhiteSpace(passwordHash))
            throw new ArgumentException("PasswordHash is required.", nameof(passwordHash));
        if (roleId <= 0)
            throw new ArgumentOutOfRangeException(nameof(roleId), "RoleId is required.");

        return new User
        {
            Username = username,
            PasswordHash = passwordHash,
            RoleId = roleId,
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? null : displayName.Trim()
        };
    }

    public void ChangePassword(string newPasswordHash)
    {
        if (string.IsNullOrWhiteSpace(newPasswordHash))
            throw new ArgumentException("PasswordHash is required.", nameof(newPasswordHash));

        PasswordHash = newPasswordHash;
    }

    public void ChangeRole(long roleId)
    {
        if (roleId <= 0)
            throw new ArgumentOutOfRangeException(nameof(roleId), "RoleId is required.");

        RoleId = roleId;
    }

    public void Update(long roleId, string? displayName)
    {
        ChangeRole(roleId);
        DisplayName = string.IsNullOrWhiteSpace(displayName) ? null : displayName.Trim();
    }

    public void Activate() => Status = 1;

    public void Deactivate() => Status = 0;
}
