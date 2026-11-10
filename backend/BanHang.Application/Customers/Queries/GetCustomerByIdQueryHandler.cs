using BanHang.Application.Customers.Dtos;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.Domain.Entities.Customers;
using BanHang.SharedKernel.Repositories;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace BanHang.Application.Customers.Queries;

public sealed class GetCustomerByIdQueryHandler(IReadOnlyRepository<Customer, Guid> repository)
    : IRequestHandler<GetCustomerByIdQuery, CustomerDto>
{
    public async Task<CustomerDto> Handle(GetCustomerByIdQuery request, CancellationToken cancellationToken)
    {
        // Queryable đã lọc khách đã xóa mềm nên khách đã xóa trả 404.
        var customer = await repository.Queryable.FirstOrDefaultAsync(c => c.Id == request.Id, cancellationToken)
                       ?? throw new NotFoundException("Khách hàng", request.Id);

        return CustomerDto.From(customer);
    }
}
