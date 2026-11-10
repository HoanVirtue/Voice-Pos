using System.Text.RegularExpressions;

namespace BanHang.Infrastructure.Persistence;

/// <summary>
/// Đổi lỗi trùng unique của MySQL thành câu tiếng Việt dễ hiểu. Thông điệp MySQL 8 dạng:
/// <c>Duplicate entry 'bo' for key 'User.IX_User_Username'</c> (tên bảng.tên index); bản cũ chỉ có tên index.
/// Thêm unique index mới thì thêm một dòng vào bảng dưới đây.
/// </summary>
public static partial class UniqueIndexMessages
{
    private const string DefaultMessage = "Dữ liệu bị trùng với bản ghi đã có, vui lòng kiểm tra lại.";

    private static readonly IReadOnlyDictionary<string, string> Messages = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        // Identity
        ["IX_User_Username"] = "Tên đăng nhập đã tồn tại.",
        ["IX_Role_Key"] = "Mã vai trò đã tồn tại.",
        ["IX_Permission_Key"] = "Mã quyền đã tồn tại.",
        ["IX_RolePermission_RoleId_UserId_PermissionKey"] = "Quyền này đã được gán trước đó.",
        ["IX_RefreshToken_TokenHash"] = "Phiên đăng nhập bị trùng, vui lòng thử lại.",
        // Customers: khóa chính do client sinh, trùng Id nghĩa là cùng một khách đã được tạo trước đó.
        ["PRIMARY"] = "Bản ghi này đã tồn tại.",
    };

    public static string Resolve(string? driverMessage)
    {
        if (string.IsNullOrEmpty(driverMessage))
        {
            return DefaultMessage;
        }

        var match = KeyNameRegex().Match(driverMessage);
        if (!match.Success)
        {
            return DefaultMessage;
        }

        var name = match.Groups[1].Value;
        return Messages.TryGetValue(name, out var message) ? message : DefaultMessage;
    }

    // "...for key 'User.IX_User_Username'" (MySQL 8) hoặc "...for key 'IX_User_Username'" (5.7).
    [GeneratedRegex(@"for key '(?:[^'.]+\.)?([^']+)'")]
    private static partial Regex KeyNameRegex();
}
