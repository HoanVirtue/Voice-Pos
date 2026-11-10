using MediatR;
using BanHang.Application.Permissions.Dtos;

namespace BanHang.Application.Permissions.Queries;

public sealed record GetMyPermissionsQuery : IRequest<MyPermissionsDto>;
