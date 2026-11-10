using BanHang.Application.Reports;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

/// <summary>Báo cáo chỉ đọc: tổng kết ngày (giờ VN), công nợ, tiền đi chợ, lãi theo lô.</summary>
public sealed class ReportsController(ISender sender) : BaseController(sender)
{
    [HttpGet("Daily")]
    [Permission(SystemPermissions.Reports.View)]
    public async Task<ActionResult<ActionResponse<DailyReportDto>>> Daily(
        [FromQuery] GetDailyReportQuery query, CancellationToken cancellationToken) =>
        Ok(ActionResponse<DailyReportDto>.Ok(await Sender.Send(query, cancellationToken)));

    [HttpGet("Debts")]
    [Permission(SystemPermissions.Reports.View)]
    public async Task<ActionResult<ActionResponse<IReadOnlyList<CustomerDebtDto>>>> Debts(CancellationToken cancellationToken) =>
        Ok(ActionResponse<IReadOnlyList<CustomerDebtDto>>.Ok(await Sender.Send(new GetDebtsQuery(), cancellationToken)));

    [HttpGet("Debts/{customerId:guid}")]
    [Permission(SystemPermissions.Reports.View)]
    public async Task<ActionResult<ActionResponse<CustomerDebtDetailDto>>> CustomerDebt(
        Guid customerId, CancellationToken cancellationToken) =>
        Ok(ActionResponse<CustomerDebtDetailDto>.Ok(await Sender.Send(new GetCustomerDebtQuery(customerId), cancellationToken)));

    [HttpGet("MarketCash")]
    [Permission(SystemPermissions.Reports.View)]
    public async Task<ActionResult<ActionResponse<MarketCashDto>>> MarketCash(
        [FromQuery] GetMarketCashQuery query, CancellationToken cancellationToken) =>
        Ok(ActionResponse<MarketCashDto>.Ok(await Sender.Send(query, cancellationToken)));

    [HttpGet("BatchProfit/{batchId:guid}")]
    [Permission(SystemPermissions.Reports.View)]
    public async Task<ActionResult<ActionResponse<BatchProfitDto>>> BatchProfit(
        Guid batchId, CancellationToken cancellationToken) =>
        Ok(ActionResponse<BatchProfitDto>.Ok(await Sender.Send(new GetBatchProfitQuery(batchId), cancellationToken)));
}
