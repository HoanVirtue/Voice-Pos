using MediatR;

namespace BanHang.Application.Customers.Commands;

/// <summary>Xóa mềm khách theo Id. Idempotent: khách không tồn tại hoặc đã xóa thì không làm gì và không báo lỗi.</summary>
public sealed record DeleteCustomerCommand(Guid Id) : IRequest;
