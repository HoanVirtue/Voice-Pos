using Microsoft.AspNetCore.Authorization;
using BanHang.Application.Authorization;

namespace BanHang.WebAPI.Authorization;

public sealed class PermissionHandler(PermissionService permissionService)
    : AuthorizationHandler<PermissionRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        if (permissionService.CanAny(context.User, requirement.Keys))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
