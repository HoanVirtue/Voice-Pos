using MediatR;

namespace BanHang.Application.Roles.Commands;

public sealed record UpdateRoleCommand(long Id, string DisplayName, string? Description = null, int SortOrder = 0) : IRequest;
