using BanHang.Application.Customers.Commands;
using BanHang.Application.Customers.Dtos;
using BanHang.Application.Customers.Queries;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

/// <summary>
/// Khách hàng. Id do client sinh (UUID) nên POST/PUT idempotent: app gửi lại từ outbox bao nhiêu lần cũng chỉ ra một bản ghi.
/// </summary>
public sealed class CustomersController(ISender sender) : BaseController(sender)
{
    /// <summary>Danh sách có phân trang. Đồng bộ: <c>updatedSince=2026-01-01T00:00:00Z&amp;includeDeleted=true</c>.</summary>
    [HttpGet]
    [Permission(SystemPermissions.Customers.View)]
    public async Task<ActionResult<ActionResponse<PaginatedList<CustomerDto>>>> List(
        [FromQuery] GetCustomersQuery query, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(query, cancellationToken);
        return Ok(ActionResponse<PaginatedList<CustomerDto>>.Ok(result));
    }

    [HttpGet("{id:guid}")]
    [Permission(SystemPermissions.Customers.View)]
    public async Task<ActionResult<ActionResponse<CustomerDto>>> Get(Guid id, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetCustomerByIdQuery(id), cancellationToken);
        return Ok(ActionResponse<CustomerDto>.Ok(result));
    }

    /// <summary>Tạo khách mới với Id do client sinh; đã có Id này thì cập nhật (idempotent).</summary>
    [HttpPost]
    [Permission(SystemPermissions.Customers.Manage)]
    public async Task<ActionResult<ActionResponse<CustomerDto>>> Create(
        UpsertCustomerCommand command, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse<CustomerDto>.Ok(result));
    }

    /// <summary>Tạo-hoặc-sửa theo Id trên đường dẫn (idempotent). Id trong body, nếu có, bị bỏ qua.</summary>
    [HttpPut("{id:guid}")]
    [Permission(SystemPermissions.Customers.Manage)]
    public async Task<ActionResult<ActionResponse<CustomerDto>>> Update(
        Guid id, UpdateCustomerRequest request, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(
            new UpsertCustomerCommand(id, request.Name, request.Alias, request.Phone, request.Note), cancellationToken);
        return Ok(ActionResponse<CustomerDto>.Ok(result));
    }

    /// <summary>Xóa mềm. Idempotent: khách không có hoặc đã xóa vẫn trả thành công.</summary>
    [HttpDelete("{id:guid}")]
    [Permission(SystemPermissions.Customers.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(Guid id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteCustomerCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}

public sealed record UpdateCustomerRequest(string Name, string? Alias = null, string? Phone = null, string? Note = null);
