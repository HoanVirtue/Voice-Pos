using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Customers;

/// <summary>
/// Khách hàng. Id là Guid do CLIENT sinh (UUID) để app tạo offline không đụng độ và gửi lại nhiều lần vẫn chỉ ra một bản ghi.
/// <see cref="UpdatedAt"/> (UTC) đổi mỗi khi bản ghi thay đổi — kể cả khi xóa mềm — để app kéo thay đổi theo <c>updatedSince</c>.
/// </summary>
public sealed class Customer : AuditableEntity<Guid>, IHasConcurrencyStamp
{
    public string Name { get; private set; } = null!;

    /// <summary>Tên gọi/biệt danh khi nói ("chị Hoa chợ", "anh Tư") — giúp nhận diện khách bằng giọng nói.</summary>
    public string? Alias { get; private set; }

    public string? Phone { get; private set; }

    public string? Note { get; private set; }

    /// <summary>Thời điểm (UTC) bản ghi thay đổi lần cuối; dùng làm mốc đồng bộ cho app.</summary>
    public DateTime UpdatedAt { get; private set; }

    public string ConcurrencyStamp { get; set; } = Guid.NewGuid().ToString("N");

    private Customer()
    {
    }

    public static Customer Create(Guid id, string name, string? alias, string? phone, string? note, DateTime utcNow)
    {
        if (id == Guid.Empty)
            throw new ArgumentException("Id khách hàng là bắt buộc.", nameof(id));

        var entity = new Customer { Id = id };
        entity.Update(name, alias, phone, note, utcNow);
        return entity;
    }

    /// <summary>
    /// Cập nhật thông tin. Trả <c>false</c> (và KHÔNG đổi <see cref="UpdatedAt"/>) nếu không có gì thay đổi — nhờ vậy app gửi
    /// lại cùng một bản ghi nhiều lần (idempotent) không làm phát sinh thay đổi giả cho các máy khác.
    /// </summary>
    public bool Update(string name, string? alias, string? phone, string? note, DateTime utcNow)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Tên khách hàng là bắt buộc.", nameof(name));

        var newName = name.Trim();
        var newAlias = Normalize(alias);
        var newPhone = Normalize(phone);
        var newNote = Normalize(note);

        if (Name == newName && Alias == newAlias && Phone == newPhone && Note == newNote)
            return false;

        Name = newName;
        Alias = newAlias;
        Phone = newPhone;
        Note = newNote;
        UpdatedAt = utcNow;
        return true;
    }

    /// <summary>Xóa mềm; idempotent — gọi lại không đổi gì (giữ nguyên mốc UpdatedAt đầu tiên).</summary>
    public void SoftDelete(DateTime utcNow)
    {
        if (IsDeleted)
            return;

        IsDeleted = true;
        UpdatedAt = utcNow;
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
