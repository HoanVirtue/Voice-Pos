using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Batches;

/// <summary>Lô hàng (con lợn): ngày mua, số con, khối lượng, tiền mua và chi phí. Lãi tính theo lô.</summary>
public sealed class Batch : AuditableEntity<Guid>, IHasConcurrencyStamp
{
    /// <summary>Ngày mua theo giờ Việt Nam.</summary>
    public DateOnly Date { get; private set; }

    public int PigCount { get; private set; }

    /// <summary>Khối lượng hơi (gram).</summary>
    public int? LiveWeightGram { get; private set; }

    /// <summary>Khối lượng móc hàm (gram).</summary>
    public int? CarcassWeightGram { get; private set; }

    /// <summary>Tiền mua lợn (đồng).</summary>
    public long BuyCost { get; private set; }

    /// <summary>Chi phí khác: mổ, chở, đá, túi… (đồng).</summary>
    public long OtherCost { get; private set; }

    public string? Note { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public string ConcurrencyStamp { get; set; } = Guid.NewGuid().ToString("N");

    private Batch()
    {
    }

    public static Batch Create(
        Guid id, DateOnly date, int pigCount, int? liveWeightGram, int? carcassWeightGram,
        long buyCost, long otherCost, string? note, DateTime utcNow)
    {
        if (id == Guid.Empty)
            throw new ArgumentException("Id lô hàng là bắt buộc.", nameof(id));

        var entity = new Batch { Id = id };
        entity.Update(date, pigCount, liveWeightGram, carcassWeightGram, buyCost, otherCost, note, utcNow);
        return entity;
    }

    public bool Update(
        DateOnly date, int pigCount, int? liveWeightGram, int? carcassWeightGram,
        long buyCost, long otherCost, string? note, DateTime utcNow)
    {
        if (pigCount < 0 || buyCost < 0 || otherCost < 0 || liveWeightGram < 0 || carcassWeightGram < 0)
            throw new ArgumentOutOfRangeException(nameof(pigCount), "Số lượng, khối lượng và tiền không được âm.");

        var newNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();

        if (Date == date && PigCount == pigCount && LiveWeightGram == liveWeightGram
            && CarcassWeightGram == carcassWeightGram && BuyCost == buyCost && OtherCost == otherCost && Note == newNote)
            return false;

        Date = date;
        PigCount = pigCount;
        LiveWeightGram = liveWeightGram;
        CarcassWeightGram = carcassWeightGram;
        BuyCost = buyCost;
        OtherCost = otherCost;
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
