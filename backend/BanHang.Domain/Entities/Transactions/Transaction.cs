using BanHang.SharedKernel.Entities;

namespace BanHang.Domain.Entities.Transactions;

/// <summary>Loại giao dịch — mỗi câu nói tạo một dòng.</summary>
public enum TransactionType
{
    /// <summary>Bán hàng (trả ngay một phần hoặc ghi nợ phần còn lại).</summary>
    Sale = 1,

    /// <summary>Khách trả nợ cũ.</summary>
    DebtPayment = 2,

    /// <summary>Mua lợn.</summary>
    BuyPig = 3,

    /// <summary>Chi khác.</summary>
    Expense = 4,

    /// <summary>Mang tiền đi chợ.</summary>
    CashOut = 5,
}

/// <summary>
/// Giao dịch (bảng lõi). Không dùng khóa ngoại tới khách/món/lô để đồng bộ offline không phụ thuộc thứ tự đẩy lên.
/// Sale: Amount = tổng bán, PaidAmount = trả ngay (nợ = Amount − PaidAmount). Các loại còn lại: PaidAmount = Amount.
/// </summary>
public sealed class Transaction : AuditableEntity<Guid>, IHasConcurrencyStamp
{
    public DateTime OccurredAt { get; private set; }

    public TransactionType Type { get; private set; }

    public Guid? CustomerId { get; private set; }

    public Guid? ProductId { get; private set; }

    public Guid? BatchId { get; private set; }

    /// <summary>Khối lượng (gram).</summary>
    public int? WeightGram { get; private set; }

    public long Amount { get; private set; }

    public long PaidAmount { get; private set; }

    /// <summary>Câu nói gốc.</summary>
    public string? RawText { get; private set; }

    /// <summary>Độ tin cậy của bộ phân tích, 0..1.</summary>
    public double? Confidence { get; private set; }

    public string? Note { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public string ConcurrencyStamp { get; set; } = Guid.NewGuid().ToString("N");

    private Transaction()
    {
    }

    public static Transaction Create(
        Guid id, DateTime occurredAt, TransactionType type, Guid? customerId, Guid? productId, Guid? batchId,
        int? weightGram, long amount, long paidAmount, string? rawText, double? confidence, string? note, DateTime utcNow)
    {
        if (id == Guid.Empty)
            throw new ArgumentException("Id giao dịch là bắt buộc.", nameof(id));

        var entity = new Transaction { Id = id };
        entity.Update(occurredAt, type, customerId, productId, batchId, weightGram, amount, paidAmount, rawText, confidence, note, utcNow);
        return entity;
    }

    /// <summary>Trả <c>false</c> (không đổi UpdatedAt) nếu không có gì thay đổi.</summary>
    public bool Update(
        DateTime occurredAt, TransactionType type, Guid? customerId, Guid? productId, Guid? batchId,
        int? weightGram, long amount, long paidAmount, string? rawText, double? confidence, string? note, DateTime utcNow)
    {
        if (!Enum.IsDefined(type))
            throw new ArgumentException("Loại giao dịch không hợp lệ.", nameof(type));
        if (amount < 0 || weightGram < 0)
            throw new ArgumentOutOfRangeException(nameof(amount), "Số tiền và khối lượng không được âm.");

        // Chỉ Sale mới có khái niệm trả một phần; còn lại coi như trả đủ.
        var newPaid = type == TransactionType.Sale ? paidAmount : amount;
        if (newPaid < 0 || newPaid > amount)
            throw new ArgumentOutOfRangeException(nameof(paidAmount), "Số tiền đã trả phải từ 0 đến tổng tiền.");

        var newOccurredAt = occurredAt.Kind switch
        {
            DateTimeKind.Utc => occurredAt,
            DateTimeKind.Local => occurredAt.ToUniversalTime(),
            _ => DateTime.SpecifyKind(occurredAt, DateTimeKind.Utc)
        };
        var newRaw = Normalize(rawText);
        var newNote = Normalize(note);
        var newCustomer = customerId == Guid.Empty ? null : customerId;
        var newProduct = productId == Guid.Empty ? null : productId;
        var newBatch = batchId == Guid.Empty ? null : batchId;

        if (OccurredAt == newOccurredAt && Type == type && CustomerId == newCustomer && ProductId == newProduct
            && BatchId == newBatch && WeightGram == weightGram && Amount == amount && PaidAmount == newPaid
            && RawText == newRaw && Confidence == confidence && Note == newNote)
            return false;

        OccurredAt = newOccurredAt;
        Type = type;
        CustomerId = newCustomer;
        ProductId = newProduct;
        BatchId = newBatch;
        WeightGram = weightGram;
        Amount = amount;
        PaidAmount = newPaid;
        RawText = newRaw;
        Confidence = confidence;
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

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
