using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed record CreateUserCommand(string Username, string Password, long RoleId, string? DisplayName = null) : IRequest<long>;
