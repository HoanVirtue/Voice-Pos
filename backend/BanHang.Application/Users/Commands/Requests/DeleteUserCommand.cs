using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed record DeleteUserCommand(long Id) : IRequest;
