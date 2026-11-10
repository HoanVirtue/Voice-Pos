using BanHang.BuildingBlocks.Authorization;

namespace BanHang.Application.Authorization;

/// <summary>
/// Khai báo cây quyền của hệ thống (mỗi nhóm một mục menu, quyền chi tiết là con). Thêm quyền mới: thêm hằng trong
/// <see cref="SystemPermissions"/> RỒI AddChild ở đây — <see cref="SystemPermissionsValidator"/> chặn ngay khi khởi động nếu lệch.
/// </summary>
public sealed class SystemPermissionDefinitionProvider : PermissionDefinitionProvider
{
    public override void Define(IPermissionDefinitionContext context)
    {
        var customers = context.AddGroup(SystemPermissions.Customers.GroupName, "KHÁCH HÀNG")
            .AddPermission(SystemPermissions.Customers.Default, "Khách hàng")
            .WithProperty(PermissionProperties.IsMenu, "True");
        customers.AddChild(SystemPermissions.Customers.View, "Xem khách hàng");
        customers.AddChild(SystemPermissions.Customers.Manage, "Thêm/sửa/xóa khách hàng");

        var transactions = context.AddGroup(SystemPermissions.Transactions.GroupName, "GIAO DỊCH")
            .AddPermission(SystemPermissions.Transactions.Default, "Giao dịch")
            .WithProperty(PermissionProperties.IsMenu, "True");
        transactions.AddChild(SystemPermissions.Transactions.View, "Xem giao dịch");
        transactions.AddChild(SystemPermissions.Transactions.Manage, "Ghi/sửa/xóa giao dịch");

        var reports = context.AddGroup(SystemPermissions.Reports.GroupName, "BÁO CÁO")
            .AddPermission(SystemPermissions.Reports.Default, "Báo cáo")
            .WithProperty(PermissionProperties.IsMenu, "True");
        reports.AddChild(SystemPermissions.Reports.View, "Xem báo cáo");

        var voice = context.AddGroup(SystemPermissions.Voice.GroupName, "GIỌNG NÓI")
            .AddPermission(SystemPermissions.Voice.Default, "Nhập liệu bằng giọng nói")
            .WithProperty(PermissionProperties.IsMenu, "False");
        voice.AddChild(SystemPermissions.Voice.Use, "Dùng nhập liệu giọng nói");

        var users = context.AddGroup(SystemPermissions.Users.GroupName, "TÀI KHOẢN")
            .AddPermission(SystemPermissions.Users.Default, "Tài khoản")
            .WithProperty(PermissionProperties.IsMenu, "True");
        users.AddChild(SystemPermissions.Users.Manage, "Quản lý tài khoản và vai trò");
    }
}
