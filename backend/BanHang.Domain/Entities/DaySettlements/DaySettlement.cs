using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.DaySettlements;

/// <summary>Chốt sổ ngày: tiền đầu ngày, tiền đếm thực tế, tiền theo sổ và chênh lệch.</summary>
public sealed class DaySettlement : AuditableEntity<Guid>, IHasConcurrencyStamp
{
    /// <summary>Ngày chốt theo giờ Việt Nam.</summary>
    public DateOnly Date { get; private set; }

    public long OpeningCash { get; private set; }

    public long CountedCash { get; private set; }

    /// <summary>Tiền còn trong tay theo sổ (server tính từ Báo cáo ngày).</summary>
    public long ExpectedCash { get; private set; }

    /// <summary>Chênh lệch = đếm thực tế − theo sổ.</summary>
    public long Difference => CountedCash - ExpectedCash;

    public string? Note { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public string ConcurrencyStamp { get; set; } = Guid.NewGuid().ToString("N");

    private DaySettlement()
    {
    }

    public static DaySettlement Create(
        Guid id, DateOnly date, long openingCash, long countedCash, long expectedCash, string? note, DateTime utcNow)
    {
        if (id == Guid.Empty)
            throw new ArgumentException("Id chốt sổ là bắt buộc.", nameof(id));

        var entity = new DaySettlement { Id = id };
        entity.Update(date, openingCash, countedCash, expectedCash, note, utcNow);
        return entity;
    }

    public bool Update(DateOnly date, long openingCash, long countedCash, long expectedCash, string? note, DateTime utcNow)
    {
        var newNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();

        if (Date == date && OpeningCash == openingCash && CountedCash == countedCash
            && ExpectedCash == expectedCash && Note == newNote)
            return false;

        Date = date;
        OpeningCash = openingCash;
        CountedCash = countedCash;
        ExpectedCash = expectedCash;
        Note = newNote;
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
