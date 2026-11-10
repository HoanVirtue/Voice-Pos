using BanHang.Application.Common;
using BanHang.Domain.Entities.Batches;
using BanHang.Domain.Entities.Customers;
using BanHang.Domain.Entities.Transactions;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.SharedKernel.Repositories;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Reports;

public sealed record DailyReportDto(
    DateOnly Date,
    long Revenue,
    long CashSales,
    long NewDebt,
    long DebtCollected,
    long CashIn,
    long BuyPigCost,
    long ExpenseCost,
    long CashOut,
    long CashInHand,
    int TransactionCount);

public sealed record CustomerDebtDto(
    Guid CustomerId, string CustomerName, long TotalSale, long TotalPaid, long TotalDebtPayment, long Debt);

public sealed record DebtItemDto(
    Guid TransactionId, DateTime OccurredAt, string Type, long Amount, long PaidAmount, long DebtDelta);

public sealed record CustomerDebtDetailDto(Guid CustomerId, string CustomerName, long Debt, IReadOnlyList<DebtItemDto> Items);

public sealed record MarketCashDto(long PigCost, long SupplierDebt, long Reserve, long Total);

public sealed record BatchProfitDto(Guid BatchId, long Revenue, long BuyCost, long OtherCost, long Profit);

/// <summary>Công thức Báo cáo ngày — dùng chung cho báo cáo và chốt sổ (tiền theo sổ).</summary>
public static class DailyReportCalculator
{
    public static async Task<DailyReportDto> ComputeAsync(
        IReadOnlyRepository<Transaction, Guid> repository, DateOnly date, long openingCash, CancellationToken cancellationToken)
    {
        var (from, to) = VietnamTime.DayRangeUtc(date);

        // Gom theo loại ngay trên DB; chỉ vài dòng trả về.
        var groups = await repository.Queryable
            .Where(t => t.OccurredAt >= from && t.OccurredAt < to)
            .GroupBy(t => t.Type)
            .Select(g => new { Type = g.Key, Count = g.Count(), Amount = g.Sum(t => t.Amount), Paid = g.Sum(t => t.PaidAmount) })
            .ToListAsync(cancellationToken);

        long Amount(TransactionType type) => groups.Where(g => g.Type == type).Sum(g => g.Amount);
        long Paid(TransactionType type) => groups.Where(g => g.Type == type).Sum(g => g.Paid);

        var revenue = Amount(TransactionType.Sale);
        var cashSales = Paid(TransactionType.Sale);
        var debtCollected = Amount(TransactionType.DebtPayment);
        var buyPig = Amount(TransactionType.BuyPig);
        var expense = Amount(TransactionType.Expense);
        var cashOut = Amount(TransactionType.CashOut);
        var cashIn = cashSales + debtCollected;

        return new DailyReportDto(
            date, revenue, cashSales, revenue - cashSales, debtCollected, cashIn,
            buyPig, expense, cashOut,
            openingCash + cashIn - buyPig - expense - cashOut,
            groups.Sum(g => g.Count));
    }
}

public sealed record GetDailyReportQuery(DateOnly Date, long OpeningCash = 0) : IRequest<DailyReportDto>;

public sealed record GetDebtsQuery : IRequest<IReadOnlyList<CustomerDebtDto>>;

public sealed record GetCustomerDebtQuery(Guid CustomerId) : IRequest<CustomerDebtDetailDto>;

public sealed record GetMarketCashQuery(long PigCount, long PigPrice, long SupplierDebt = 0, int ReservePercent = 10)
    : IRequest<MarketCashDto>;

public sealed record GetBatchProfitQuery(Guid BatchId) : IRequest<BatchProfitDto>;

public sealed class GetDailyReportQueryValidator : AbstractValidator<GetDailyReportQuery>
{
    public GetDailyReportQueryValidator() =>
        RuleFor(x => x.Date).NotEqual(default(DateOnly)).WithMessage("Ngày báo cáo không hợp lệ.");
}

public sealed class GetMarketCashQueryValidator : AbstractValidator<GetMarketCashQuery>
{
    public GetMarketCashQueryValidator()
    {
        RuleFor(x => x.PigCount).GreaterThanOrEqualTo(0).WithMessage("Số con không được âm.");
        RuleFor(x => x.PigPrice).GreaterThanOrEqualTo(0).WithMessage("Giá lợn không được âm.");
        RuleFor(x => x.SupplierDebt).GreaterThanOrEqualTo(0).WithMessage("Nợ mối không được âm.");
        RuleFor(x => x.ReservePercent).InclusiveBetween(0, 100).WithMessage("Tỷ lệ dự phòng phải từ 0 đến 100.");
    }
}

public sealed class GetDailyReportQueryHandler(IReadOnlyRepository<Transaction, Guid> transactions)
    : IRequestHandler<GetDailyReportQuery, DailyReportDto>
{
    public Task<DailyReportDto> Handle(GetDailyReportQuery request, CancellationToken cancellationToken) =>
        DailyReportCalculator.ComputeAsync(transactions, request.Date, request.OpeningCash, cancellationToken);
}

