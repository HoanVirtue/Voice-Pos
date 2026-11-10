using MediatR;
using BanHang.Application.Auth.Dtos;

namespace BanHang.Application.Auth.Commands;

public sealed record RefreshTokenCommand(string RefreshToken) : IRequest<LoginResultDto>;
