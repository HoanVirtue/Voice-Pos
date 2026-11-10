using MediatR; using BanHang.Application.Roles.Dtos;
namespace BanHang.Application.Roles.Queries;
public sealed record GetRoleByIdQuery(long Id) : IRequest<RoleDto>;