public sealed class GetDebtsQueryHandler(
    IReadOnlyRepository<Transaction, Guid> transactions,
    IReadOnlyRepository<Customer, Guid> customers) : IRequestHandler<GetDebtsQuery, IReadOnlyList<CustomerDebtDto>>
{
    public async Task<IReadOnlyList<CustomerDebtDto>> Handle(GetDebtsQuery request, CancellationToken cancellationToken)
    {
        var groups = await transactions.Queryable
            .Where(t => t.CustomerId != null && (t.Type == TransactionType.Sale || t.Type == TransactionType.DebtPayment))
            .GroupBy(t => new { t.CustomerId, t.Type })
            .Select(g => new { CustomerId = g.Key.CustomerId!.Value, g.Key.Type, Amount = g.Sum(t => t.Amount), Paid = g.Sum(t => t.PaidAmount) })
            .ToListAsync(cancellationToken);

        var rows = groups
            .GroupBy(g => g.CustomerId)
            .Select(g => new
            {
                CustomerId = g.Key,
                TotalSale = g.Where(x => x.Type == TransactionType.Sale).Sum(x => x.Amount),
                TotalPaid = g.Where(x => x.Type == TransactionType.Sale).Sum(x => x.Paid),
                TotalDebtPayment = g.Where(x => x.Type == TransactionType.DebtPayment).Sum(x => x.Amount),
            })
            .Select(x => new { x.CustomerId, x.TotalSale, x.TotalPaid, x.TotalDebtPayment, Debt = x.TotalSale - x.TotalPaid - x.TotalDebtPayment })
            .Where(x => x.Debt != 0)
            .ToList();

        var ids = rows.Select(r => r.CustomerId).ToList();
        // Khách đã xóa mềm vẫn có thể còn nợ: tra tên bỏ qua bộ lọc xóa mềm.
        var names = await customers.Queryable.IgnoreQueryFilters()
            .Where(c => ids.Contains(c.Id))
            .Select(c => new { c.Id, c.Name })
            .ToDictionaryAsync(c => c.Id, c => c.Name, cancellationToken);

        return rows
            .Select(r => new CustomerDebtDto(
                r.CustomerId, names.GetValueOrDefault(r.CustomerId, string.Empty),
                r.TotalSale, r.TotalPaid, r.TotalDebtPayment, r.Debt))
            .OrderByDescending(r => r.Debt)
            .ThenBy(r => r.CustomerName)
            .ToList();
    }
}

public sealed class GetCustomerDebtQueryHandler(
    IReadOnlyRepository<Transaction, Guid> transactions,
    IReadOnlyRepository<Customer, Guid> customers) : IRequestHandler<GetCustomerDebtQuery, CustomerDebtDetailDto>
{
    public async Task<CustomerDebtDetailDto> Handle(GetCustomerDebtQuery request, CancellationToken cancellationToken)
    {
        var customer = await customers.Queryable.IgnoreQueryFilters()
                           .FirstOrDefaultAsync(c => c.Id == request.CustomerId, cancellationToken)
                       ?? throw new NotFoundException("Khách hàng", request.CustomerId);

        var rows = await transactions.Queryable
            .Where(t => t.CustomerId == request.CustomerId
                        && (t.Type == TransactionType.Sale || t.Type == TransactionType.DebtPayment))
            .OrderBy(t => t.OccurredAt).ThenBy(t => t.Id)
            .ToListAsync(cancellationToken);

        var items = rows.Select(t => new DebtItemDto(
                t.Id, t.OccurredAt.AsUtc(), t.Type.ToString(), t.Amount, t.PaidAmount,
                t.Type == TransactionType.Sale ? t.Amount - t.PaidAmount : -t.Amount))
            .ToList();

        return new CustomerDebtDetailDto(customer.Id, customer.Name, items.Sum(i => i.DebtDelta), items);
    }
}

public sealed class GetMarketCashQueryHandler : IRequestHandler<GetMarketCashQuery, MarketCashDto>
{
    public Task<MarketCashDto> Handle(GetMarketCashQuery request, CancellationToken cancellationToken)
    {
        var pigCost = request.PigCount * request.PigPrice;
        var reserve = (long)Math.Round(pigCost * (decimal)request.ReservePercent / 100m, MidpointRounding.AwayFromZero);
        return Task.FromResult(new MarketCashDto(pigCost, request.SupplierDebt, reserve, pigCost + request.SupplierDebt + reserve));
    }
}

public sealed class GetBatchProfitQueryHandler(
    IReadOnlyRepository<Transaction, Guid> transactions,
    IReadOnlyRepository<Batch, Guid> batches) : IRequestHandler<GetBatchProfitQuery, BatchProfitDto>
{
    public async Task<BatchProfitDto> Handle(GetBatchProfitQuery request, CancellationToken cancellationToken)
    {
        var batch = await batches.Queryable.FirstOrDefaultAsync(b => b.Id == request.BatchId, cancellationToken)
                    ?? throw new NotFoundException("Lô hàng", request.BatchId);

        var revenue = await transactions.Queryable
            .Where(t => t.BatchId == request.BatchId && t.Type == TransactionType.Sale)
            .SumAsync(t => (long?)t.Amount, cancellationToken) ?? 0;

        return new BatchProfitDto(batch.Id, revenue, batch.BuyCost, batch.OtherCost, revenue - batch.BuyCost - batch.OtherCost);
    }
}
