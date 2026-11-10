using MediatR;

namespace BanHang.Application.Roles.Commands;

public sealed record SetRoleStatusCommand(long Id, bool IsActive) : IRequest;
