using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed record SetUserStatusCommand(long Id, bool IsActive) : IRequest;
