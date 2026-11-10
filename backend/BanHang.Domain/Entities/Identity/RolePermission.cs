using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Identity;

/// <summary>
/// Một dòng cấp quyền. Cùng một bảng phục vụ hai loại grant:
/// <list type="bullet">
/// <item><c>UserId = 0</c> — quyền mặc định của vai trò.</item>
/// <item><c>UserId &gt; 0</c> — cấp/thu riêng cho một tài khoản, đè lên mặc định của vai trò đó.</item>
/// </list>
/// Công thức hiệu lực: dòng của chính user (nếu có) thắng dòng mặc định cùng (RoleId, PermissionKey).
/// Cột <see cref="Allow"/> là bool chứ không phải "có dòng nghĩa là được", để dòng override còn diễn
/// đạt được ý "thu hồi" một quyền mà vai trò vốn có.
/// </summary>
public sealed class RolePermission : AuditableEntity
{
    public long RoleId { get; private set; }

    /// <summary>0 = dòng mặc định của vai trò, không phải override của riêng ai.</summary>
    public long UserId { get; private set; }

    public string PermissionKey { get; private set; } = null!;

    public bool Allow { get; private set; }

    private RolePermission()
    {
    }

    public static RolePermission CreateRoleDefault(long roleId, string permissionKey, bool allow = true) =>
        Create(roleId, userId: 0, permissionKey, allow);

    public static RolePermission CreateUserOverride(long roleId, long userId, string permissionKey, bool allow)
    {
        if (userId <= 0)
            throw new ArgumentOutOfRangeException(nameof(userId), "Override phải gắn với một tài khoản cụ thể.");

        return Create(roleId, userId, permissionKey, allow);
    }

    private static RolePermission Create(long roleId, long userId, string permissionKey, bool allow)
    {
        if (string.IsNullOrWhiteSpace(permissionKey))
            throw new ArgumentException("PermissionKey is required.", nameof(permissionKey));

        return new RolePermission
        {
            RoleId = roleId,
            UserId = userId,
            PermissionKey = permissionKey,
            Allow = allow
        };
    }

    public void SetAllow(bool allow) => Allow = allow;
}
