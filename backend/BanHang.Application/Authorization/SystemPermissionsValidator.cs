using BanHang.BuildingBlocks.Authorization;

namespace BanHang.Application.Authorization;

/// <summary>
/// Đối chiếu hằng khai báo trong <see cref="SystemPermissions"/> với cây đăng ký trong
/// <see cref="SystemPermissionDefinitionProvider"/>. Gọi lúc khởi động để lỗi lộ ra ngay, thay vì
/// âm thầm khiến một quyền không bao giờ cấp được (khai hằng mà quên AddChild) hoặc gán
/// <c>[Permission]</c> bằng chuỗi không tồn tại (AddChild mà quên khai hằng).
/// </summary>
public static class SystemPermissionsValidator
{
    public static void Validate()
    {
        var declared = SystemPermissions.GetAll().ToHashSet();
        var manager = new PermissionDefinitionManager(new SystemPermissionDefinitionProvider());
        var registered = manager.GetAllFlat().Select(p => p.Name).ToHashSet();

        var missingInProvider = declared.Where(key => !registered.Contains(key)).ToList();
        var missingInDeclared = registered.Where(key => !declared.Contains(key)).ToList();

        if (missingInProvider.Count == 0 && missingInDeclared.Count == 0)
        {
            return;
        }

        throw new InvalidOperationException(
            "SystemPermissions.cs và SystemPermissionDefinitionProvider.cs bị lệch nhau.\n"
            + $"Khai trong SystemPermissions nhưng chưa AddChild: {Join(missingInProvider)}\n"
            + $"Đăng ký trong Provider nhưng không có hằng tương ứng: {Join(missingInDeclared)}");

        static string Join(IEnumerable<string> keys)
        {
            var list = keys.ToList();
            return list.Count == 0 ? "(không có)" : string.Join(", ", list);
        }
    }
}
