namespace BanHang.Application.Permissions.Dtos;

/// <summary>Quyền hiệu lực của người đang đăng nhập (tính lại từ DB, không đọc claim) để app ẩn/hiện chức năng.</summary>
public sealed record MyPermissionsDto(
    long UserId,
    string Username,
    long RoleId,
    string RoleKey,
    string RoleDisplayName,
    bool IsFullBypass,
    IReadOnlyCollection<string> Permissions);
