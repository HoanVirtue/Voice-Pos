using System.Globalization;
using BanHang.Application.Authorization;
using BanHang.BuildingBlocks.Authorization;
using BanHang.Domain.Entities.Identity;
using BanHang.Infrastructure.Persistence;
using BanHang.SharedKernel.Repositories;
using BanHang.WebAPI;
using Microsoft.EntityFrameworkCore;

// Máy chủ có thể chạy culture mặc định dùng dấu phẩy thập phân (vi-VN) làm parse/format số sai. Ép invariant culture
// để mọi input/format số luôn theo chuẩn "." — khớp với JSON và với app.
CultureInfo.DefaultThreadCurrentCulture = CultureInfo.InvariantCulture;
CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.InvariantCulture;

DotEnv.Load();

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false);

if (string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("BanHangConnection")))
{
    throw new InvalidOperationException(
        "Thiếu chuỗi kết nối ConnectionStrings:BanHangConnection. Sao chép .env.example thành .env (ở thư mục gốc repo) "
        + "và điền ConnectionStrings__BanHangConnection, hoặc đặt biến môi trường tương ứng.");
}

builder.AddAppServices();

var app = builder.Build();
app.UseAppPipeline();

// Tự động migrate (nếu có migration), sau đó seed danh mục quyền, vai trò mặc định và tài khoản mặc định.
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILoggerFactory>().CreateLogger("Migration");

    var dbContext = services.GetRequiredService<BanHangDbContext>();
    if (dbContext.Database.GetMigrations().Any())
    {
        await dbContext.Database.MigrateAsync();
    }
    else
    {
        // Chưa tạo migration InitialCreate: dựng schema thẳng từ model để `dotnet run` dùng được ngay. Sau khi tạo
        // migration (xem README/báo cáo), xóa DB dev này để MigrateAsync dựng lại từ đầu.
        logger.LogWarning("Chưa có migration nào — dùng EnsureCreated. Hãy chạy 'dotnet ef migrations add InitialCreate'.");
        await dbContext.Database.EnsureCreatedAsync();
    }

    await PermissionCatalogSeeder.SeedAsync(
        services.GetRequiredService<IRepository<Permission>>(), logger);

    await RoleDefaultPermissionSeeder.SeedAsync(
        services.GetRequiredService<IRepository<Role>>(),
        services.GetRequiredService<IRepository<RolePermission>>(),
        logger);
}

await DbInitializer.SeedDefaultUsersAsync(
    app.Services, RoleDefaultPermissionSeeder.AdminKey, RoleDefaultPermissionSeeder.SellerKey);

await app.RunAsync();

/// <summary>Để project test dùng <c>WebApplicationFactory</c> sau này.</summary>
public partial class Program;
