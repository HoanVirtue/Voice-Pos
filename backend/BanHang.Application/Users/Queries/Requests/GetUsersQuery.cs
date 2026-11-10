using MediatR; using BanHang.Application.Common.Requests; using BanHang.Application.Users.Dtos; using BanHang.BuildingBlocks.Pagination;
namespace BanHang.Application.Users.Queries;
public sealed class GetUsersQuery : QueryRequestBase, IRequest<PaginatedList<UserListItemDto>> { public long? RoleId { get; set; } public int? Status { get; set; } }
