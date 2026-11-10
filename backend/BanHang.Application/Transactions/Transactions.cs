using BanHang.Application.Common;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Time;
using BanHang.Domain.Entities.Transactions;
using BanHang.SharedKernel.Repositories;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Transactions;

/// <summary>
/// <see cref="Type"/>: <c>Sale</c>, <c>DebtPayment</c>, <c>BuyPig</c>, <c>Expense</c>, <c>CashOut</c>.
/// Sale: Amount = tổng bán, PaidAmount = trả ngay (nợ = Amount − PaidAmount). Loại khác: PaidAmount = Amount.
/// </summary>
public sealed record TransactionDto(
    Guid Id,
    DateTime OccurredAt,
    string Type,
    Guid? CustomerId,
    Guid? ProductId,
    Guid? BatchId,
    int? WeightGram,
    long Amount,
    long PaidAmount,
    string? RawText,
    double? Confidence,
    string? Note,
    DateTime UpdatedAt,
    bool IsDeleted)
{
    public static TransactionDto From(Transaction t) => new(
        t.Id, t.OccurredAt.AsUtc(), t.Type.ToString(), t.CustomerId, t.ProductId, t.BatchId, t.WeightGram,
        t.Amount, t.PaidAmount, t.RawText, t.Confidence, t.Note, t.UpdatedAt.AsUtc(), t.IsDeleted);
}

internal static class TransactionTypes
{
    /// <summary>Chỉ nhận đúng tên loại (phân biệt hoa thường); từ chối số như "3".</summary>
    public static bool TryParse(string? value, out TransactionType type)
    {
        type = default;
        return value is not null
               && Enum.GetNames<TransactionType>().Contains(value, StringComparer.Ordinal)
               && Enum.TryParse(value, false, out type);
    }
}

/// <summary>Tạo hoặc cập nhật giao dịch theo Id do client sinh (idempotent; đã xóa thì giữ nguyên trạng thái xóa).</summary>
public sealed record UpsertTransactionCommand(
    Guid Id,
    DateTime OccurredAt,
    string Type,
    Guid? CustomerId = null,
    Guid? ProductId = null,
    Guid? BatchId = null,
    int? WeightGram = null,
    long Amount = 0,
    long PaidAmount = 0,
    string? RawText = null,
    double? Confidence = null,
    string? Note = null) : IRequest<TransactionDto>;

public sealed record DeleteTransactionCommand(Guid Id) : IRequest;

public sealed class GetTransactionsQuery : SyncQueryRequestBase, IRequest<PaginatedList<TransactionDto>>
{
    public DateTime? From { get; set; }

    public DateTime? To { get; set; }

    public Guid? CustomerId { get; set; }

    public string? Type { get; set; }
}

public sealed record GetTransactionByIdQuery(Guid Id) : IRequest<TransactionDto>;

public sealed class UpsertTransactionCommandValidator : AbstractValidator<UpsertTransactionCommand>
{
    public UpsertTransactionCommandValidator()
    {
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã giao dịch không hợp lệ.");
        RuleFor(x => x.OccurredAt).NotEqual(default(DateTime)).WithMessage("Thời gian giao dịch không hợp lệ.");

        RuleFor(x => x.Type)
            .Must(t => TransactionTypes.TryParse(t, out _))
            .WithMessage("Loại giao dịch không hợp lệ (Sale, DebtPayment, BuyPig, Expense, CashOut).");

        RuleFor(x => x.Amount).GreaterThanOrEqualTo(0).WithMessage("Số tiền không được âm.");
        RuleFor(x => x.WeightGram).GreaterThanOrEqualTo(0).When(x => x.WeightGram.HasValue)
            .WithMessage("Khối lượng không được âm.");
        RuleFor(x => x.RawText).MaximumLength(1000).WithMessage("Câu nói gốc tối đa 1000 ký tự.");
        RuleFor(x => x.Note).MaximumLength(1000).WithMessage("Ghi chú tối đa 1000 ký tự.");
        RuleFor(x => x.Confidence).InclusiveBetween(0, 1).When(x => x.Confidence.HasValue)
            .WithMessage("Độ tin cậy phải từ 0 đến 1.");

        When(x => x.Type == nameof(TransactionType.Sale), () =>
        {
            RuleFor(x => x.PaidAmount).InclusiveBetween(0, long.MaxValue).WithMessage("Số tiền đã trả không được âm.");
            RuleFor(x => x).Must(x => x.PaidAmount <= x.Amount)
                .WithName("PaidAmount").WithMessage("Số tiền đã trả không được lớn hơn tổng tiền.");
            RuleFor(x => x.CustomerId)
                .Must(id => id.HasValue && id.Value != Guid.Empty)
                .When(x => x.Amount > x.PaidAmount)
                .WithMessage("Bán nợ phải có khách hàng.");
        });

        RuleFor(x => x.CustomerId)
            .Must(id => id.HasValue && id.Value != Guid.Empty)
            .When(x => x.Type == nameof(TransactionType.DebtPayment))
            .WithMessage("Thu nợ phải có khách hàng.");
    }
}

