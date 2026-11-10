using System.Globalization;
using BanHang.Application.Authorization;
using BanHang.BuildingBlocks.Behaviors;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace BanHang.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        var assembly = typeof(DependencyInjection).Assembly;

        // FluentValidation đi kèm bản dịch tiếng Việt cho các thông báo mặc định; cố định culture "vi" để thông báo
        // luôn tiếng Việt kể cả khi app ép InvariantCulture cho việc parse/format số.
        ValidatorOptions.Global.LanguageManager.Culture = new CultureInfo("vi");

        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(assembly);
            cfg.AddOpenBehavior(typeof(LoggingBehavior<,>));
            cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
        });

        services.AddValidatorsFromAssembly(assembly);

        services.AddScoped<PermissionService>();
        services.AddScoped<EffectivePermissionResolver>();

        return services;
    }
}
