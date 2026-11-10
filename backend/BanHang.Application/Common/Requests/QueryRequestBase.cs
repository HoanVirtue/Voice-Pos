namespace BanHang.Application.Common.Requests;

/// <summary>Tham số truy vấn danh sách dùng chung: phân trang + từ khóa. Request con thêm bộ lọc riêng.</summary>
public abstract class QueryRequestBase
{
    public int PageIndex { get; set; } = 1;

    public int PageSize { get; set; } = 20;

    public string? Keyword { get; set; }
}
