using BanHang.Application.Users.Dtos;
using BanHang.BuildingBlocks.Pagination;
using BanHang.Domain.Entities.Identity;
using BanHang.SharedKernel.Repositories;
using MediatR;

namespace BanHang.Application.Users.Queries;

public sealed class GetUsersQueryHandler(
    IReadOnlyRepository<User> userRepository,
    IReadOnlyRepository<Role> roleRepository)
    : IRequestHandler<GetUsersQuery, PaginatedList<UserListItemDto>>
{
    public Task<PaginatedList<UserListItemDto>> Handle(GetUsersQuery request, CancellationToken cancellationToken)
    {
        var query = from u in userRepository.Queryable
                    join r in roleRepository.Queryable on u.RoleId equals r.Id
                    select new { User = u, Role = r };

        if (!string.IsNullOrWhiteSpace(request.Keyword))
        {
            var keyword = request.Keyword.Trim();
            query = query.Where(x => x.User.Username.Contains(keyword)
                                     || (x.User.DisplayName != null && x.User.DisplayName.Contains(keyword)));
        }

        if (request.RoleId.HasValue && request.RoleId.Value > 0)
        {
            query = query.Where(x => x.User.RoleId == request.RoleId.Value);
        }

        if (request.Status.HasValue)
        {
            query = query.Where(x => x.User.Status == request.Status.Value);
        }

        var projected = query
            .OrderByDescending(x => x.User.Id)
            .Select(x => new UserListItemDto(
                x.User.Id,
                x.User.Username,
                x.User.DisplayName,
                x.Role.Id,
                x.Role.DisplayName,
                x.Role.Key,
                x.User.Status,
                x.User.CreatedAt));

        return PaginatedList<UserListItemDto>.CreateAsync(
            projected, request.PageIndex, request.PageSize, cancellationToken);
    }
}
