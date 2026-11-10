using BanHang.Application.Batches;
using BanHang.Application.DaySettlements;
using BanHang.Application.Products;
using BanHang.Application.Reports;
using BanHang.Application.Transactions;

namespace BanHang.Tests.Sales;

public class SalesValidatorTests
{
    private static readonly DateTime At = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private static UpsertTransactionCommand Tx(
        string type = "Sale", long amount = 100, long paid = 100, Guid? customer = null, double? confidence = null) =>
        new(Guid.NewGuid(), At, type, customer, Amount: amount, PaidAmount: paid, Confidence: confidence);

    [Fact]
    public void Product_Valid_Passes_And_Invalid_Fails_WithVietnameseMessages()
    {
        var v = new UpsertProductCommandValidator();

        Assert.True(v.Validate(new UpsertProductCommand(Guid.NewGuid(), "Ba chỉ", null, 130_000)).IsValid);

        var messages = v.Validate(new UpsertProductCommand(Guid.Empty, " ", null, -1)).Errors.Select(e => e.ErrorMessage).ToList();
        Assert.Contains("Mã món hàng không hợp lệ.", messages);
        Assert.Contains("Tên món hàng không được để trống.", messages);
        Assert.Contains("Giá mỗi kg không được âm.", messages);
    }

    [Fact]
    public void Batch_NegativeValues_Fail()
    {
        var v = new UpsertBatchCommandValidator();

        Assert.True(v.Validate(new UpsertBatchCommand(Guid.NewGuid(), new DateOnly(2026, 1, 1), 2, 1, 1, 10, 5)).IsValid);
        Assert.False(v.Validate(new UpsertBatchCommand(Guid.NewGuid(), new DateOnly(2026, 1, 1), -1)).IsValid);
        Assert.False(v.Validate(new UpsertBatchCommand(Guid.NewGuid(), new DateOnly(2026, 1, 1), BuyCost: -1)).IsValid);
        Assert.False(v.Validate(new UpsertBatchCommand(Guid.NewGuid(), default)).IsValid);
    }

    [Theory]
    [InlineData("Sale", true)]
    [InlineData("DebtPayment", true)]
    [InlineData("BuyPig", true)]
    [InlineData("Expense", true)]
    [InlineData("CashOut", true)]
    [InlineData("sale", false)]
    [InlineData("3", false)]
    [InlineData("", false)]
    [InlineData("Refund", false)]
    public void Transaction_Type_MustBeKnownName(string type, bool valid)
    {
        var cust = Guid.NewGuid();
        var result = new UpsertTransactionCommandValidator().Validate(Tx(type, customer: cust));

        Assert.Equal(valid, result.IsValid);
    }

    [Fact]
    public void Transaction_Sale_PaidCannotExceedAmount_AndDebtNeedsCustomer()
    {
        var v = new UpsertTransactionCommandValidator();

        Assert.True(v.Validate(Tx(amount: 100, paid: 100)).IsValid);                          // trả đủ, không cần khách
        Assert.False(v.Validate(Tx(amount: 100, paid: 150)).IsValid);                         // trả quá
        Assert.False(v.Validate(Tx(amount: 100, paid: 40)).IsValid);                          // nợ nhưng không có khách
        Assert.True(v.Validate(Tx(amount: 100, paid: 40, customer: Guid.NewGuid())).IsValid); // nợ có khách
    }

    [Fact]
    public void Transaction_DebtPayment_NeedsCustomer_AndConfidenceInRange()
    {
        var v = new UpsertTransactionCommandValidator();

        Assert.False(v.Validate(Tx("DebtPayment")).IsValid);
        Assert.True(v.Validate(Tx("DebtPayment", customer: Guid.NewGuid())).IsValid);
        Assert.False(v.Validate(Tx("Expense", confidence: 1.5)).IsValid);
        Assert.True(v.Validate(Tx("Expense", confidence: 0.8)).IsValid);
        Assert.False(v.Validate(Tx("Expense", amount: -1)).IsValid);
    }

    [Fact]
    public void Transaction_ListQuery_RejectsUnknownType_AndBadPaging()
    {
        var v = new GetTransactionsQueryValidator();

        Assert.True(v.Validate(new GetTransactionsQuery { Type = "Sale" }).IsValid);
        Assert.False(v.Validate(new GetTransactionsQuery { Type = "X" }).IsValid);
        Assert.False(v.Validate(new GetTransactionsQuery { PageSize = 0 }).IsValid);
    }

    [Fact]
    public void Settlement_And_MarketCash_Validate()
    {
        Assert.True(new UpsertDaySettlementCommandValidator()
            .Validate(new UpsertDaySettlementCommand(Guid.NewGuid(), new DateOnly(2026, 1, 1), 0, 10)).IsValid);
        Assert.False(new UpsertDaySettlementCommandValidator()
            .Validate(new UpsertDaySettlementCommand(Guid.NewGuid(), new DateOnly(2026, 1, 1), 0, -10)).IsValid);

        var m = new GetMarketCashQueryValidator();
        Assert.True(m.Validate(new GetMarketCashQuery(2, 100)).IsValid);
        Assert.False(m.Validate(new GetMarketCashQuery(2, 100, ReservePercent: 101)).IsValid);
        Assert.False(m.Validate(new GetMarketCashQuery(-1, 100)).IsValid);
    }
}
