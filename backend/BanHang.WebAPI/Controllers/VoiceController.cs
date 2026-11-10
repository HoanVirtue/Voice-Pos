using BanHang.Application.Voice.Dtos;
using BanHang.Application.Voice.Queries;
using BanHang.BuildingBlocks.Authorization;
using BanHang.BuildingBlocks.Web;
using BanHang.WebAPI.Authorization;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

public sealed class VoiceController(ISender sender) : BaseController(sender)
{
    /// <summary>Token nhận dạng giọng nói (Blaze) cho app — để app không phải nhúng token cứng.</summary>
    [HttpGet("stt-token")]
    [Permission(SystemPermissions.Voice.Use)]
    public async Task<ActionResult<ActionResponse<SttTokenDto>>> GetSttToken(CancellationToken cancellationToken)
    {
        var result = await Sender.Send(new GetSttTokenQuery(), cancellationToken);
        return Ok(ActionResponse<SttTokenDto>.Ok(result));
    }
}
