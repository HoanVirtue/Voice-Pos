using BanHang.Application.Customers.Dtos;
using MediatR;

namespace BanHang.Application.Customers.Commands;

/// <summary>
/// Tạo hoặc cập nhật khách theo Id do client sinh. Gửi lại nhiều lần cho kết quả như nhau (idempotent):
/// chưa có thì tạo, đã có thì cập nhật, đã bị xóa thì giữ nguyên trạng thái xóa.
/// </summary>
public sealed record UpsertCustomerCommand(
    Guid Id,
    string Name,
    string? Alias = null,
    string? Phone = null,
    string? Note = null) : IRequest<CustomerDto>;
