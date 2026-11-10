using MediatR;
using BanHang.Application.Common.Requests;
using BanHang.Application.Roles.Dtos;
using BanHang.BuildingBlocks.Pagination;
namespace BanHang.Application.Roles.Queries;
public sealed class GetRolesQuery : QueryRequestBase, IRequest<PaginatedList<RoleListItemDto>> { public int? Status { get; set; } }
