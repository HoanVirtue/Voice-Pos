using BanHang.Application.Customers.Dtos;
using MediatR;

namespace BanHang.Application.Customers.Queries;

public sealed record GetCustomerByIdQuery(Guid Id) : IRequest<CustomerDto>;
