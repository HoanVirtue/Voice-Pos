using MediatR;
using BanHang.Application.Auth.Dtos;

namespace BanHang.Application.Auth.Commands;

public sealed record LoginCommand(string Username, string Password) : IRequest<LoginResultDto>;
