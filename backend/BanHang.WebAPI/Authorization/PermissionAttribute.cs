using Microsoft.AspNetCore.Authorization;
using BanHang.BuildingBlocks.Authorization;

namespace BanHang.WebAPI.Authorization;

/// <summary>
/// Yêu cầu quyền cho một action, ví dụ:
/// <code>[Permission(SystemPermissions.Catalog.Shift.Edit)]</code>
///
/// Truyền nhiều key nghĩa là "có MỘT trong số đó là được" (HOẶC). Lặp nhiều attribute là VÀ
/// (mọi policy đều phải qua), nên trường hợp HOẶC bắt buộc phải gói trong một attribute.
/// </summary>
[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class, AllowMultiple = true)]
public sealed class PermissionAttribute : AuthorizeAttribute
{
    public PermissionAttribute(params string[] permissionKeys)
    {
        if (permissionKeys.Length == 0)
        {
            throw new ArgumentException("Phải truyền ít nhất một permission key.", nameof(permissionKeys));
        }

        Policy = AuthorizationConstants.PermissionPolicyPrefix
                 + string.Join(AuthorizationConstants.PermissionPolicySeparator, permissionKeys);
    }
}
