using BanHang.Application.Customers.Commands;
using BanHang.Application.Customers.Queries;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Customers;
using BanHang.Tests.Support;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Tests.Customers;

public class CustomerHandlerTests
{
    private readonly TestDb _db = new();

    private UpsertCustomerCommandHandler UpsertHandler() =>
        new(_db.Repository<Customer, Guid>(), _db.Clock);

    private DeleteCustomerCommandHandler DeleteHandler() =>
        new(_db.Repository<Customer, Guid>(), _db.Clock);

    private GetCustomersQueryHandler ListHandler() =>
        new(_db.Repository<Customer, Guid>());

    [Fact]
    public async Task Upsert_NewId_CreatesCustomer()
    {
        var id = Guid.NewGuid();

        var dto = await UpsertHandler().Handle(
            new UpsertCustomerCommand(id, "  Chị Hoa  ", "Hoa chợ", "0901 234 567", null), default);

        Assert.Equal(id, dto.Id);
        Assert.Equal("Chị Hoa", dto.Name);
        Assert.Equal("Hoa chợ", dto.Alias);
        Assert.Equal(DateTimeKind.Utc, dto.UpdatedAt.Kind);
        Assert.False(dto.IsDeleted);
        Assert.Equal(1, await _db.NewContext().Set<Customer>().CountAsync());
    }

    [Fact]
    public async Task Upsert_SameCommandTwice_IsIdempotent()
    {
        var command = new UpsertCustomerCommand(Guid.NewGuid(), "Anh Tư", null, "0912345678", "khách quen");

        var first = await UpsertHandler().Handle(command, default);
        _db.Clock.Advance(TimeSpan.FromMinutes(5));
        var second = await UpsertHandler().Handle(command, default);

        Assert.Equal(1, await _db.NewContext().Set<Customer>().CountAsync());
        // Không có gì đổi thì mốc đồng bộ phải giữ nguyên, tránh phát sinh thay đổi giả.
        Assert.Equal(first.UpdatedAt, second.UpdatedAt);
    }

    [Fact]
    public async Task Upsert_ExistingId_UpdatesFieldsAndBumpsUpdatedAt()
    {
        var id = Guid.NewGuid();
        var created = await UpsertHandler().Handle(new UpsertCustomerCommand(id, "Anh Tư"), default);

        _db.Clock.Advance(TimeSpan.FromMinutes(5));
        var updated = await UpsertHandler().Handle(new UpsertCustomerCommand(id, "Anh Tư", Phone: "0988000111"), default);

        Assert.Equal("0988000111", updated.Phone);
        Assert.True(updated.UpdatedAt > created.UpdatedAt);
        Assert.Equal(1, await _db.NewContext().Set<Customer>().CountAsync());
    }

    [Fact]
    public async Task Delete_SoftDeletes_AndIsIdempotent()
    {
        var id = Guid.NewGuid();
        await UpsertHandler().Handle(new UpsertCustomerCommand(id, "Chị Lan"), default);

        await DeleteHandler().Handle(new DeleteCustomerCommand(id), default);
        await DeleteHandler().Handle(new DeleteCustomerCommand(id), default);
        await DeleteHandler().Handle(new DeleteCustomerCommand(Guid.NewGuid()), default); // không tồn tại: không lỗi

        var visible = await ListHandler().Handle(new GetCustomersQuery(), default);
        var all = await ListHandler().Handle(new GetCustomersQuery { IncludeDeleted = true }, default);

        Assert.Empty(visible.Items);
        var row = Assert.Single(all.Items);
        Assert.True(row.IsDeleted);
    }

    [Fact]
    public async Task Upsert_OnDeletedCustomer_DoesNotResurrect()
    {
        var id = Guid.NewGuid();
        await UpsertHandler().Handle(new UpsertCustomerCommand(id, "Chị Lan"), default);
        await DeleteHandler().Handle(new DeleteCustomerCommand(id), default);

        var result = await UpsertHandler().Handle(new UpsertCustomerCommand(id, "Tên mới"), default);

        Assert.True(result.IsDeleted);
        Assert.Empty((await ListHandler().Handle(new GetCustomersQuery(), default)).Items);
    }

    [Fact]
    public async Task List_UpdatedSince_ReturnsOnlyNewerChangesInOrder()
    {
        var a = Guid.NewGuid();
        var b = Guid.NewGuid();
        var c = Guid.NewGuid();
        await UpsertHandler().Handle(new UpsertCustomerCommand(a, "A"), default);
        _db.Clock.Advance(TimeSpan.FromMinutes(10));
        var since = _db.Clock.UtcNow;
        _db.Clock.Advance(TimeSpan.FromMinutes(1));
        await UpsertHandler().Handle(new UpsertCustomerCommand(b, "B"), default);
        _db.Clock.Advance(TimeSpan.FromMinutes(1));
        await UpsertHandler().Handle(new UpsertCustomerCommand(c, "C"), default);
        _db.Clock.Advance(TimeSpan.FromMinutes(1));
        await DeleteHandler().Handle(new DeleteCustomerCommand(b), default);

        var result = await ListHandler().Handle(
            new GetCustomersQuery { UpdatedSince = since, IncludeDeleted = true }, default);

        // c đổi lúc +2, b bị xóa lúc +3 → thứ tự theo UpdatedAt tăng dần: c rồi b; a (cũ hơn mốc) không có.
        Assert.Equal(new[] { c, b }, result.Items.Select(x => x.Id).ToArray());
        Assert.True(result.Items.Last().IsDeleted);
    }

    [Fact]
    public async Task List_PagingAndKeyword_Work()
    {
        for (var i = 1; i <= 5; i++)
        {
            await UpsertHandler().Handle(new UpsertCustomerCommand(Guid.NewGuid(), $"Khách {i}", Phone: $"090000000{i}"), default);
        }

        var page2 = await ListHandler().Handle(new GetCustomersQuery { PageIndex = 2, PageSize = 2 }, default);
        var byPhone = await ListHandler().Handle(new GetCustomersQuery { Keyword = "0900000003" }, default);

        Assert.Equal(5, page2.TotalItems);
        Assert.Equal(3, page2.TotalPages);
        Assert.Equal(2, page2.Items.Count);
        Assert.Equal("Khách 3", Assert.Single(byPhone.Items).Name);
    }

    [Fact]
    public async Task GetById_DeletedOrMissing_ThrowsNotFound()
    {
        var id = Guid.NewGuid();
        await UpsertHandler().Handle(new UpsertCustomerCommand(id, "Chị Lan"), default);
        await DeleteHandler().Handle(new DeleteCustomerCommand(id), default);

        var handler = new GetCustomerByIdQueryHandler(_db.Repository<Customer, Guid>());

        await Assert.ThrowsAsync<NotFoundException>(() => handler.Handle(new GetCustomerByIdQuery(id), default));
        await Assert.ThrowsAsync<NotFoundException>(() => handler.Handle(new GetCustomerByIdQuery(Guid.NewGuid()), default));
    }
}
