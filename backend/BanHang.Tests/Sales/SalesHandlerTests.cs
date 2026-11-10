using BanHang.Application.Batches;
using BanHang.Application.DaySettlements;
using BanHang.Application.Products;
using BanHang.Application.Transactions;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Batches;
using BanHang.Domain.Entities.DaySettlements;
using BanHang.Domain.Entities.Products;
using BanHang.Domain.Entities.Transactions;
using BanHang.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Tests.Sales;

public class SalesHandlerTests
{
    private readonly TestDb _db = new();

    private UpsertProductCommandHandler UpsertProduct() => new(_db.Repository<Product, Guid>(), _db.Clock);
    private DeleteProductCommandHandler DeleteProduct() => new(_db.Repository<Product, Guid>(), _db.Clock);
    private GetProductsQueryHandler ListProducts() => new(_db.Repository<Product, Guid>());
    private UpsertBatchCommandHandler UpsertBatch() => new(_db.Repository<Batch, Guid>(), _db.Clock);
    private UpsertTransactionCommandHandler UpsertTx() => new(_db.Repository<Transaction, Guid>(), _db.Clock);
    private DeleteTransactionCommandHandler DeleteTx() => new(_db.Repository<Transaction, Guid>(), _db.Clock);
    private GetTransactionsQueryHandler ListTx() => new(_db.Repository<Transaction, Guid>());

    private UpsertDaySettlementCommandHandler UpsertSettlement() =>
        new(_db.Repository<DaySettlement, Guid>(), _db.Repository<Transaction, Guid>(), _db.Clock);

    private static UpsertTransactionCommand Sale(Guid id, long amount, long paid, Guid? customer = null, DateTime? at = null) =>
        new(id, at ?? new DateTime(2026, 1, 1, 3, 0, 0, DateTimeKind.Utc), "Sale", customer, Amount: amount, PaidAmount: paid);

    // ---------- Product ----------

    [Fact]
    public async Task Product_Upsert_IsIdempotent_AndKeepsUpdatedAtWhenUnchanged()
    {
        var cmd = new UpsertProductCommand(Guid.NewGuid(), "  Ba chỉ ", "ba rọi", 130_000);

        var first = await UpsertProduct().Handle(cmd, default);
        _db.Clock.Advance(TimeSpan.FromMinutes(5));
        var second = await UpsertProduct().Handle(cmd, default);

        Assert.Equal("Ba chỉ", first.Name);
        Assert.Equal(first.UpdatedAt, second.UpdatedAt);
        Assert.Equal(DateTimeKind.Utc, second.UpdatedAt.Kind);
        Assert.Equal(1, await _db.NewContext().Set<Product>().CountAsync());
    }

    [Fact]
    public async Task Product_Update_ChangesPriceAndBumpsUpdatedAt()
    {
        var id = Guid.NewGuid();
        var created = await UpsertProduct().Handle(new UpsertProductCommand(id, "Sườn", null, 150_000), default);
        _db.Clock.Advance(TimeSpan.FromMinutes(5));

        var updated = await UpsertProduct().Handle(new UpsertProductCommand(id, "Sườn", null, 160_000), default);

        Assert.Equal(160_000, updated.PricePerKg);
        Assert.True(updated.UpdatedAt > created.UpdatedAt);
    }

    [Fact]
    public async Task Product_DeleteIsIdempotent_UpsertDoesNotResurrect_ListHidesButSyncShows()
    {
        var id = Guid.NewGuid();
        await UpsertProduct().Handle(new UpsertProductCommand(id, "Xương", null, 50_000), default);
        await DeleteProduct().Handle(new DeleteProductCommand(id), default);
        await DeleteProduct().Handle(new DeleteProductCommand(id), default);
        await DeleteProduct().Handle(new DeleteProductCommand(Guid.NewGuid()), default);

        var result = await UpsertProduct().Handle(new UpsertProductCommand(id, "Tên khác", null, 1), default);

        Assert.True(result.IsDeleted);
        Assert.Empty((await ListProducts().Handle(new GetProductsQuery(), default)).Items);
        var all = await ListProducts().Handle(new GetProductsQuery { IncludeDeleted = true }, default);
        Assert.True(Assert.Single(all.Items).IsDeleted);
    }

    // ---------- Batch ----------

    [Fact]
    public async Task Batch_Upsert_CreatesThenUpdates()
    {
        var id = Guid.NewGuid();
        var date = new DateOnly(2026, 3, 5);
        var created = await UpsertBatch().Handle(new UpsertBatchCommand(id, date, 2, 180_000, 140_000, 9_000_000, 300_000), default);
        _db.Clock.Advance(TimeSpan.FromMinutes(1));
        var updated = await UpsertBatch().Handle(new UpsertBatchCommand(id, date, 2, 180_000, 140_000, 9_000_000, 350_000, "thêm đá"), default);

        Assert.Equal(date, created.Date);
        Assert.Equal(350_000, updated.OtherCost);
        Assert.Equal("thêm đá", updated.Note);
        Assert.Equal(1, await _db.NewContext().Set<Batch>().CountAsync());
    }

    // ---------- Transaction ----------

    [Fact]
    public async Task Transaction_Sale_Upsert_IsIdempotent()
    {
        var cmd = Sale(Guid.NewGuid(), 500_000, 200_000, Guid.NewGuid());

        var first = await UpsertTx().Handle(cmd, default);
        _db.Clock.Advance(TimeSpan.FromMinutes(5));
        var second = await UpsertTx().Handle(cmd, default);

        Assert.Equal("Sale", first.Type);
        Assert.Equal(first.UpdatedAt, second.UpdatedAt);
        Assert.Equal(1, await _db.NewContext().Set<Transaction>().CountAsync());
    }

