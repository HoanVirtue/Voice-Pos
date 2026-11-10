using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace BanHang.BuildingBlocks.Time;

public static class BuilderExtensions
{
    public static void AddCustomTime(this WebApplicationBuilder builder)
    {
        builder.Services.AddSingleton<IDateTimeProvider, DateTimeProvider>();
    }
}
