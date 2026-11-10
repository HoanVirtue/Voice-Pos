using BanHang.Application.Customers.Dtos;
using BanHang.BuildingBlocks.Time;
using BanHang.Domain.Entities.Customers;
using BanHang.SharedKernel.Repositories;
using MediatR;

namespace BanHang.Application.Customers.Commands;

public sealed class UpsertCustomerCommandHandler(
    IRepository<Customer, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<UpsertCustomerCommand, CustomerDto>
{
    public async Task<CustomerDto> Handle(UpsertCustomerCommand request, CancellationToken cancellationToken)
    {
        var utcNow = dateTimeProvider.UtcNow;

        // FindAsync không áp query filter nên thấy cả bản ghi đã xóa mềm — cần để không tạo lại Id đã dùng.
        var existing = await repository.FindAsync(request.Id, cancellationToken);

        if (existing is null)
        {
            var created = Customer.Create(request.Id, request.Name, request.Alias, request.Phone, request.Note, utcNow);
            await repository.InsertAsync(created, cancellationToken: cancellationToken);
            return CustomerDto.From(created);
        }

        // Đã xóa: không hồi sinh qua upsert (bản xóa là sự thật; app sẽ thấy IsDeleted khi kéo thay đổi).
        if (existing.IsDeleted)
        {
            return CustomerDto.From(existing);
        }

        if (existing.Update(request.Name, request.Alias, request.Phone, request.Note, utcNow))
        {
            await repository.UpdateAsync(existing, cancellationToken: cancellationToken);
        }

        return CustomerDto.From(existing);
    }
}
