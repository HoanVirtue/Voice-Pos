namespace BanHang.BuildingBlocks.Authorization;

public static class AuthorizationConstants
{
    /// <summary>Claim chứa mảng JSON các permission key mà tài khoản được phép.</summary>
    public const string ClaimPermissions = "perms";

    /// <summary>Claim chứa Key của vai trò (Role.Key), ví dụ "Admin".</summary>
    public const string ClaimRoleKey = "role_key";

    /// <summary>Claim đánh dấu vai trò bỏ qua mọi kiểm tra quyền.</summary>
    public const string ClaimFullBypass = "full_bypass";

    /// <summary>Tiền tố policy cho <c>[Permission(...)]</c>. Nhiều key ngăn bằng '|' nghĩa là HOẶC.</summary>
    public const string PermissionPolicyPrefix = "PERMISSION_KEY:";

    public const char PermissionPolicySeparator = '|';
}
