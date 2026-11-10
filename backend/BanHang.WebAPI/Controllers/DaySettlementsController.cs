using BanHang.Application.DaySettlements;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

/// <summary>Chốt sổ ngày. Server tự tính tiền theo sổ và chênh lệch; mỗi ngày một bản ghi chưa xóa (trùng ngày → 409).</summary>
public sealed class DaySettlementsController(ISender sender) : BaseController(sender)
{
    [HttpGet]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<PaginatedList<DaySettlementDto>>>> List(
        [FromQuery] GetDaySettlementsQuery query, CancellationToken cancellationToken) =>
        Ok(ActionResponse<PaginatedList<DaySettlementDto>>.Ok(await Sender.Send(query, cancellationToken)));

    [HttpGet("{id:guid}")]
    [Permission(SystemPermissions.Transactions.View)]
    public async Task<ActionResult<ActionResponse<DaySettlementDto>>> Get(Guid id, CancellationToken cancellationToken) =>
        Ok(ActionResponse<DaySettlementDto>.Ok(await Sender.Send(new GetDaySettlementByIdQuery(id), cancellationToken)));

    [HttpPost]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<DaySettlementDto>>> Create(
        UpsertDaySettlementCommand command, CancellationToken cancellationToken) =>
        Ok(ActionResponse<DaySettlementDto>.Ok(await Sender.Send(command, cancellationToken)));

    /// <summary>Tạo-hoặc-sửa theo Id trên đường dẫn (idempotent). Id trong body, nếu có, bị bỏ qua.</summary>
    [HttpPut("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse<DaySettlementDto>>> Update(
        Guid id, UpdateDaySettlementRequest r, CancellationToken cancellationToken) =>
        Ok(ActionResponse<DaySettlementDto>.Ok(await Sender.Send(
            new UpsertDaySettlementCommand(id, r.Date, r.OpeningCash, r.CountedCash, r.Note), cancellationToken)));

    /// <summary>Xóa mềm, idempotent.</summary>
    [HttpDelete("{id:guid}")]
    [Permission(SystemPermissions.Transactions.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(Guid id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteDaySettlementCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}

public sealed record UpdateDaySettlementRequest(DateOnly Date, long OpeningCash = 0, long CountedCash = 0, string? Note = null);
