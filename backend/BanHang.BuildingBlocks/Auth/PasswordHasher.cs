namespace BanHang.BuildingBlocks.Auth;

/// <summary>BCrypt-based hasher — salted per-call, safe to store the returned hash directly.</summary>
public sealed class PasswordHasher : IPasswordHasher
{
    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password);

    public bool Verify(string password, string passwordHash) => BCrypt.Net.BCrypt.Verify(password, passwordHash);
}
