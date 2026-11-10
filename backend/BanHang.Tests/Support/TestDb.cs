using BanHang.BuildingBlocks.Time;
using BanHang.BuildingBlocks.Web;
using BanHang.Infrastructure.Persistence;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Tests.Support;

/// <summary>
/// DB in-memory dùng chung cho các test handler. Mỗi lần gọi <see cref="NewContext"/> tạo một DbContext mới trên CÙNG dữ liệu,
/// mô phỏng mỗi request HTTP một context riêng.
/// </summary>
public sealed class TestDb
{
    private readonly DbContextOptions<BanHangDbContext> _options =
        new DbContextOptionsBuilder<BanHangDbContext>()
            .UseInMemoryDatabase($"banhang-tests-{Guid.NewGuid()}")
            .Options;

    public FakeClock Clock { get; } = new();

    public BanHangDbContext NewContext() =>
        new(_options, new FakeCurrentUser(), Clock, new NullPublisher());

    public EfCoreRepository<TEntity, TKey> Repository<TEntity, TKey>(BanHangDbContext? context = null)
        where TEntity : BanHang.SharedKernel.Entities.BaseEntity<TKey> =>
        new(context ?? NewContext());
}

/// <summary>Đồng hồ giả: mỗi lần <see cref="Advance"/> nhích thời gian tiến lên để kiểm tra UpdatedAt.</summary>
public sealed class FakeClock : IDateTimeProvider
{
    public DateTime UtcNow { get; private set; } = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    public DateTime Now => UtcNow.AddHours(7);

    public void Advance(TimeSpan by) => UtcNow = UtcNow.Add(by);
}

public sealed class FakeCurrentUser : ICurrentUser
{
    public string? UserId => "1";
    public string? UserName => "test";
    public bool IsAuthenticated => true;
}

public sealed class NullPublisher : IPublisher
{
    public Task Publish(object notification, CancellationToken cancellationToken = default) => Task.CompletedTask;

    public Task Publish<TNotification>(TNotification notification, CancellationToken cancellationToken = default)
        where TNotification : INotification => Task.CompletedTask;
}
