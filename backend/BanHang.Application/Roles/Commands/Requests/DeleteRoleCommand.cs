using MediatR;

namespace BanHang.Application.Roles.Commands;

public sealed record DeleteRoleCommand(long Id) : IRequest;
