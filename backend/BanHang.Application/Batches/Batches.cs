using BanHang.Application.Common;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Time;
using BanHang.Domain.Entities.Batches;
using BanHang.SharedKernel.Repositories;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Batches;

public sealed record BatchDto(
    Guid Id,
    DateOnly Date,
    int PigCount,
    int? LiveWeightGram,
    int? CarcassWeightGram,
    long BuyCost,
    long OtherCost,
    string? Note,
    DateTime UpdatedAt,
    bool IsDeleted)
{
    public static BatchDto From(Batch b) => new(
        b.Id, b.Date, b.PigCount, b.LiveWeightGram, b.CarcassWeightGram, b.BuyCost, b.OtherCost, b.Note,
        b.UpdatedAt.AsUtc(), b.IsDeleted);
}

/// <summary>Tạo hoặc cập nhật lô hàng theo Id do client sinh (idempotent).</summary>
public sealed record UpsertBatchCommand(
    Guid Id,
    DateOnly Date,
    int PigCount = 0,
    int? LiveWeightGram = null,
    int? CarcassWeightGram = null,
    long BuyCost = 0,
    long OtherCost = 0,
    string? Note = null) : IRequest<BatchDto>;

public sealed record DeleteBatchCommand(Guid Id) : IRequest;

public sealed class GetBatchesQuery : SyncQueryRequestBase, IRequest<PaginatedList<BatchDto>>;

public sealed record GetBatchByIdQuery(Guid Id) : IRequest<BatchDto>;

public sealed class UpsertBatchCommandValidator : AbstractValidator<UpsertBatchCommand>
{
    public UpsertBatchCommandValidator()
    {
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã lô hàng không hợp lệ.");
        RuleFor(x => x.Date).NotEqual(default(DateOnly)).WithMessage("Ngày của lô hàng không hợp lệ.");
        RuleFor(x => x.PigCount).GreaterThanOrEqualTo(0).WithMessage("Số con không được âm.");
        RuleFor(x => x.LiveWeightGram).GreaterThanOrEqualTo(0).When(x => x.LiveWeightGram.HasValue)
            .WithMessage("Khối lượng hơi không được âm.");
        RuleFor(x => x.CarcassWeightGram).GreaterThanOrEqualTo(0).When(x => x.CarcassWeightGram.HasValue)
            .WithMessage("Khối lượng móc hàm không được âm.");
        RuleFor(x => x.BuyCost).GreaterThanOrEqualTo(0).WithMessage("Tiền mua không được âm.");
        RuleFor(x => x.OtherCost).GreaterThanOrEqualTo(0).WithMessage("Chi phí khác không được âm.");
        RuleFor(x => x.Note).MaximumLength(1000).WithMessage("Ghi chú tối đa 1000 ký tự.");
    }
}

public sealed class DeleteBatchCommandValidator : AbstractValidator<DeleteBatchCommand>
{
    public DeleteBatchCommandValidator() =>
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã lô hàng không hợp lệ.");
}

public sealed class GetBatchesQueryValidator : PagedQueryValidator<GetBatchesQuery>;

public sealed class UpsertBatchCommandHandler(
    IRepository<Batch, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<UpsertBatchCommand, BatchDto>
{
    public async Task<BatchDto> Handle(UpsertBatchCommand request, CancellationToken cancellationToken)
    {
        var utcNow = dateTimeProvider.UtcNow;
        var existing = await repository.FindAsync(request.Id, cancellationToken);

        if (existing is null)
        {
            var created = Batch.Create(
                request.Id, request.Date, request.PigCount, request.LiveWeightGram, request.CarcassWeightGram,
                request.BuyCost, request.OtherCost, request.Note, utcNow);
            await repository.InsertAsync(created, cancellationToken: cancellationToken);
            return BatchDto.From(created);
        }

        if (existing.IsDeleted)
        {
            return BatchDto.From(existing);
        }

        if (existing.Update(
                request.Date, request.PigCount, request.LiveWeightGram, request.CarcassWeightGram,
                request.BuyCost, request.OtherCost, request.Note, utcNow))
        {
            await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
        }

        return BatchDto.From(existing);
    }
}

public sealed class DeleteBatchCommandHandler(
    IRepository<Batch, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<DeleteBatchCommand>
{
    public async Task Handle(DeleteBatchCommand request, CancellationToken cancellationToken)
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

public sealed class GetBatchesQueryHandler(IReadOnlyRepository<Batch, Guid> repository)
    : IRequestHandler<GetBatchesQuery, PaginatedList<BatchDto>>
{
    public async Task<PaginatedList<BatchDto>> Handle(GetBatchesQuery request, CancellationToken cancellationToken)
    {
        var query = repository.Queryable;

        if (request.IncludeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim();
            query = query.Where(b => b.Note != null && b.Note.Contains(keyword));
        }

        if (request.UpdatedSince.HasValue)
        {
            var since = request.UpdatedSince.Value.AsUtc();
            query = query.Where(b => b.UpdatedAt > since).OrderBy(b => b.UpdatedAt).ThenBy(b => b.Id);
        }
        else
        {
            query = query.OrderByDescending(b => b.Date).ThenBy(b => b.Id);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var entities = await query
            .Skip((request.PageIndex - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedList<BatchDto>(
            entities.Select(BatchDto.From).ToList(), totalCount, request.PageIndex, request.PageSize);
    }
}

public sealed class GetBatchByIdQueryHandler(IReadOnlyRepository<Batch, Guid> repository)
    : IRequestHandler<GetBatchByIdQuery, BatchDto>
{
    public async Task<BatchDto> Handle(GetBatchByIdQuery request, CancellationToken cancellationToken)
    {
        var entity = await repository.Queryable.FirstOrDefaultAsync(b => b.Id == request.Id, cancellationToken)
                     ?? throw new NotFoundException("Lô hàng", request.Id);
        return BatchDto.From(entity);
    }
}
