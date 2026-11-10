namespace BanHang.SharedKernel.Entities;

/// <summary>
/// Entity có dấu phiên bản để chống ghi đè đồng thời (optimistic concurrency). Giá trị do DbContext cấp lại
/// mỗi lần lưu; câu UPDATE kèm điều kiện dấu cũ nên người lưu sau bị <c>DbUpdateConcurrencyException</c>
/// thay vì âm thầm ghi đè hoặc xử lý trùng.
/// </summary>
public interface IHasConcurrencyStamp
{
    string ConcurrencyStamp { get; set; }
}
