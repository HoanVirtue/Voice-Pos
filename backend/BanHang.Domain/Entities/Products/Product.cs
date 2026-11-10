using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Products;

/// <summary>Món hàng (ba chỉ, nạc vai, sườn…). Id do client sinh; <see cref="UpdatedAt"/> (UTC) là mốc đồng bộ.</summary>
public sealed class Product : AuditableEntity<Guid>, IHasConcurrencyStamp
{
    public string Name { get; private set; } = null!;

    /// <summary>Tên gọi khác khi nói.</summary>
    public string? Alias { get; private set; }

    /// <summary>Giá bán hiện tại mỗi kg (đồng).</summary>
    public long PricePerKg { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public string ConcurrencyStamp { get; set; } = Guid.NewGuid().ToString("N");

    private Product()
    {
    }

    public static Product Create(Guid id, string name, string? alias, long pricePerKg, DateTime utcNow)
    {
        if (id == Guid.Empty)
            throw new ArgumentException("Id món hàng là bắt buộc.", nameof(id));

        var entity = new Product { Id = id };
        entity.Update(name, alias, pricePerKg, utcNow);
        return entity;
    }

    /// <summary>Trả <c>false</c> (không đổi UpdatedAt) nếu không có gì thay đổi — để gửi lại nhiều lần vẫn idempotent.</summary>
    public bool Update(string name, string? alias, long pricePerKg, DateTime utcNow)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Tên món hàng là bắt buộc.", nameof(name));
        if (pricePerKg < 0)
            throw new ArgumentOutOfRangeException(nameof(pricePerKg), "Giá không được âm.");

        var newName = name.Trim();
        var newAlias = string.IsNullOrWhiteSpace(alias) ? null : alias.Trim();

        if (Name == newName && Alias == newAlias && PricePerKg == pricePerKg)
            return false;

        Name = newName;
        Alias = newAlias;
        PricePerKg = pricePerKg;
        UpdatedAt = utcNow;
        return true;
    }

    public void SoftDelete(DateTime utcNow)
    {
        if (IsDeleted)
            return;

        IsDeleted = true;
        UpdatedAt = utcNow;
    }
}
