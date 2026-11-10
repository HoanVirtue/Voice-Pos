namespace BanHang.Application.Roles.Dtos;

public sealed record RoleDto(
    long Id,
    string Key,
    string DisplayName,
    string? Description,
    bool IsFullBypass,
    bool IsSystem,
    int SortOrder,
    int Status);

/// <summary>Dòng trên màn Phân quyền: kèm số quyền đang cấp và số tài khoản đang dùng vai trò.</summary>
public sealed record RoleListItemDto(
    long Id,
    string Key,
    string DisplayName,
    string? Description,
    bool IsFullBypass,
    bool IsSystem,
    int SortOrder,
    int PermissionCount,
    int UserCount,
    int Status);
