namespace BanHang.SharedKernel.Entities;

/// <summary>
/// Entity có thông tin audit + xóa mềm. Tách thành interface để mọi kiểu khóa (long, Guid...) đều được
/// <c>AppDbContextBase</c> tự gắn query filter IsDeleted và điền CreatedAt/ModifiedAt.
/// </summary>
public interface IAuditable
{
    DateTime CreatedAt { get; set; }
    string? CreatedBy { get; set; }
    DateTime? ModifiedAt { get; set; }
    string? ModifiedBy { get; set; }
    bool IsDeleted { get; set; }
}
