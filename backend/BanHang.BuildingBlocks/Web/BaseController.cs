using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BanHang.BuildingBlocks.Web;

/// <summary>
/// Every module controller inherits this instead of ControllerBase directly, so a module never
/// needs its own MediatR wiring or routing convention — that consistency is what keeps modules
/// swappable behind the same host. Secure by default: every action requires authentication unless
/// explicitly marked [AllowAnonymous] (e.g. login/register).
/// </summary>
[ApiController]
[Route("api/v1/[controller]")]
[Authorize]
public abstract class BaseController(ISender sender) : ControllerBase
{
    protected readonly ISender Sender = sender;
}
