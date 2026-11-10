using MediatR;
using Microsoft.AspNetCore.Mvc;
using BanHang.Application.Common.Dtos;
using BanHang.Application.Roles.Commands;
using BanHang.Application.Roles.Dtos;
using BanHang.Application.Roles.Queries;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;

namespace BanHang.WebAPI.Controllers;

/// <summary>Vai trò người dùng — nguồn cho màn "Phân quyền người dùng".</summary>
public sealed class RoleController(ISender sender) : BaseController(sender)
{
    [HttpGet("Get/{id:long}")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<RoleDto>>> Get(long id, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetRoleByIdQuery(id), cancellationToken);
        return Ok(ActionResponse<RoleDto>.Ok(result));
    }

    [HttpGet("List")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<PaginatedList<RoleListItemDto>>>> List(
        [FromQuery] GetRolesQuery query, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(query, cancellationToken);
        return Ok(ActionResponse<PaginatedList<RoleListItemDto>>.Ok(result));
    }

    /// <summary>Dùng cho ô chọn vai trò trên form tài khoản — ai quản lý tài khoản cũng cần.</summary>
    [HttpGet("Lookup")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<IReadOnlyCollection<LookupDto>>>> Lookup(
        CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetRoleLookupQuery(), cancellationToken);
        return Ok(ActionResponse<IReadOnlyCollection<LookupDto>>.Ok(result));
    }

    [HttpPost("Create")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<long>>> Create(
        CreateRoleCommand command, CancellationToken cancellationToken)
    {
        var id = await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse<long>.Ok(id));
    }

    [HttpPut("Update")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> Update(
        UpdateRoleCommand command, CancellationToken cancellationToken)
    {
        await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpDelete("Delete/{id:long}")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(long id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteRoleCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpPut("Lock")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> Lock([FromQuery] long id, CancellationToken cancellationToken)
    {
        await Sender.Send(new SetRoleStatusCommand(id, IsActive: false), cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpPut("UnLock")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> UnLock([FromQuery] long id, CancellationToken cancellationToken)
    {
        await Sender.Send(new SetRoleStatusCommand(id, IsActive: true), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}
