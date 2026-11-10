using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BanHang.Application.Users.Commands;
using BanHang.Application.Users.Dtos;
using BanHang.Application.Users.Queries;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Pagination;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;

namespace BanHang.WebAPI.Controllers;

/// <summary>Quản lý tài khoản người dùng — nguồn cho màn "Quản lý tài khoản".</summary>
public sealed class UsersController(ISender sender) : BaseController(sender)
{
    [HttpGet("Get/{id:long}")]
    [HttpGet("{id:long}")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<UserDto>>> Get(long id, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetUserByIdQuery(id), cancellationToken);
        return Ok(ActionResponse<UserDto>.Ok(result));
    }

    /// <summary>Thông tin tài khoản của người dùng đang đăng nhập — nguồn cho màn "Tài khoản của tôi".</summary>
    [HttpGet("Me")]
    [Authorize]
    public async Task<ActionResult<ActionResponse<UserDto>>> Me(CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetMyAccountQuery(), cancellationToken);
        return Ok(ActionResponse<UserDto>.Ok(result));
    }

    /// <summary>Người dùng tự đổi mật khẩu — yêu cầu nhập đúng mật khẩu hiện tại, khác ResetPassword của admin.</summary>
    [HttpPut("ChangeMyPassword")]
    [Authorize]
    public async Task<ActionResult<ActionResponse>> ChangeMyPassword(
        ChangeMyPasswordCommand command, CancellationToken cancellationToken)
    {
        await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpGet("List")]
    [HttpGet]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<PaginatedList<UserListItemDto>>>> List(
        [FromQuery] GetUsersQuery query, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(query, cancellationToken);
        return Ok(ActionResponse<PaginatedList<UserListItemDto>>.Ok(result));
    }

    [HttpPost("Create")]
    [HttpPost]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse<long>>> Create(
        CreateUserCommand command, CancellationToken cancellationToken)
    {
        var id = await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse<long>.Ok(id));
    }

    [HttpPut("Update")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> Update(
        UpdateUserCommand command, CancellationToken cancellationToken)
    {
        await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpDelete("Delete/{id:long}")]
    [HttpDelete("{id:long}")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> Delete(long id, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteUserCommand(id), cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpPut("ResetPassword")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> ResetPassword(
        ResetPasswordCommand command, CancellationToken cancellationToken)
    {
        await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpPut("Lock")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> Lock([FromQuery] long id, CancellationToken cancellationToken)
    {
        await Sender.Send(new SetUserStatusCommand(id, IsActive: false), cancellationToken);
        return Ok(ActionResponse.Ok());
    }

    [HttpPut("UnLock")]
    [Permission(SystemPermissions.Users.Manage)]
    public async Task<ActionResult<ActionResponse>> UnLock([FromQuery] long id, CancellationToken cancellationToken)
    {
        await Sender.Send(new SetUserStatusCommand(id, IsActive: true), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}
