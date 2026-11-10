using BanHang.Application.Common.Requests;
using BanHang.Application.Customers.Dtos;
using BanHang.BuildingBlocks.Pagination;
using MediatR;

namespace BanHang.Application.Customers.Queries;

/// <summary>
/// Danh sách khách có phân trang. <see cref="UpdatedSince"/> (UTC) chỉ lấy bản ghi đổi sau mốc đó, sắp theo UpdatedAt
/// tăng dần — dùng cho đồng bộ của app; kèm <see cref="IncludeDeleted"/> để nhận cả khách đã xóa.
/// Không có UpdatedSince thì sắp theo tên.
/// </summary>
public sealed class GetCustomersQuery : QueryRequestBase, IRequest<PaginatedList<CustomerDto>>
{
    public DateTime? UpdatedSince { get; set; }

    public bool IncludeDeleted { get; set; }
}
