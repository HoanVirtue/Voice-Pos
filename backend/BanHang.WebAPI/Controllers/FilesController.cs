using BanHang.Application.Files.Commands;
using BanHang.Application.Files.Queries;
using BanHang.BuildingBlocks.Web;
using MediatR;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.WebAPI.Controllers;

public sealed class FilesController(ISender sender) : BaseController(sender)
{
    /// <summary>Tải file lên thư mục con <c>folder</c> (vd "voice"); trả về đường dẫn tương đối để lưu và tải lại.</summary>
    [HttpPost("upload")]
    [RequestSizeLimit(50 * 1024 * 1024)]
    public async Task<ActionResult<ActionResponse<string>>> Upload(
        IFormFile file, [FromForm] string folder, CancellationToken cancellationToken)
    {
        await using var stream = file.OpenReadStream();
        var objectPath = await Sender.Send(new UploadFileCommand(stream, file.FileName, folder), cancellationToken);
        return Ok(ActionResponse<string>.Ok(objectPath));
    }

    [HttpGet("download-url")]
    public async Task<ActionResult<ActionResponse<string>>> GetDownloadUrl(
        [FromQuery] string objectPath, CancellationToken cancellationToken)
    {
        var url = await Sender.Send(new GetFileDownloadUrlQuery(objectPath), cancellationToken);
        return Ok(ActionResponse<string>.Ok(url));
    }

    /// <summary>Tải nội dung file về (cần đăng nhập). Trả file thô, không bọc ActionResponse.</summary>
    [HttpGet("download")]
    public async Task<IActionResult> Download([FromQuery] string path, CancellationToken cancellationToken)
    {
        var file = await Sender.Send(new GetFileContentQuery(path), cancellationToken);
        return File(file.Content, file.ContentType, enableRangeProcessing: true);
    }

    [HttpDelete]
    public async Task<ActionResult<ActionResponse>> Delete([FromQuery] string objectPath, CancellationToken cancellationToken)
    {
        await Sender.Send(new DeleteFileCommand(objectPath), cancellationToken);
        return Ok(ActionResponse.Ok());
    }
}
