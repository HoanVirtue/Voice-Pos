using BanHang.Application.Batches;
using BanHang.Application.Reports;
using BanHang.Application.Transactions;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Batches;
using BanHang.Domain.Entities.Customers;
using BanHang.Domain.Entities.Transactions;
using BanHang.Tests.Support;

namespace BanHang.Tests.Sales;

public class ReportTests
{
    private readonly TestDb _db = new();

    private Task<TransactionDto> Add(
        string type, long amount, long paid = 0, Guid? customer = null, Guid? batch = null, string at = "2026-01-01T03:00:00Z") =>
        new UpsertTransactionCommandHandler(_db.Repository<Transaction, Guid>(), _db.Clock).Handle(
            new UpsertTransactionCommand(
                Guid.NewGuid(), DateTime.Parse(at, null, System.Globalization.DateTimeStyles.AdjustToUniversal), type,
                customer, BatchId: batch, Amount: amount, PaidAmount: paid), default);

    private async Task<Guid> AddCustomer(string name)
    {
        var id = Guid.NewGuid();
        await _db.Repository<Customer, Guid>().InsertAsync(Customer.Create(id, name, null, null, null, _db.Clock.UtcNow));
        return id;
    }

    [Fact]
    public async Task Daily_AggregatesByTypeWithinVietnamDay()
    {
        var c = Guid.NewGuid();
        await Add("Sale", 1_000_000, 600_000, c);            // doanh thu 1tr, thu ngay 600k, nợ mới 400k
        await Add("Sale", 200_000, 200_000);                  // trả ngay
        await Add("DebtPayment", 300_000, customer: c);       // thu nợ cũ
        await Add("BuyPig", 5_000_000);
        await Add("Expense", 100_000);
        await Add("CashOut", 2_000_000);
        await Add("Sale", 999_999, 999_999, at: "2026-01-01T17:00:00Z"); // ngày 2/1 giờ VN: loại ra

        var r = await new GetDailyReportQueryHandler(_db.Repository<Transaction, Guid>())
            .Handle(new GetDailyReportQuery(new DateOnly(2026, 1, 1), 1_000_000), default);

        Assert.Equal(1_200_000, r.Revenue);
        Assert.Equal(800_000, r.CashSales);
        Assert.Equal(400_000, r.NewDebt);
        Assert.Equal(300_000, r.DebtCollected);
        Assert.Equal(1_100_000, r.CashIn);
        Assert.Equal(5_000_000, r.BuyPigCost);
        Assert.Equal(100_000, r.ExpenseCost);
        Assert.Equal(2_000_000, r.CashOut);
        // 1.000.000 + 1.100.000 − 5.000.000 − 100.000 − 2.000.000
        Assert.Equal(-5_000_000, r.CashInHand);
        Assert.Equal(6, r.TransactionCount);
    }

    [Fact]
    public async Task Daily_EmptyDay_IsAllZeroExceptOpeningCash()
    {
        var r = await new GetDailyReportQueryHandler(_db.Repository<Transaction, Guid>())
            .Handle(new GetDailyReportQuery(new DateOnly(2026, 5, 5), 123), default);

        Assert.Equal(0, r.Revenue);
        Assert.Equal(123, r.CashInHand);
        Assert.Equal(0, r.TransactionCount);
    }

    [Fact]
    public async Task Debts_SumPerCustomer_SortedDescending_SkipsSettled()
    {
        var lan = await AddCustomer("Chị Lan");
        var tu = await AddCustomer("Anh Tư");
        var hoa = await AddCustomer("Chị Hoa");
        await Add("Sale", 1_000_000, 400_000, lan);   // nợ 600k
        await Add("DebtPayment", 100_000, customer: lan);   // còn 500k
        await Add("Sale", 800_000, 0, tu);            // nợ 800k
        await Add("Sale", 300_000, 100_000, hoa);     // nợ 200k
        await Add("DebtPayment", 200_000, customer: hoa);   // hết nợ

        var list = await new GetDebtsQueryHandler(_db.Repository<Transaction, Guid>(), _db.Repository<Customer, Guid>())
            .Handle(new GetDebtsQuery(), default);

        Assert.Equal(["Anh Tư", "Chị Lan"], list.Select(x => x.CustomerName));
        Assert.Equal([800_000L, 500_000L], list.Select(x => x.Debt));
        var lanRow = list.Single(x => x.CustomerId == lan);
        Assert.Equal(1_000_000, lanRow.TotalSale);
        Assert.Equal(400_000, lanRow.TotalPaid);
        Assert.Equal(100_000, lanRow.TotalDebtPayment);
    }

    [Fact]
    public async Task CustomerDebt_ListsItemsWithDeltas_AndNotFoundForUnknown()
    {
        var lan = await AddCustomer("Chị Lan");
        await Add("Sale", 1_000_000, 400_000, lan, at: "2026-01-01T03:00:00Z");
        await Add("DebtPayment", 250_000, customer: lan, at: "2026-01-02T03:00:00Z");
        await Add("BuyPig", 999, customer: lan);   // không tính vào công nợ

        var handler = new GetCustomerDebtQueryHandler(_db.Repository<Transaction, Guid>(), _db.Repository<Customer, Guid>());
        var detail = await handler.Handle(new GetCustomerDebtQuery(lan), default);

        Assert.Equal(350_000, detail.Debt);
        Assert.Equal([600_000L, -250_000L], detail.Items.Select(i => i.DebtDelta));
        await Assert.ThrowsAsync<NotFoundException>(() => handler.Handle(new GetCustomerDebtQuery(Guid.NewGuid()), default));
    }

    [Theory]
    [InlineData(3, 4_000_000, 1_000_000, 10, 12_000_000, 1_200_000, 14_200_000)]
    [InlineData(0, 4_000_000, 500_000, 10, 0, 0, 500_000)]
    [InlineData(1, 1_005, 0, 10, 1_005, 101, 1_106)]   // 100,5 làm tròn lên 101
    public async Task MarketCash_Formula(long count, long price, long debt, int pct, long pigCost, long reserve, long total)
    {
        var r = await new GetMarketCashQueryHandler().Handle(new GetMarketCashQuery(count, price, debt, pct), default);

        Assert.Equal(pigCost, r.PigCost);
        Assert.Equal(debt, r.SupplierDebt);
        Assert.Equal(reserve, r.Reserve);
        Assert.Equal(total, r.Total);
    }

    [Fact]
    public async Task BatchProfit_RevenueMinusCosts_OnlySalesOfThatBatch()
    {
        var batchId = Guid.NewGuid();
        await new UpsertBatchCommandHandler(_db.Repository<Batch, Guid>(), _db.Clock)
            .Handle(new UpsertBatchCommand(batchId, new DateOnly(2026, 1, 1), 2, BuyCost: 9_000_000, OtherCost: 300_000), default);
        await Add("Sale", 6_000_000, 6_000_000, batch: batchId);
        await Add("Sale", 4_000_000, 1_000_000, Guid.NewGuid(), batch: batchId);
        await Add("Sale", 777, 777);                                   // lô khác/không lô
        await Add("BuyPig", 9_000_000, batch: batchId);                // không tính vào doanh thu

        var handler = new GetBatchProfitQueryHandler(_db.Repository<Transaction, Guid>(), _db.Repository<Batch, Guid>());
        var r = await handler.Handle(new GetBatchProfitQuery(batchId), default);

        Assert.Equal(10_000_000, r.Revenue);
        Assert.Equal(700_000, r.Profit);
        await Assert.ThrowsAsync<NotFoundException>(() => handler.Handle(new GetBatchProfitQuery(Guid.NewGuid()), default));
    }
}
