using System.Net;
using BanHang.Application.Common;
using BanHang.Application.Reports;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Time;
using BanHang.Domain.Entities.DaySettlements;
using BanHang.Domain.Entities.Transactions;
using BanHang.SharedKernel.Repositories;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.DaySettlements;

public sealed record DaySettlementDto(
    Guid Id,
    DateOnly Date,
    long OpeningCash,
    long CountedCash,
    long ExpectedCash,
    long Difference,
    string? Note,
    DateTime UpdatedAt,
    bool IsDeleted)
{
    public static DaySettlementDto From(DaySettlement s) => new(
        s.Id, s.Date, s.OpeningCash, s.CountedCash, s.ExpectedCash, s.Difference, s.Note, s.UpdatedAt.AsUtc(), s.IsDeleted);
}

/// <summary>
/// Chốt sổ ngày. Server tự tính ExpectedCash (theo Báo cáo ngày) và Difference. Mỗi ngày một bản ghi chưa xóa:
/// Id khác nhưng trùng ngày → 409.
/// </summary>
public sealed record UpsertDaySettlementCommand(
    Guid Id, DateOnly Date, long OpeningCash = 0, long CountedCash = 0, string? Note = null) : IRequest<DaySettlementDto>;

public sealed record DeleteDaySettlementCommand(Guid Id) : IRequest;

public sealed class GetDaySettlementsQuery : SyncQueryRequestBase, IRequest<PaginatedList<DaySettlementDto>>;

public sealed record GetDaySettlementByIdQuery(Guid Id) : IRequest<DaySettlementDto>;

public sealed class UpsertDaySettlementCommandValidator : AbstractValidator<UpsertDaySettlementCommand>
{
    public UpsertDaySettlementCommandValidator()
    {
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã chốt sổ không hợp lệ.");
        RuleFor(x => x.Date).NotEqual(default(DateOnly)).WithMessage("Ngày chốt sổ không hợp lệ.");
        RuleFor(x => x.OpeningCash).GreaterThanOrEqualTo(0).WithMessage("Tiền đầu ngày không được âm.");
        RuleFor(x => x.CountedCash).GreaterThanOrEqualTo(0).WithMessage("Tiền đếm thực tế không được âm.");
        RuleFor(x => x.Note).MaximumLength(1000).WithMessage("Ghi chú tối đa 1000 ký tự.");
    }
}

public sealed class DeleteDaySettlementCommandValidator : AbstractValidator<DeleteDaySettlementCommand>
{
    public DeleteDaySettlementCommandValidator() =>
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã chốt sổ không hợp lệ.");
}

public sealed class GetDaySettlementsQueryValidator : PagedQueryValidator<GetDaySettlementsQuery>;

public sealed class UpsertDaySettlementCommandHandler(
    IRepository<DaySettlement, Guid> repository,
    IReadOnlyRepository<Transaction, Guid> transactions,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<UpsertDaySettlementCommand, DaySettlementDto>
{
    public async Task<DaySettlementDto> Handle(UpsertDaySettlementCommand request, CancellationToken cancellationToken)
    {
        var utcNow = dateTimeProvider.UtcNow;
        var existing = await repository.FindAsync(request.Id, cancellationToken);

        // Đã xóa: không hồi sinh qua upsert.
        if (existing is { IsDeleted: true })
        {
            return DaySettlementDto.From(existing);
        }

        var dateTaken = await repository.Queryable
            .AnyAsync(s => s.Date == request.Date && s.Id != request.Id, cancellationToken);
        if (dateTaken)
        {
            throw new CustomException("Ngày này đã được chốt sổ.", HttpStatusCode.Conflict);
        }

        var daily = await DailyReportCalculator.ComputeAsync(transactions, request.Date, request.OpeningCash, cancellationToken);

        if (existing is null)
        {
            var created = DaySettlement.Create(
                request.Id, request.Date, request.OpeningCash, request.CountedCash, daily.CashInHand, request.Note, utcNow);
            await repository.InsertAsync(created, cancellationToken: cancellationToken);
            return DaySettlementDto.From(created);
        }

        if (existing.Update(request.Date, request.OpeningCash, request.CountedCash, daily.CashInHand, request.Note, utcNow))
        {
            await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
        }

        return DaySettlementDto.From(existing);
    }
}

public sealed class DeleteDaySettlementCommandHandler(
    IRepository<DaySettlement, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<DeleteDaySettlementCommand>
{
    public async Task Handle(DeleteDaySettlementCommand request, CancellationToken cancellationToken)
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

public sealed class GetDaySettlementsQueryHandler(IReadOnlyRepository<DaySettlement, Guid> repository)
    : IRequestHandler<GetDaySettlementsQuery, PaginatedList<DaySettlementDto>>
{
    public async Task<PaginatedList<DaySettlementDto>> Handle(GetDaySettlementsQuery request, CancellationToken cancellationToken)
    {
        var query = repository.Queryable;

        if (request.IncludeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim();
            query = query.Where(s => s.Note != null && s.Note.Contains(keyword));
        }

        if (request.UpdatedSince.HasValue)
        {
            var since = request.UpdatedSince.Value.AsUtc();
            query = query.Where(s => s.UpdatedAt > since).OrderBy(s => s.UpdatedAt).ThenBy(s => s.Id);
        }
        else
        {
            query = query.OrderByDescending(s => s.Date).ThenBy(s => s.Id);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var entities = await query
            .Skip((request.PageIndex - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedList<DaySettlementDto>(
            entities.Select(DaySettlementDto.From).ToList(), totalCount, request.PageIndex, request.PageSize);
    }
}

public sealed class GetDaySettlementByIdQueryHandler(IReadOnlyRepository<DaySettlement, Guid> repository)
    : IRequestHandler<GetDaySettlementByIdQuery, DaySettlementDto>
{
    public async Task<DaySettlementDto> Handle(GetDaySettlementByIdQuery request, CancellationToken cancellationToken)
    {
        var entity = await repository.Queryable.FirstOrDefaultAsync(s => s.Id == request.Id, cancellationToken)
                     ?? throw new NotFoundException("Chốt sổ", request.Id);
        return DaySettlementDto.From(entity);
    }
}
