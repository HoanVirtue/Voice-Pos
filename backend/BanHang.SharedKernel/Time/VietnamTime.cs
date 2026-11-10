namespace BanHang.SharedKernel.Time;

/// <summary>
/// Giờ hiện tại theo múi giờ Việt Nam (UTC+7), KHÔNG phụ thuộc múi giờ của máy chủ/container.
///
/// Dữ liệu chấm công (PunchTime) được lưu theo giờ đồng hồ Việt Nam. Nếu container chạy ở UTC
/// (mặc định của image dotnet trên Linux), <see cref="System.DateTime.Now"/> sẽ trả về giờ UTC — chậm 7 tiếng —
/// khiến các so sánh "thời điểm hiện tại" (realtime cutoff) loại nhầm lượt quẹt trong ngày.
/// Dùng lớp này cho mọi so sánh/ghi nhận "hiện tại" trong nghiệp vụ để luôn đúng giờ Việt Nam.
///
/// Đặt ở SharedKernel (project nền được mọi tầng ref) để Domain, BuildingBlocks, Application dùng chung.
/// </summary>
public static class VietnamTime
{
    private static readonly TimeZoneInfo Tz = ResolveTimeZone();

    /// <summary>Múi giờ Việt Nam, dùng cho các bộ lập lịch cần khai báo múi giờ tường minh.</summary>
    public static TimeZoneInfo TimeZone => Tz;

    /// <summary>Thời điểm hiện tại theo giờ Việt Nam.</summary>
    public static DateTime Now => TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, Tz).DateTime;

    /// <summary>Ngày hiện tại theo giờ Việt Nam.</summary>
    public static DateOnly Today => DateOnly.FromDateTime(Now);

    /// <summary>Giờ trong ngày hiện tại theo giờ Việt Nam.</summary>
    public static TimeOnly TimeNow => TimeOnly.FromDateTime(Now);

    private static TimeZoneInfo ResolveTimeZone()
    {
        // IANA trên Linux/macOS, Windows id trên Windows — thử lần lượt.
        foreach (var id in new[] { "Asia/Ho_Chi_Minh", "SE Asia Standard Time" })
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); }
            catch (TimeZoneNotFoundException) { }
            catch (InvalidTimeZoneException) { }
        }

        // Nếu hệ điều hành thiếu dữ liệu tz: dùng offset cố định UTC+7 (Việt Nam không có DST).
        return TimeZoneInfo.CreateCustomTimeZone("VN+7", TimeSpan.FromHours(7), "Vietnam (UTC+7)", "Vietnam (UTC+7)");
    }
}
