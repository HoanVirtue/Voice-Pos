using System.Reflection;

namespace BanHang.BuildingBlocks.Authorization;

/// <summary>
/// Danh mục quyền của toàn hệ thống (hằng chuỗi). Khi thêm quyền: thêm hằng ở đây RỒI khai báo trong
/// <c>SystemPermissionDefinitionProvider</c> — <c>SystemPermissionsValidator</c> chặn ngay lúc khởi động nếu lệch.
/// </summary>
public static class SystemPermissions
{
    public static class Customers
    {
        public const string GroupName = "BanHang.Customers";

        public const string Default = GroupName + ".Customer";
        public const string View = Default + ".View";
        public const string Manage = Default + ".Manage";
    }

    public static class Transactions
    {
        public const string GroupName = "BanHang.Transactions";

        public const string Default = GroupName + ".Transaction";
        public const string View = Default + ".View";
        public const string Manage = Default + ".Manage";
    }

    public static class Reports
    {
        public const string GroupName = "BanHang.Reports";

        public const string Default = GroupName + ".Report";
        public const string View = Default + ".View";
    }

    public static class Voice
    {
        public const string GroupName = "BanHang.Voice";

        public const string Default = GroupName + ".Voice";
        public const string Use = Default + ".Use";
    }

    public static class Users
    {
        public const string GroupName = "BanHang.Users";

        public const string Default = GroupName + ".User";
        public const string Manage = Default + ".Manage";
    }

    /// <summary>Mọi hằng quyền (bỏ qua GroupName), dùng để so khớp với danh mục và cấp toàn quyền cho Admin.</summary>
    public static IEnumerable<string> GetAll()
    {
        foreach (var value in Collect(typeof(SystemPermissions)))
        {
            yield return value;
        }
    }

    private static IEnumerable<string> Collect(Type type)
    {
        foreach (var field in type.GetFields(BindingFlags.Public | BindingFlags.Static | BindingFlags.FlattenHierarchy))
        {
            if (field is { IsLiteral: true, IsInitOnly: false }
                && field.FieldType == typeof(string)
                && field.Name != "GroupName"
                && field.GetValue(null) is string value)
            {
                yield return value;
            }
        }

        foreach (var nested in type.GetNestedTypes(BindingFlags.Public))
        {
            foreach (var value in Collect(nested))
            {
                yield return value;
            }
        }
    }
}
