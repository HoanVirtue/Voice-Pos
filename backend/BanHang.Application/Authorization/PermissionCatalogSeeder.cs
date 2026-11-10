using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using BanHang.BuildingBlocks.Authorization;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;

namespace BanHang.Application.Authorization;

/// <summary>
/// Upsert cây quyền khai báo trong code xuống bảng Permission mỗi lần khởi động, nhờ đó thêm quyền
/// mới chỉ cần sửa code chứ không phải viết migration.
///
/// Cố ý KHÔNG xoá key đã biến mất khỏi provider: có thể đang có dòng RolePermission trỏ tới, và
/// việc đổi tên quyền thường đi kèm bước chuyển dữ liệu thủ công. Chỉ ghi log cảnh báo.
/// </summary>
public static class PermissionCatalogSeeder
{
    public static async Task SeedAsync(
        IRepository<Permission> repository,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        SystemPermissionsValidator.Validate();

        var manager = new PermissionDefinitionManager(new SystemPermissionDefinitionProvider());
        var definitions = manager.GetAllFlat().ToList();

        // Collation DB không phân biệt hoa thường, nên dòng cũ chỉ khác chữ hoa/thường hoặc vừa có
        // bản đã xoá vừa có bản đang dùng vẫn là cùng một key. Gom theo key không phân biệt hoa
        // thường và ưu tiên dòng chưa xoá, tránh crash trùng key hoặc chèn thêm dòng trùng lúc khởi động.
        var rows = await repository.Queryable
            .IgnoreQueryFilters()
            .ToListAsync(cancellationToken);
        var existing = rows
            .GroupBy(p => p.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                g => g.Key,
                g => g.OrderBy(p => p.IsDeleted).ThenBy(p => p.Id).First(),
                StringComparer.OrdinalIgnoreCase);

        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var added = 0;
        var updated = 0;

        foreach (var definition in definitions)
        {
            seen.Add(definition.Name);

            if (existing.TryGetValue(definition.Name, out var permission))
            {
                permission.Update(
                    definition.DisplayName,
                    definition.GroupName ?? string.Empty,
                    definition.ParentName,
                    definition.GetIsMenu());
                await repository.UpdateAsync(permission, autoSave: false, cancellationToken);
                updated++;
            }
            else
            {
                var created = Permission.Create(
                    definition.Name,
                    definition.DisplayName,
                    definition.GroupName ?? string.Empty,
                    definition.ParentName,
                    definition.GetIsMenu());
                await repository.InsertAsync(created, autoSave: false, cancellationToken);
                added++;
            }
        }

        await repository.SaveChangesAsync(cancellationToken);

        var stale = existing.Keys.Where(key => !seen.Contains(key)).ToList();
        if (stale.Count > 0)
        {
            logger.LogWarning(
                "PermissionCatalogSeeder: {Count} quyền còn trong DB nhưng không còn khai báo trong code "
                + "(giữ nguyên, không tự xoá): {Keys}",
                stale.Count, string.Join(", ", stale));
        }

        logger.LogInformation(
            "PermissionCatalogSeeder: {Added} quyền mới, {Updated} quyền cập nhật, tổng {Total}.",
            added, updated, definitions.Count);
    }
}
