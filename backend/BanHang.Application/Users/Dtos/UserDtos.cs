namespace BanHang.Application.Users.Dtos;

public sealed record UserListItemDto(
    long Id,
    string Username,
    string? DisplayName,
    long RoleId,
    string RoleDisplayName,
    string RoleKey,
    int Status,
    DateTime CreatedAt);

public sealed record UserDto(
    long Id,
    string Username,
    string? DisplayName,
    long RoleId,
    string RoleDisplayName,
    string RoleKey,
    int Status,
    DateTime CreatedAt);
