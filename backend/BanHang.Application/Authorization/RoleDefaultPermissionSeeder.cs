using BanHang.BuildingBlocks.Authorization;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BanHang.Application.Authorization;

/// <summary>
/// Seed các vai trò mặc định lúc khởi động: <c>Admin</c> (toàn quyền, bypass) và <c>Seller</c> (bán hàng).
/// Chỉ THÊM quyền còn thiếu cho Seller, không bao giờ gỡ — quản trị viên chỉnh tay thì giữ nguyên.
/// </summary>
public static class RoleDefaultPermissionSeeder
{
    public const string AdminKey = "Admin";
    public const string SellerKey = "Seller";

    /// <summary>Quyền mặc định của vai trò Bán hàng: mọi thứ trừ quản lý tài khoản.</summary>
    public static readonly IReadOnlyCollection<string> SellerPermissions =
    [
        SystemPermissions.Customers.Default,
        SystemPermissions.Customers.View,
        SystemPermissions.Customers.Manage,
        SystemPermissions.Transactions.Default,
        SystemPermissions.Transactions.View,
        SystemPermissions.Transactions.Manage,
        SystemPermissions.Reports.Default,
        SystemPermissions.Reports.View,
        SystemPermissions.Voice.Default,
        SystemPermissions.Voice.Use,
    ];

    public static async Task SeedAsync(
        IRepository<Role> roleRepository,
        IRepository<RolePermission> rolePermissionRepository,
        ILogger? logger = null,
        CancellationToken cancellationToken = default)
    {
        await EnsureRoleAsync(
            roleRepository, AdminKey, "Quản trị viên",
            "Toàn quyền cấu hình và quản trị hệ thống",
            isFullBypass: true, sortOrder: 1, logger, cancellationToken);

        var seller = await EnsureRoleAsync(
            roleRepository, SellerKey, "Bán hàng",
            "Bán hàng, quản lý khách hàng, giao dịch và báo cáo",
            isFullBypass: false, sortOrder: 2, logger, cancellationToken);

        var existingKeys = (await rolePermissionRepository.Queryable
                .IgnoreQueryFilters()
                .Where(rp => rp.RoleId == seller.Id && rp.UserId == 0)
                .Select(rp => rp.PermissionKey)
                .ToListAsync(cancellationToken))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var missing = SellerPermissions
            .Where(key => !existingKeys.Contains(key))
            .Select(key => RolePermission.CreateRoleDefault(seller.Id, key))
            .ToList();

        if (missing.Count > 0)
        {
            await rolePermissionRepository.InsertManyAsync(missing, cancellationToken: cancellationToken);
            logger?.LogInformation(
                "RoleDefaultPermissionSeeder: đã gán {Count} quyền mặc định cho vai trò '{Key}'.", missing.Count, SellerKey);
        }
    }

    private static async Task<Role> EnsureRoleAsync(
        IRepository<Role> repository,
        string key,
        string displayName,
        string description,
        bool isFullBypass,
        int sortOrder,
        ILogger? logger,
        CancellationToken cancellationToken)
    {
        // Ưu tiên dòng đang dùng; nếu chỉ còn bản đã xóa mềm thì phục hồi, không tạo vai trò thứ hai cùng key.
        var normalizedKey = key.ToUpper();
        var existing = await repository.Queryable
            .IgnoreQueryFilters()
            .Where(r => r.Key.ToUpper() == normalizedKey)
            .OrderBy(r => r.IsDeleted)
            .ThenBy(r => r.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (existing is not null)
        {
            // Queryable là no-tracking nên entity đọc ở đây UpdateAsync (Set.Update) vẫn chạy đúng.
            if (existing.IsDeleted)
            {
                existing.IsDeleted = false;
                await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
                logger?.LogInformation("RoleDefaultPermissionSeeder: đã phục hồi vai trò '{Key}'.", key);
            }

            if (!existing.IsSystem)
            {
                existing.SetSystem(true);
                await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
            }

            return existing;
        }

        var role = Role.Create(key, displayName, description, isFullBypass, isSystem: true, sortOrder: sortOrder);
        await repository.InsertAsync(role, cancellationToken: cancellationToken);
        logger?.LogInformation("RoleDefaultPermissionSeeder: đã tạo vai trò '{Key}' ({DisplayName}).", key, displayName);
        return role;
    }
}
