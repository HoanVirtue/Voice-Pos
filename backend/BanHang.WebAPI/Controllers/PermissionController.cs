using BanHang.Application.Permissions.Dtos;
using BanHang.Application.Permissions.Queries;
using BanHang.BuildingBlocks.Web;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

public sealed class PermissionController(ISender sender) : BaseController(sender)
{
    /// <summary>Quyền hiệu lực của người đang đăng nhập (tính lại từ DB) — app gọi để ẩn/hiện chức năng.</summary>
    [HttpGet("Mine")]
    public async Task<ActionResult<ActionResponse<MyPermissionsDto>>> Mine(CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetMyPermissionsQuery(), cancellationToken);
        return Ok(ActionResponse<MyPermissionsDto>.Ok(result));
    }
}
