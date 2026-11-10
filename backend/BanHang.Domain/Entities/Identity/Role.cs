using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Identity;

/// <summary>
/// Vai trò người dùng. Thay cho enum UserRole cũ: vai trò giờ là dữ liệu nên quản trị viên tạo thêm
/// được từ màn Phân quyền mà không phải sửa code và build lại.
/// </summary>
public sealed class Role : AuditableEntity
{
    /// <summary>Mã không dấu, dùng trong claim và khi seed. Duy nhất, không đổi sau khi tạo.</summary>
    public string Key { get; private set; } = null!;

    public string DisplayName { get; private set; } = null!;

    public string? Description { get; private set; }

    /// <summary>
    /// Chỉ true cho vai trò quản trị hệ thống — bỏ qua mọi kiểm tra quyền. Đây là quy tắc bypass
    /// duy nhất của hệ thống, thay cho việc rải `if (role == "Admin")` ở từng nơi.
    /// </summary>
    public bool IsFullBypass { get; private set; }

    /// <summary>Vai trò seed sẵn — không cho xoá, tránh tự khoá mình ra khỏi hệ thống.</summary>
    public bool IsSystem { get; private set; }

    public int SortOrder { get; private set; }

    public int Status { get; private set; } = 1;

    private Role()
    {
    }

    public static Role Create(
        string key, string displayName, string? description = null,
        bool isFullBypass = false, bool isSystem = false, int sortOrder = 0)
    {
        if (string.IsNullOrWhiteSpace(key))
            throw new ArgumentException("Key is required.", nameof(key));

        var entity = new Role { Key = key, IsFullBypass = isFullBypass, IsSystem = isSystem };
        entity.Update(displayName, description, sortOrder);
        return entity;
    }

    public void Update(string displayName, string? description, int sortOrder)
    {
        if (string.IsNullOrWhiteSpace(displayName))
            throw new ArgumentException("DisplayName is required.", nameof(displayName));

        DisplayName = displayName;
        Description = description;
        SortOrder = sortOrder;
    }

    public void SetSystem(bool isSystem) => IsSystem = isSystem;

    public void Activate() => Status = 1;

    public void Deactivate() => Status = 0;
}
