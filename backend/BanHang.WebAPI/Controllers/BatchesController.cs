using BanHang.Application.Batches;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

/// <summary>Lô hàng (con lợn). Id do client sinh nên POST/PUT idempotent.</summary>
public sealed class BatchesController(ISender sender) : BaseController(sender)
{
    [HttpGet]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<PaginatedList<BatchDto>>>> List(
        [FromQuery] GetBatchesQuery query, CancellationToken cancellationToken) =>
        Ok(ActionResponse<PaginatedList<BatchDto>>.Ok(await Sender.Send(query, cancellationToken)));

    [HttpGet("{id:guid}")]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<BatchDto>>> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(ActionResponse<BatchDto>.Ok(await Sender.Send(new GetBatchByIdQuery(id), cancellationToken)));

    [HttpPost]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<BatchDto>>> Create(
        UpsertBatchCommand command, CancellationToken cancellationToken) =>
        Ok(ActionResponse<BatchDto>.Ok(await Sender.Send(command, cancellationToken)));

    /// <summary>Tạo-hoặc-sửa theo Id trên đường dẫn (idempotent). Id trong body, nếu có, bị bỏ qua.</summary>
    [HttpPut("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<BatchDto>>> Update(
        Guid id, UpdateBatchRequest request, CancellationToken cancellationToken) =>
        Ok(ActionResponse<BatchDto>.Ok(await Sender.Send(
            new UpsertBatchCommand(
                id, request.Date, request.PigCount, request.LiveWeightGram, request.CarcassWeightGram,
                request.BuyCost, request.OtherCost, request.Note),
            cancellationToken)));

    /// <summary>Xóa mềm, idempotent.</summary>
    [HttpDelete("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(Guid id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteBatchCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}

public sealed record UpdateBatchRequest(
    DateOnly Date,
    int PigCount = 0,
    int? LiveWeightGram = null,
    int? CarcassWeightGram = null,
    long BuyCost = 0,
    long OtherCost = 0,
    string? Note = null);
