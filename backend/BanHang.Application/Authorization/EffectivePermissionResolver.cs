using Microsoft.EntityFrameworkCore;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Authorization;

/// <summary>
/// Tính tập quyền hiệu lực của một tài khoản: quyền mặc định của vai trò, sau đó áp override riêng
/// của chính tài khoản đó đè lên.
///
/// Override có thể mang <c>Allow = false</c> để THU HỒI một quyền mà vai trò vốn có — vì vậy không
/// thể chỉ hợp nhất hai danh sách, phải xử lý theo thứ tự.
/// </summary>
public sealed class EffectivePermissionResolver(IReadOnlyRepository<RolePermission> repository)
{
    public async Task<IReadOnlyCollection<string>> ResolveAsync(
        long roleId, long userId, CancellationToken cancellationToken = default)
    {
        var rows = await repository.Queryable
            .Where(rp => rp.RoleId == roleId && (rp.UserId == 0 || rp.UserId == userId))
            .Select(rp => new { rp.UserId, rp.PermissionKey, rp.Allow })
            .ToListAsync(cancellationToken);

        var effective = new HashSet<string>();

        foreach (var row in rows.Where(r => r.UserId == 0 && r.Allow))
        {
            effective.Add(row.PermissionKey);
        }

        foreach (var row in rows.Where(r => r.UserId != 0))
        {
            if (row.Allow)
            {
                effective.Add(row.PermissionKey);
            }
            else
            {
                effective.Remove(row.PermissionKey);
            }
        }

        return effective;
    }
}
