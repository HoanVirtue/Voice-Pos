using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Serilog;
using Serilog.Filters;

namespace BanHang.BuildingBlocks.Logging;

public static class BuilderExtensions
{
    public const string LogFilesSectionName = "LogFiles";

    public static void AddCustomLogging(this WebApplicationBuilder builder)
    {
        builder.Host.UseSerilog((context, configuration) =>
        {
            configuration.ReadFrom.Configuration(context.Configuration);

            // Ghi riêng log của một nhóm logger (theo namespace/tên class) ra file, vd để soi nội dung gửi
            // sang hệ thống ngoài mà không phải lọc trong log chung. Đường dẫn tương đối tính từ content root.
            var sinks = context.Configuration.GetSection(LogFilesSectionName).Get<SourceLogFile[]>() ?? [];
            foreach (var sink in sinks.Where(s => !string.IsNullOrWhiteSpace(s.Source) && !string.IsNullOrWhiteSpace(s.Path)))
            {
                var path = Path.IsPathRooted(sink.Path)
                    ? sink.Path
                    : Path.Combine(context.HostingEnvironment.ContentRootPath, sink.Path);
                configuration.WriteTo.Logger(sub => sub
                    .Filter.ByIncludingOnly(Matching.FromSource(sink.Source))
                    .WriteTo.File(path, rollingInterval: RollingInterval.Day, retainedFileCountLimit: sink.RetainedFileCount));
            }
        });
    }

    private sealed class SourceLogFile
    {
        public string Source { get; set; } = string.Empty;
        public string Path { get; set; } = string.Empty;
        public int RetainedFileCount { get; set; } = 30;
    }
}
