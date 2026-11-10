using Microsoft.AspNetCore.Authorization;

namespace BanHang.WebAPI.Authorization;

/// <summary>Có MỘT trong các key này là đủ (HOẶC) — xem chú thích trên PermissionAttribute.</summary>
public sealed class PermissionRequirement(IReadOnlyList<string> keys) : IAuthorizationRequirement
{
    public IReadOnlyList<string> Keys { get; } = keys;
}
