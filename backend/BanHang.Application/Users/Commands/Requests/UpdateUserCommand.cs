using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed record UpdateUserCommand(long Id, long RoleId, string? DisplayName = null) : IRequest;
