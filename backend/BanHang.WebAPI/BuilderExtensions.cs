using BanHang.Application;
using BanHang.Application.Voice;
using BanHang.BuildingBlocks;
using BanHang.BuildingBlocks.Cors;
using BanHang.Infrastructure;
using BanHang.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;

namespace BanHang.WebAPI;

public static class BuilderExtensions
{
    public static void AddAppServices(this WebApplicationBuilder builder)
    {
        builder.AddBuildingBlocks();

        builder.Services.AddControllers();

        builder.Services.AddApplication();
        builder.Services.AddInfrastructure(builder.Configuration);

        builder.Services.Configure<BlazeOptions>(builder.Configuration.GetSection(BlazeOptions.SectionName));

        // Policy dựng động từ tên policy do [Permission(...)] sinh ra, nên thêm quyền mới không
        // phải khai báo thêm gì ở đây.
        builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
        builder.Services.AddScoped<IAuthorizationHandler, PermissionHandler>();
    }

    public static void UseAppPipeline(this WebApplication app)
    {
        app.UseBuildingBlocks();

        // Trên server thật HTTPS thường do reverse proxy đảm nhiệm; chỉ bật chuyển hướng khi cấu hình tường minh.
        if (app.Configuration.GetValue<bool>("UseHttpsRedirection"))
        {
            app.UseHttpsRedirection();
        }

        app.UseCustomCors();
        app.UseAuthentication();
        app.UseAuthorization();

        app.MapGet("/health", () => Results.Ok(new { status = "ok" })).AllowAnonymous();
        app.MapControllers();
    }
}
