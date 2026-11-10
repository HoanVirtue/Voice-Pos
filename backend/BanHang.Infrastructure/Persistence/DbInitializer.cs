using BanHang.BuildingBlocks.Auth;
using BanHang.Domain.Entities.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace BanHang.Infrastructure.Persistence;

public static class DbInitializer
{
    /// <summary>
    /// Seed tài khoản mặc định: admin (vai trò quản trị) và các tài khoản bán hàng ("bo", "me").
    /// Mật khẩu đọc từ cấu hình (<c>Seed:AdminPassword</c>, <c>Seed:BoPassword</c>, <c>Seed:MePassword</c>) — KHÔNG có
    /// mật khẩu mặc định trong code: thiếu cấu hình thì bỏ qua tài khoản đó và ghi cảnh báo. Chỉ tạo khi chưa tồn tại,
    /// không bao giờ ghi đè mật khẩu của tài khoản đã có.
    /// </summary>
    public static async Task SeedDefaultUsersAsync(
        IServiceProvider services, string adminRoleKey, string sellerRoleKey, CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var provider = scope.ServiceProvider;
        var dbContext = provider.GetRequiredService<BanHangDbContext>();
        var configuration = provider.GetRequiredService<IConfiguration>();
        var passwordHasher = provider.GetRequiredService<IPasswordHasher>();
        var logger = provider.GetRequiredService<ILoggerFactory>().CreateLogger("DbInitializer");

        var adminRoleId = await GetRoleIdAsync(dbContext, adminRoleKey, cancellationToken);
        var sellerRoleId = await GetRoleIdAsync(dbContext, sellerRoleKey, cancellationToken);

        var seeds = new[]
        {
            (Username: configuration["Seed:AdminUsername"] ?? "admin", Display: "Quản trị viên",
                Password: configuration["Seed:AdminPassword"], RoleId: adminRoleId),
            (Username: configuration["Seed:BoUsername"] ?? "bo", Display: "Bố",
                Password: configuration["Seed:BoPassword"], RoleId: sellerRoleId),
            (Username: configuration["Seed:MeUsername"] ?? "me", Display: "Mẹ",
                Password: configuration["Seed:MePassword"], RoleId: sellerRoleId),
        };

        foreach (var seed in seeds)
        {
            // IgnoreQueryFilters: tài khoản đã bị xóa mềm vẫn giữ chỗ username (unique index không lọc IsDeleted).
            var exists = await dbContext.Set<User>().IgnoreQueryFilters()
                .AnyAsync(u => u.Username == seed.Username, cancellationToken);
            if (exists)
            {
                continue;
            }

            if (string.IsNullOrWhiteSpace(seed.Password))
            {
                logger.LogWarning(
                    "Bỏ qua seed tài khoản '{Username}': chưa cấu hình mật khẩu (xem .env.example, mục Seed__*).",
                    seed.Username);
                continue;
            }

            dbContext.Set<User>().Add(
                User.Create(seed.Username, passwordHasher.Hash(seed.Password), seed.RoleId, seed.Display));
            await dbContext.SaveChangesAsync(cancellationToken);
            logger.LogInformation("Đã seed tài khoản '{Username}'. Hãy đổi mật khẩu sau lần đăng nhập đầu.", seed.Username);
        }
    }

    private static async Task<long> GetRoleIdAsync(BanHangDbContext dbContext, string roleKey, CancellationToken cancellationToken)
    {
        var roleId = await dbContext.Set<Role>()
            .Where(r => r.Key == roleKey)
            .Select(r => r.Id)
            .FirstOrDefaultAsync(cancellationToken);

        return roleId != 0
            ? roleId
            : throw new InvalidOperationException(
                $"Chưa seed được vai trò '{roleKey}' — kiểm tra thứ tự gọi seeder trong Program.cs.");
    }
}
