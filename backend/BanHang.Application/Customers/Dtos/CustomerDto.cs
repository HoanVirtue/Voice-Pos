using BanHang.Domain.Entities.Customers;

namespace BanHang.Application.Customers.Dtos;

/// <summary>
/// <see cref="UpdatedAt"/> luôn là UTC (có hậu tố Z khi serialize). <see cref="IsDeleted"/> chỉ có thể true khi app kéo
/// thay đổi với <c>includeDeleted=true</c> — để app biết khách nào đã bị xóa mà gỡ khỏi máy.
/// </summary>
public sealed record CustomerDto(
    Guid Id,
    string Name,
    string? Alias,
    string? Phone,
    string? Note,
    DateTime UpdatedAt,
    bool IsDeleted)
{
    public static CustomerDto From(Customer c) => new(
        c.Id,
        c.Name,
        c.Alias,
        c.Phone,
        c.Note,
        // MySQL datetime không lưu Kind: gắn lại UTC để JSON ra "…Z" và app không hiểu nhầm là giờ local.
        DateTime.SpecifyKind(c.UpdatedAt, DateTimeKind.Utc),
        c.IsDeleted);
}
