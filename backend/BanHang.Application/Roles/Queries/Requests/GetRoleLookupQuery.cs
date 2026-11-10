using MediatR; using BanHang.Application.Common.Dtos;
namespace BanHang.Application.Roles.Queries;
public sealed record GetRoleLookupQuery : IRequest<IReadOnlyCollection<LookupDto>>;
