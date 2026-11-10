using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;
using BanHang.BuildingBlocks.Authorization;

namespace BanHang.WebAPI.Authorization;

/// <summary>
/// Dựng policy động từ tên policy mà <see cref="PermissionAttribute"/> sinh ra. Nhờ vậy thêm một
/// quyền mới không phải đăng ký thêm policy nào trong Program.cs.
/// </summary>
public sealed class PermissionPolicyProvider(IOptions<AuthorizationOptions> options)
    : DefaultAuthorizationPolicyProvider(options)
{
    public override Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        if (!policyName.StartsWith(AuthorizationConstants.PermissionPolicyPrefix, StringComparison.Ordinal))
        {
            return base.GetPolicyAsync(policyName);
        }

        var keys = policyName[AuthorizationConstants.PermissionPolicyPrefix.Length..]
            .Split(AuthorizationConstants.PermissionPolicySeparator, StringSplitOptions.RemoveEmptyEntries);

        var policy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .AddRequirements(new PermissionRequirement(keys))
            .Build();

        return Task.FromResult<AuthorizationPolicy?>(policy);
    }
}
