using BanHang.BuildingBlocks.Time;
using BanHang.BuildingBlocks.Web;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace BanHang.Infrastructure.Persistence;

/// <summary>
/// Dùng cho công cụ <c>dotnet ef</c> (không chạy app). Chuỗi kết nối lấy theo thứ tự: biến môi trường
/// <c>ConnectionStrings__BanHangConnection</c>, appsettings của BanHang.WebAPI, rồi mặc định MySQL local.
/// </summary>
public sealed class BanHangDbContextFactory : IDesignTimeDbContextFactory<BanHangDbContext>
{
    private const string FallbackConnection =
        "Server=localhost;Port=3306;Database=banhang;User=root;Password=;CharSet=utf8mb4";

    public BanHangDbContext CreateDbContext(string[] args)
    {
        var webApiDir = FindWebApiDirectory();

        var builder = new ConfigurationBuilder();
        if (webApiDir is not null)
        {
            builder.SetBasePath(webApiDir)
                .AddJsonFile("appsettings.json", optional: true)
                .AddJsonFile("appsettings.Development.json", optional: true);
        }

        var configuration = builder.AddEnvironmentVariables().Build();
        var connectionString = configuration.GetConnectionString("BanHangConnection");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            connectionString = FallbackConnection;
        }

        var optionsBuilder = new DbContextOptionsBuilder<BanHangDbContext>();
        BanHangDbContext.Configure(optionsBuilder, connectionString);
        return new BanHangDbContext(optionsBuilder.Options, new DesignTimeCurrentUser(), new DateTimeProvider(), new NullPublisher());
    }

    private static string? FindWebApiDirectory()
    {
        var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "BanHang.WebAPI");
            if (Directory.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        return null;
    }

    private sealed class DesignTimeCurrentUser : ICurrentUser
    {
        public string? UserId => null;
        public string? UserName => null;
        public bool IsAuthenticated => false;
    }

    private sealed class NullPublisher : IPublisher
    {
        public Task Publish(object notification, CancellationToken cancellationToken = default) => Task.CompletedTask;

        public Task Publish<TNotification>(TNotification notification, CancellationToken cancellationToken = default)
            where TNotification : INotification => Task.CompletedTask;
    }
}
