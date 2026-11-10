namespace BanHang.BuildingBlocks.Web;

/// <summary>
/// Abstracts "who is calling" away from HttpContext so Application-layer handlers never take
/// a dependency on ASP.NET Core. Until authentication is wired up, every implementation may
/// legitimately return null/false — callers must treat that as "system/anonymous", not an error.
/// </summary>
public interface ICurrentUser
{
    string? UserId { get; }
    string? UserName { get; }
    bool IsAuthenticated { get; }
}
