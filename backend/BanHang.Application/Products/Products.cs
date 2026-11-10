using BanHang.Application.Common;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Time;
using BanHang.Domain.Entities.Products;
using BanHang.SharedKernel.Repositories;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Products;

public sealed record ProductDto(Guid Id, string Name, string? Alias, long PricePerKg, DateTime UpdatedAt, bool IsDeleted)
{
    public static ProductDto From(Product p) =>
        new(p.Id, p.Name, p.Alias, p.PricePerKg, p.UpdatedAt.AsUtc(), p.IsDeleted);
}

/// <summary>Tạo hoặc cập nhật món theo Id do client sinh (idempotent; đã xóa thì giữ nguyên trạng thái xóa).</summary>
public sealed record UpsertProductCommand(Guid Id, string Name, string? Alias = null, long PricePerKg = 0) : IRequest<ProductDto>;

public sealed record DeleteProductCommand(Guid Id) : IRequest;

public sealed class GetProductsQuery : SyncQueryRequestBase, IRequest<PaginatedList<ProductDto>>;

public sealed record GetProductByIdQuery(Guid Id) : IRequest<ProductDto>;

public sealed class UpsertProductCommandValidator : AbstractValidator<UpsertProductCommand>
{
    public UpsertProductCommandValidator()
    {
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã món hàng không hợp lệ.");
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Tên món hàng không được để trống.")
            .MaximumLength(100).WithMessage("Tên món hàng tối đa 100 ký tự.");
        RuleFor(x => x.Alias).MaximumLength(100).WithMessage("Tên gọi tối đa 100 ký tự.");
        RuleFor(x => x.PricePerKg).GreaterThanOrEqualTo(0).WithMessage("Giá mỗi kg không được âm.");
    }
}

public sealed class DeleteProductCommandValidator : AbstractValidator<DeleteProductCommand>
{
    public DeleteProductCommandValidator() =>
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã món hàng không hợp lệ.");
}

public sealed class GetProductsQueryValidator : PagedQueryValidator<GetProductsQuery>;

public sealed class UpsertProductCommandHandler(
    IRepository<Product, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<UpsertProductCommand, ProductDto>
{
    public async Task<ProductDto> Handle(UpsertProductCommand request, CancellationToken cancellationToken)
    {
        var utcNow = dateTimeProvider.UtcNow;
        var existing = await repository.FindAsync(request.Id, cancellationToken);

        if (existing is null)
        {
            var created = Product.Create(request.Id, request.Name, request.Alias, request.PricePerKg, utcNow);
            await repository.InsertAsync(created, cancellationToken: cancellationToken);
            return ProductDto.From(created);
        }

        if (existing.IsDeleted)
        {
            return ProductDto.From(existing);
        }

        if (existing.Update(request.Name, request.Alias, request.PricePerKg, utcNow))
        {
            await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
        }

        return ProductDto.From(existing);
    }
}

public sealed class DeleteProductCommandHandler(
    IRepository<Product, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<DeleteProductCommand>
{
    public async Task Handle(DeleteProductCommand request, CancellationToken cancellationToken)
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

public sealed class GetProductsQueryHandler(IReadOnlyRepository<Product, Guid> repository)
    : IRequestHandler<GetProductsQuery, PaginatedList<ProductDto>>
{
    public async Task<PaginatedList<ProductDto>> Handle(GetProductsQuery request, CancellationToken cancellationToken)
    {
        var query = repository.Queryable;

        if (request.IncludeDeleted)
        {
            query = query.IgnoreQueryFilters();
        }

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim();
            query = query.Where(p => p.Name.Contains(keyword) || (p.Alias != null && p.Alias.Contains(keyword)));
        }

        if (request.UpdatedSince.HasValue)
        {
            var since = request.UpdatedSince.Value.AsUtc();
            query = query.Where(p => p.UpdatedAt > since).OrderBy(p => p.UpdatedAt).ThenBy(p => p.Id);
        }
        else
        {
            query = query.OrderBy(p => p.Name).ThenBy(p => p.Id);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var entities = await query
            .Skip((request.PageIndex - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        return new PaginatedList<ProductDto>(
            entities.Select(ProductDto.From).ToList(), totalCount, request.PageIndex, request.PageSize);
    }
}

public sealed class GetProductByIdQueryHandler(IReadOnlyRepository<Product, Guid> repository)
    : IRequestHandler<GetProductByIdQuery, ProductDto>
{
    public async Task<ProductDto> Handle(GetProductByIdQuery request, CancellationToken cancellationToken)
    {
        var entity = await repository.Queryable.FirstOrDefaultAsync(p => p.Id == request.Id, cancellationToken)
                     ?? throw new NotFoundException("Món hàng", request.Id);
        return ProductDto.From(entity);
    }
}
