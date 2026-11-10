using Microsoft.AspNetCore.Http;
using Serilog.Events;

namespace BanHang.BuildingBlocks.Logging;

/// <summary>Mức log cho dòng "HTTP ... responded ..." theo mã trạng thái cuối cùng.</summary>
public static class RequestLogLevel
{
    public static LogEventLevel For(HttpContext http, double elapsedMs, Exception? ex)
    {
        if (ex is not null) return LogEventLevel.Error;
        var status = http.Response.StatusCode;
        if (status >= 500) return status == StatusCodes.Status500InternalServerError ? LogEventLevel.Error : LogEventLevel.Warning;
        return status >= 400 ? LogEventLevel.Warning : LogEventLevel.Information;
    }
}
