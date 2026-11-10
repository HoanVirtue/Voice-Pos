using BanHang.BuildingBlocks.Time;
using BanHang.Domain.Entities.Customers;
using BanHang.SharedKernel.Repositories;
using MediatR;

namespace BanHang.Application.Customers.Commands;

public sealed class DeleteCustomerCommandHandler(
    IRepository<Customer, Guid> repository,
    IDateTimeProvider dateTimeProvider) : IRequestHandler<DeleteCustomerCommand>
{
    public async Task Handle(DeleteCustomerCommand request, CancellationToken cancellationToken)
    {
        var customer = await repository.FindAsync(request.Id, cancellationToken);
        if (customer is null || customer.IsDeleted)
        {
            return;
        }

        // Không dùng repository.DeleteAsync: cần đặt UpdatedAt để app kéo được thay đổi "đã xóa".
        customer.SoftDelete(dateTimeProvider.UtcNow);
        await repository.UpdateAsync(customer, cancellationToken: cancellationToken);
    }
}