public sealed class DeleteTransactionCommandValidator : AbstractValidator<DeleteTransactionCommand>
{
    public DeleteTransactionCommandValidator() =>
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã giao dịch không hợp lệ.");
}

public sealed class GetTransactionsQueryValidator : PagedQueryValidator<GetTransactionsQuery>
{
    public GetTransactionsQueryValidator() =>
        RuleFor(x => x.Type)
            .Must(t => TransactionTypes.TryParse(t, out _))
            .When(x => !string.IsNullOrEmpty(x.Type))
            .WithMessage("Loại giao dịch không hợp lệ (Sale, DebtPayment, BuyPig, Expense, CashOut).");
}

public sealed class UpsertTransactionCommandHandler(
    IRepository<Transaction, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<UpsertTransactionCommand, TransactionDto>
{
    public async Task<TransactionDto> Handle(UpsertTransactionCommand request, CancellationToken cancellationToken)
    {
        var utcNow = dateTimeProvider.UtcNow;
        TransactionTypes.TryParse(request.Type, out var type);
        var existing = await repository.FindAsync(request.Id, cancellationToken);

        if (existing is null)
        {
            var created = Transaction.Create(
                request.Id, request.OccurredAt, type, request.CustomerId, request.ProductId, request.BatchId,
                request.WeightGram, request.Amount, request.PaidAmount, request.RawText, request.Confidence,
                request.Note, utcNow);
            await repository.InsertAsync(created, cancellationToken: cancellationToken);
            return TransactionDto.From(created);
        }

        if (existing.IsDeleted)
        {
            return TransactionDto.From(existing);
        }

        if (existing.Update(
                request.OccurredAt, type, request.CustomerId, request.ProductId, request.BatchId,
                request.WeightGram, request.Amount, request.PaidAmount, request.RawText, request.Confidence,
                request.Note, utcNow))
        {
            await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
        }

        return TransactionDto.From(existing);
    }
}

public sealed class DeleteTransactionCommandHandler(
    IRepository<Transaction, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<DeleteTransactionCommand>
{
    public async Task Handle(DeleteTransactionCommand request, CancellationToken cancellationToken)
    {
        var entity = await repository.FindAsync(request.Id, cancellationToken);
        if (entity is null || entity.IsDeleted)
        {
            return;
        }

        entity.SoftDelete(dateTimeProvider.UtcNow);
        await repository.UpdateAsync(entity, cancellationToken: cancellationToken);
    }
}

public sealed class GetTransactionsQueryHandler(IReadOnlyRepository<Transaction, Guid> repository)
    : IRequestHandler<GetTransactionsQuery, PaginatedList<TransactionDto>>
{
    public async Task<PaginatedList<TransactionDto>> Handle(GetTransactionsQuery request, CancellationToken cancellationToken)
    {
        var query = repository.Queryable;

        if (request.IncludeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim();
            query = query.Where(t => (t.RawText != null && t.RawText.Contains(keyword))
                                     || (t.Note != null && t.Note.Contains(keyword)));
        }

        if (request.From.HasValue)
        {
            var from = request.From.Value.AsUtc();
            query = query.Where(t => t.OccurredAt >= from);
        }

        if (request.To.HasValue)
        {
            var to = request.To.Value.AsUtc();
            query = query.Where(t => t.OccurredAt < to);
        }

        if (request.CustomerId.HasValue)
        {
            var customerId = request.CustomerId.Value;
            query = query.Where(t => t.CustomerId == customerId);
        }

        if (TransactionTypes.TryParse(request.Type, out var type))
        {
            query = query.Where(t => t.Type == type);
        }

        if (request.UpdatedSince.HasValue)
        {
            var since = request.UpdatedSince.Value.AsUtc();
            query = query.Where(t => t.UpdatedAt > since).OrderBy(t => t.UpdatedAt).ThenBy(t => t.Id);
        }
        else
        {
            query = query.OrderByDescending(t => t.OccurredAt).ThenBy(t => t.Id);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var entities = await query
            .Skip((request.PageIndex - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedList<TransactionDto>(
            entities.Select(TransactionDto.From).ToList(), totalCount, request.PageIndex, request.PageSize);
    }
}

public sealed class GetTransactionByIdQueryHandler(IReadOnlyRepository<Transaction, Guid> repository)
    : IRequestHandler<GetTransactionByIdQuery, TransactionDto>
{
    public async Task<TransactionDto> Handle(GetTransactionByIdQuery request, CancellationToken cancellationToken)
    {
        var entity = await repository.Queryable.FirstOrDefaultAsync(t => t.Id == request.Id, cancellationToken)
                     ?? throw new NotFoundException("Giao dịch", request.Id);
        return TransactionDto.From(entity);
    }
}
