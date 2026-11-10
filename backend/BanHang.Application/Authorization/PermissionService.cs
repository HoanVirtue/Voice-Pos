using System.Security.Claims;
using System.Text.Json;
using BanHang.BuildingBlocks.Authorization;

namespace BanHang.Application.Authorization;

/// <summary>
/// Quyết định một request có được phép hay không. Đọc thẳng claim trong JWT, KHÔNG truy vấn DB —
/// quyền đã được tính sẵn lúc đăng nhập nên mỗi request không phải chịu thêm một vòng vào database.
///
/// Đánh đổi: quyền đổi thì token cũ vẫn còn hiệu lực tới lúc hết hạn. Chấp nhận được vì token ngắn
/// hạn; nếu cần thu hồi tức thì thì thêm claim phiên bản quyền và đối chiếu ở middleware.
/// </summary>
public sealed class PermissionService
{
    public bool Can(ClaimsPrincipal? user, string permissionKey)
    {
        if (user is null || string.IsNullOrWhiteSpace(permissionKey))
        {
            return false;
        }

        if (!user.Identity?.IsAuthenticated ?? true)
        {
            return false;
        }

        // Quy tắc bỏ qua duy nhất của hệ thống — thay cho việc rải `if (role == "Admin")` khắp nơi.
        if (user.FindFirst(AuthorizationConstants.ClaimFullBypass)?.Value == "true"
            || user.IsInRole("Admin"))
        {
            return true;
        }

        return GetPermissions(user).Contains(permissionKey);
    }

    /// <summary>Có MỘT trong các key là đủ (HOẶC).</summary>
    public bool CanAny(ClaimsPrincipal? user, IEnumerable<string> permissionKeys) =>
        permissionKeys.Any(key => Can(user, key));

    public static IReadOnlySet<string> GetPermissions(ClaimsPrincipal user)
    {
        var raw = user.FindFirst(AuthorizationConstants.ClaimPermissions)?.Value;
        if (string.IsNullOrWhiteSpace(raw))
        {
            return new HashSet<string>();
        }

        try
        {
            return JsonSerializer.Deserialize<HashSet<string>>(raw) ?? [];
        }
        catch (JsonException)
        {
            // Token hỏng hoặc do bản cũ phát hành — coi như không có quyền nào thay vì ném lỗi 500.
            return new HashSet<string>();
        }
    }
}
