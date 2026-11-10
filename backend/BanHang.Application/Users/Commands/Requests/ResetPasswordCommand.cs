using MediatR;

namespace BanHang.Application.Users.Commands;

public sealed record ResetPasswordCommand(long UserId, string NewPassword) : IRequest;
