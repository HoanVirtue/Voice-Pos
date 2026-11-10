using BanHang.SharedKernel.Time;

namespace BanHang.BuildingBlocks.Time;

public interface IDateTimeProvider
{
    DateTime Now { get; }
    DateTime UtcNow { get; }
}

public sealed class DateTimeProvider : IDateTimeProvider
{
    // Giờ Việt Nam (UTC+7) độc lập múi giờ máy chủ — dùng cho audit CreatedAt/ModifiedAt.
    public DateTime Now => VietnamTime.Now;
    public DateTime UtcNow => DateTime.UtcNow;
}
