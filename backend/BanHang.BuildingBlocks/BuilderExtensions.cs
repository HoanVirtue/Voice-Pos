using Microsoft.AspNetCore.Builder;
using Serilog;
using BanHang.BuildingBlocks.Auth;
using BanHang.BuildingBlocks.Cors;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Logging;
using BanHang.BuildingBlocks.Swagger;
using BanHang.BuildingBlocks.Time;
using BanHang.BuildingBlocks.Web;

namespace BanHang.BuildingBlocks;

/// <summary>
/// Single entry point the host calls instead of hand-registering every cross-cutting concern in
/// Program.cs — new cross-cutting pieces (caching, rate limiting, ...) get their own
/// Add.../Use... pair next to their feature folder and get wired in here, once.
/// </summary>
public static class BuilderExtensions
{
    public static void AddBuildingBlocks(this WebApplicationBuilder builder)
    {
        builder.AddCustomLogging();
        builder.AddCustomWeb();
        builder.AddCustomTime();
        builder.AddCustomAuth();
        builder.AddCustomCors();
        builder.AddCustomSwagger();
    }

    public static void UseBuildingBlocks(this WebApplication app)
    {
        app.UseCustomSwagger();
        // Ghi log request phải nằm NGOÀI middleware xử lý ngoại lệ: khi đó nó thấy mã trạng thái cuối cùng
        // (401/503/...) thay vì thấy ngoại lệ chưa xử lý và ghi nhầm 500 mức Error.
        app.UseSerilogRequestLogging(o => o.GetLevel = RequestLogLevel.For);
        app.UseMiddleware<ExceptionHandlingMiddleware>();
    }
}