    [Fact]
    public async Task Transaction_NonSale_ForcesPaidEqualsAmount()
    {
        var dto = await UpsertTx().Handle(
            new UpsertTransactionCommand(Guid.NewGuid(), DateTime.UtcNow, "Expense", Amount: 70_000, PaidAmount: 0), default);

        Assert.Equal(70_000, dto.PaidAmount);
    }

    [Fact]
    public async Task Transaction_DeleteThenUpsert_DoesNotResurrect()
    {
        var id = Guid.NewGuid();
        await UpsertTx().Handle(Sale(id, 100_000, 100_000), default);
        await DeleteTx().Handle(new DeleteTransactionCommand(id), default);
        await DeleteTx().Handle(new DeleteTransactionCommand(id), default);

        var result = await UpsertTx().Handle(Sale(id, 999, 999), default);

        Assert.True(result.IsDeleted);
        Assert.Empty((await ListTx().Handle(new GetTransactionsQuery(), default)).Items);
    }

    [Fact]
    public async Task Transaction_List_FiltersByCustomerTypeAndRange_AndSyncsInOrder()
    {
        var anna = Guid.NewGuid();
        var day1 = new DateTime(2026, 1, 1, 3, 0, 0, DateTimeKind.Utc);
        var day2 = day1.AddDays(1);
        await UpsertTx().Handle(Sale(Guid.NewGuid(), 100, 100, anna, day1), default);
        _db.Clock.Advance(TimeSpan.FromMinutes(10));
        await UpsertTx().Handle(Sale(Guid.NewGuid(), 200, 200, null, day2), default);
        await UpsertTx().Handle(
            new UpsertTransactionCommand(Guid.NewGuid(), day2, "DebtPayment", anna, Amount: 50), default);

        var byCustomer = await ListTx().Handle(new GetTransactionsQuery { CustomerId = anna }, default);
        var byType = await ListTx().Handle(new GetTransactionsQuery { Type = "DebtPayment" }, default);
        var byRange = await ListTx().Handle(new GetTransactionsQuery { From = day2, To = day2.AddDays(1) }, default);
        var since = await ListTx().Handle(
            new GetTransactionsQuery { UpdatedSince = new DateTime(2026, 1, 1, 0, 5, 0, DateTimeKind.Utc) }, default);

        Assert.Equal(2, byCustomer.Items.Count);
        Assert.Single(byType.Items);
        Assert.Equal(2, byRange.Items.Count);
        Assert.Equal(2, since.Items.Count);
        Assert.True(since.Items.First().UpdatedAt <= since.Items.Last().UpdatedAt);
    }

    // ---------- DaySettlement ----------

    [Fact]
    public async Task Settlement_ComputesExpectedCashAndDifference_UsingVietnamDay()
    {
        // 2026-01-01 giờ VN = [2025-12-31T17:00Z, 2026-01-01T17:00Z). 16:59Z vẫn thuộc ngày 1/1; 17:00Z là ngày 2/1.
        await UpsertTx().Handle(Sale(Guid.NewGuid(), 1_000_000, 600_000, Guid.NewGuid(), new DateTime(2025, 12, 31, 17, 0, 0, DateTimeKind.Utc)), default);
        await UpsertTx().Handle(Sale(Guid.NewGuid(), 777, 777, null, new DateTime(2026, 1, 1, 17, 0, 0, DateTimeKind.Utc)), default);
        await UpsertTx().Handle(new UpsertTransactionCommand(Guid.NewGuid(), new DateTime(2026, 1, 1, 2, 0, 0, DateTimeKind.Utc), "BuyPig", Amount: 400_000), default);

        var dto = await UpsertSettlement().Handle(
            new UpsertDaySettlementCommand(Guid.NewGuid(), new DateOnly(2026, 1, 1), 1_000_000, 1_150_000, "ok"), default);

        // 1.000.000 đầu ngày + 600.000 thu tiền mặt − 400.000 mua lợn = 1.200.000
        Assert.Equal(1_200_000, dto.ExpectedCash);
        Assert.Equal(-50_000, dto.Difference);
    }

    [Fact]
    public async Task Settlement_SameDateDifferentId_Conflicts_ButSameIdIsIdempotent()
    {
        var id = Guid.NewGuid();
        var date = new DateOnly(2026, 2, 2);
        var cmd = new UpsertDaySettlementCommand(id, date, 0, 0);

        var first = await UpsertSettlement().Handle(cmd, default);
        _db.Clock.Advance(TimeSpan.FromMinutes(5));
        var second = await UpsertSettlement().Handle(cmd, default);
        var ex = await Assert.ThrowsAsync<CustomException>(() =>
            UpsertSettlement().Handle(cmd with { Id = Guid.NewGuid() }, default));

        Assert.Equal(first.UpdatedAt, second.UpdatedAt);
        Assert.Equal(System.Net.HttpStatusCode.Conflict, ex.StatusCode);
    }

    [Fact]
    public async Task Settlement_AfterDelete_AllowsNewRecordForSameDate()
    {
        var id = Guid.NewGuid();
        var date = new DateOnly(2026, 2, 3);
        await UpsertSettlement().Handle(new UpsertDaySettlementCommand(id, date), default);
        await new DeleteDaySettlementCommandHandler(_db.Repository<DaySettlement, Guid>(), _db.Clock)
            .Handle(new DeleteDaySettlementCommand(id), default);

        var again = await UpsertSettlement().Handle(new UpsertDaySettlementCommand(Guid.NewGuid(), date), default);

        Assert.False(again.IsDeleted);
    }
}
