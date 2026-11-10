using MediatR;

namespace BanHang.Application.Roles.Commands;

public sealed record CreateRoleCommand(string Key, string DisplayName, string? Description = null, int SortOrder = 0) : IRequest<long>;
