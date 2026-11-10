using MediatR;

namespace BanHang.Application.Users.Commands;

/// <summary>Người dùng tự đổi mật khẩu của chính mình.</summary>
public sealed record ChangeMyPasswordCommand(string CurrentPassword, string NewPassword) : IRequest;
