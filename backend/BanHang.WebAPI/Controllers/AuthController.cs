using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BanHang.Application.Auth.Commands;
using BanHang.Application.Auth.Dtos;
using BanHang.BuildingBlocks.Web;

namespace BanHang.WebAPI.Controllers;

[AllowAnonymous]
public sealed class AuthController(ISender sender) : BaseController(sender)
{
    [HttpPost("login")]
    public async Task<ActionResult<ActionResponse<LoginResultDto>>> Login(LoginCommand command, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse<LoginResultDto>.Ok(result));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<ActionResponse<LoginResultDto>>> Refresh(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        var result = await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse<LoginResultDto>.Ok(result));
    }

    [HttpPost("logout")]
    public async Task<ActionResult<ActionResponse>> Logout(LogoutCommand command, CancellationToken cancellationToken)
    {
        await Sender.Send(command, cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}
