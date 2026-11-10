using BanHang.Application.Products;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

/// <summary>Món hàng. Id do client sinh nên POST/PUT idempotent. Đồng bộ: <c>updatedSince=...&amp;includeDeleted=true</c>.</summary>
public sealed class ProductsController(ISender sender) : BaseController(sender)
{
    [HttpGet]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<PaginatedList<ProductDto>>>> List(
        [FromQuery] GetProductsQuery query, CancellationToken cancellationToken) =>
        Ok(ActionResponse<PaginatedList<ProductDto>>.Ok(await Sender.Send(query, cancellationToken)));

    [HttpGet("{id:guid}")]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<ProductDto>>> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(ActionResponse<ProductDto>.Ok(await Sender.Send(new GetProductByIdQuery(id), cancellationToken)));

    [HttpPost]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<ProductDto>>> Create(
        UpsertProductCommand command, CancellationToken cancellationToken) =>
        Ok(ActionResponse<ProductDto>.Ok(await Sender.Send(command, cancellationToken)));

    /// <summary>Tạo-hoặc-sửa theo Id trên đường dẫn (idempotent). Id trong body, nếu có, bị bỏ qua.</summary>
    [HttpPut("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<ProductDto>>> Update(
        Guid id, UpdateProductRequest request, CancellationToken cancellationToken) =>
        Ok(ActionResponse<ProductDto>.Ok(await Sender.Send(
            new UpsertProductCommand(id, request.Name, request.Alias, request.PricePerKg), cancellationToken)));

    /// <summary>Xóa mềm, idempotent.</summary>
    [HttpDelete("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(Guid id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteProductCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}

public sealed record UpdateProductRequest(string Name, string? Alias = null, long PricePerKg = 0);
