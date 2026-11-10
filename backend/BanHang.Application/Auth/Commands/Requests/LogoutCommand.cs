using MediatR;

namespace BanHang.Application.Auth.Commands;

public sealed record LogoutCommand(string? RefreshToken) : IRequest;
