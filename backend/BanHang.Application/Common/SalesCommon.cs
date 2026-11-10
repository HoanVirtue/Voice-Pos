using BanHang.Application.Common.Requests;
using FluentValidation;

namespace BanHang.Application.Common;

/// <summary>Truy vấn danh sách có hỗ trợ đồng bộ: chỉ lấy bản ghi đổi sau mốc (UTC), kèm bản đã xóa mềm.</summary>
public abstract class SyncQueryRequestBase : QueryRequestBase
{
    public DateTime? UpdatedSince { get; set; }

    public bool IncludeDeleted { get; set; }
}

/// <summary>Kiểm tra phân trang dùng chung cho mọi truy vấn danh sách.</summary>
public abstract class PagedQueryValidator<T> : AbstractValidator<T> where T : QueryRequestBase
{
    protected PagedQueryValidator()
    {
        RuleFor(x => x.PageIndex).GreaterThanOrEqualTo(1).WithMessage("Số trang phải từ 1 trở lên.");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 500).WithMessage("Số dòng mỗi trang phải từ 1 đến 500.");
    }
}

public static class UtcExtensions
{
    /// <summary>Chuẩn hóa về UTC: Unspecified (đọc từ MySQL) coi là UTC, Local đổi sang UTC.</summary>
    public static DateTime AsUtc(this DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
    };
}

/// <summary>Giờ Việt Nam cố định UTC+7 (không có giờ mùa hè) — tránh phụ thuộc id múi giờ khác nhau giữa Windows/Linux.</summary>
public static class VietnamTime
{
    public static readonly TimeSpan Offset = TimeSpan.FromHours(7);

    /// <summary>[00:00, 24:00) giờ VN của <paramref name="date"/> đổi sang khoảng UTC [from, to).</summary>
    public static (DateTime FromUtc, DateTime ToUtc) DayRangeUtc(DateOnly date)
    {
        var from = DateTime.SpecifyKind(date.ToDateTime(TimeOnly.MinValue) - Offset, DateTimeKind.Utc);
        return (from, from.AddDays(1));
    }
}
