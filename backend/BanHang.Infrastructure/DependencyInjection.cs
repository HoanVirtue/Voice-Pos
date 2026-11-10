using BanHang.Infrastructure.Persistence;
using BanHang.Infrastructure.Storage;
using BanHang.SharedKernel.Repositories;
using BanHang.SharedKernel.Storage;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BanHang.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<BanHangDbContext>(options =>
            BanHangDbContext.Configure(options, configuration.GetConnectionString("BanHangConnection")));

        services.AddScoped(typeof(IReadOnlyRepository<,>), typeof(EfCoreRepository<,>));
        services.AddScoped(typeof(IReadOnlyRepository<>), typeof(EfCoreRepository<>));
        services.AddScoped(typeof(IRepository<,>), typeof(EfCoreRepository<,>));
        services.AddScoped(typeof(IRepository<>), typeof(EfCoreRepository<>));

        services.Configure<LocalFileStorageOptions>(configuration.GetSection(LocalFileStorageOptions.SectionName));
        services.AddScoped<IFileStorageService, LocalFileStorageService>();

        return services;
    }
}
