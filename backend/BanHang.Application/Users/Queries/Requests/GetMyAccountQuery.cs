using MediatR; using BanHang.Application.Users.Dtos;
namespace BanHang.Application.Users.Queries;
public sealed record GetMyAccountQuery : IRequest<UserDto>;
