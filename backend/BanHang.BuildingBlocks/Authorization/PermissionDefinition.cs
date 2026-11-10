namespace BanHang.BuildingBlocks.Authorization;

/// <summary>
/// Một node trong cây permission: có thể là mục menu hoặc một hành động con của mục đó.
/// Mô phỏng PermissionDefinition của ABP nhưng không phụ thuộc package ABP — dự án chỉ cần phần
/// khai báo cây, không cần vòng đời module của ABP.
/// </summary>
public sealed class PermissionDefinition
{
    public string Name { get; }
    public string DisplayName { get; }
    public string? ParentName { get; }
    public string? GroupName { get; }
    public List<PermissionDefinition> Children { get; } = [];
    public Dictionary<string, string> Properties { get; } = [];

    internal PermissionDefinition(string name, string displayName, string? parentName, string? groupName)
    {
        Name = name;
        DisplayName = displayName;
        ParentName = parentName;
        GroupName = groupName;
    }

    public PermissionDefinition AddChild(string name, string displayName)
    {
        var child = new PermissionDefinition(name, displayName, parentName: Name, groupName: GroupName);
        Children.Add(child);
        return child;
    }

    public PermissionDefinition WithProperty(string key, string value)
    {
        Properties[key] = value;
        return this;
    }

    /// <summary>Node này là một mục menu (FE dùng để dựng sidebar), không phải hành động con.</summary>
    public bool GetIsMenu() => Properties.TryGetValue(PermissionProperties.IsMenu, out var v) && v == "True";
}

public static class PermissionProperties
{
    public const string IsMenu = "isMenu";
}

/// <summary>Nhóm quyền ở cấp cao nhất — tương ứng một "phân hệ" trên màn Phân quyền.</summary>
public sealed class PermissionGroupDefinition
{
    public string Name { get; }
    public string DisplayName { get; }
    public List<PermissionDefinition> Permissions { get; } = [];

    internal PermissionGroupDefinition(string name, string displayName)
    {
        Name = name;
        DisplayName = displayName;
    }

    public PermissionDefinition AddPermission(string name, string displayName)
    {
        var permission = new PermissionDefinition(name, displayName, parentName: null, groupName: Name);
        Permissions.Add(permission);
        return permission;
    }
}

public interface IPermissionDefinitionContext
{
    IReadOnlyList<PermissionGroupDefinition> Groups { get; }

    PermissionGroupDefinition AddGroup(string name, string displayName);

    PermissionDefinition? GetPermissionOrNull(string name);
}

public sealed class PermissionDefinitionContext : IPermissionDefinitionContext
{
    private readonly List<PermissionGroupDefinition> _groups = [];

    public IReadOnlyList<PermissionGroupDefinition> Groups => _groups;

    public PermissionGroupDefinition AddGroup(string name, string displayName)
    {
        var group = new PermissionGroupDefinition(name, displayName);
        _groups.Add(group);
        return group;
    }

    public PermissionDefinition? GetPermissionOrNull(string name)
    {
        foreach (var group in _groups)
        {
            var found = FindRecursive(group.Permissions, name);
            if (found is not null)
            {
                return found;
            }
        }

        return null;
    }

    private static PermissionDefinition? FindRecursive(IEnumerable<PermissionDefinition> nodes, string name)
    {
        foreach (var node in nodes)
        {
            if (node.Name == name)
            {
                return node;
            }

            var childMatch = FindRecursive(node.Children, name);
            if (childMatch is not null)
            {
                return childMatch;
            }
        }

        return null;
    }
}

/// <summary>Kế thừa và override <see cref="Define"/> để khai báo cây quyền của hệ thống.</summary>
public abstract class PermissionDefinitionProvider
{
    public abstract void Define(IPermissionDefinitionContext context);
}

/// <summary>
/// Gọi Define() một lần rồi giữ kết quả trong bộ nhớ. Dùng để duyệt phẳng toàn bộ cây khi seed
/// catalog xuống DB hoặc khi trả cây quyền cho FE dựng màn Phân quyền.
/// </summary>
public sealed class PermissionDefinitionManager
{
    private readonly PermissionDefinitionContext _context = new();

    public PermissionDefinitionManager(PermissionDefinitionProvider provider)
    {
        provider.Define(_context);
    }

    public IReadOnlyList<PermissionGroupDefinition> Groups => _context.Groups;

    public IEnumerable<PermissionDefinition> GetAllFlat()
    {
        foreach (var group in _context.Groups)
        {
            foreach (var permission in group.Permissions)
            {
                foreach (var node in Flatten(permission))
                {
                    yield return node;
                }
            }
        }
    }

    private static IEnumerable<PermissionDefinition> Flatten(PermissionDefinition node)
    {
        yield return node;

        foreach (var child in node.Children)
        {
            foreach (var descendant in Flatten(child))
            {
                yield return descendant;
            }
        }
    }
}
