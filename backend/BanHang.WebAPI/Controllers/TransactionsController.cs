using BanHang.Application.Transactions;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

/// <summary>
/// Giao dịch (bán / thu nợ / mua lợn / chi khác / mang tiền đi). Id do client sinh nên POST/PUT idempotent.
/// Lọc thêm: <c>from</c>, <c>to</c> (UTC), <c>customerId</c>, <c>type</c>.
/// </summary>
public sealed class TransactionsController(ISender sender) : BaseController(sender)
{
    [HttpGet]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<PaginatedList<TransactionDto>>>> List(
        [FromQuery] GetTransactionsQuery query, CancellationToken cancellationToken) =>
        Ok(ActionResponse<PaginatedList<TransactionDto>>.Ok(await Sender.Send(query, cancellationToken)));

    [HttpGet("{id:guid}")]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<TransactionDto>>> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(ActionResponse<TransactionDto>.Ok(await Sender.Send(new GetTransactionByIdQuery(id), cancellationToken)));

    [HttpPost]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<TransactionDto>>> Create(
        UpsertTransactionCommand command, CancellationToken cancellationToken) =>
        Ok(ActionResponse<TransactionDto>.Ok(await Sender.Send(command, cancellationToken)));

    /// <summary>Tạo-hoặc-sửa theo Id trên đường dẫn (idempotent). Id trong body, nếu có, bị bỏ qua.</summary>
    [HttpPut("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<TransactionDto>>> Update(
        Guid id, UpdateTransactionRequest r, CancellationToken cancellationToken) =>
        Ok(ActionResponse<TransactionDto>.Ok(await Sender.Send(
            new UpsertTransactionCommand(
                id, r.OccurredAt, r.Type, r.CustomerId, r.ProductId, r.BatchId, r.WeightGram, r.Amount,
                r.PaidAmount, r.RawText, r.Confidence, r.Note),
            cancellationToken)));

    /// <summary>Xóa mềm, idempotent.</summary>
    [HttpDelete("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(Guid id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteTransactionCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}

public sealed record UpdateTransactionRequest(
    DateTime OccurredAt,
    string Type,
    Guid? CustomerId = null,
    Guid? ProductId = null,
    Guid? BatchId = null,
    int? WeightGram = null,
    long Amount = 0,
    long PaidAmount = 0,
    string? RawText = null,
    double? Confidence = null,
    string? Note = null);
