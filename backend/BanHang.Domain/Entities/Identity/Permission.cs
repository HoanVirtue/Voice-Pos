using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Identity;

/// <summary>
/// Catalog quyền — bản sao xuống DB của cây khai báo trong SystemPermissions/
/// SystemPermissionDefinitionProvider. Code vẫn là nguồn sự thật; bảng này tồn tại để RolePermission
/// và màn Phân quyền có dữ liệu để tham chiếu và hiển thị thay vì phải nạp cây từ code mỗi lần.
/// Được upsert lúc khởi động bởi PermissionCatalogSeeder.
/// </summary>
public sealed class Permission : AuditableEntity
{
    /// <summary>Khoá nghiệp vụ, ví dụ "Timesheet.Catalog.Shift.Edit". Duy nhất.</summary>
    public string Key { get; private set; } = null!;

    public string DisplayLabel { get; private set; } = null!;

    /// <summary>Tên phân hệ, ví dụ "Timesheet.Catalog".</summary>
    public string GroupName { get; private set; } = null!;

    /// <summary>Key của node cha; null nếu đây là mục menu cấp cao nhất trong nhóm.</summary>
    public string? ParentKey { get; private set; }

    /// <summary>True nếu node này là mục menu, false nếu là hành động con.</summary>
    public bool IsMenu { get; private set; }

    private Permission()
    {
    }

    public static Permission Create(string key, string displayLabel, string groupName, string? parentKey, bool isMenu)
    {
        var entity = new Permission { Key = key };
        entity.Update(displayLabel, groupName, parentKey, isMenu);
        return entity;
    }

    public void Update(string displayLabel, string groupName, string? parentKey, bool isMenu)
    {
        if (string.IsNullOrWhiteSpace(displayLabel))
            throw new ArgumentException("DisplayLabel is required.", nameof(displayLabel));

        DisplayLabel = displayLabel;
        GroupName = groupName;
        ParentKey = parentKey;
        IsMenu = isMenu;
        IsDeleted = false;
    }
}
