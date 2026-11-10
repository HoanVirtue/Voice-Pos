using System.Net;
using BanHang.BuildingBlocks.Behaviors;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Logging;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Serilog.Events;

namespace BanHang.Tests.Behaviors;

public class LoggingLevelTests
{
    private sealed class CaptureLogger<T> : ILogger<T>
    {
        public List<LogLevel> Levels { get; } = [];
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception,
            Func<TState, Exception?, string> formatter) => Levels.Add(logLevel);
    }

    private sealed record Ping : IRequest<string>;

    private static DefaultHttpContext Ctx(int status) => new() { Response = { StatusCode = status } };

    [Theory]
    [InlineData(200, LogEventLevel.Information)]
    [InlineData(204, LogEventLevel.Information)]
    [InlineData(401, LogEventLevel.Warning)]
    [InlineData(404, LogEventLevel.Warning)]
    [InlineData(503, LogEventLevel.Warning)]
    [InlineData(500, LogEventLevel.Error)]
    public void RequestLogLevel_TheoMaTrangThai(int status, LogEventLevel expected) =>
        Assert.Equal(expected, RequestLogLevel.For(Ctx(status), 1, null));

    [Fact]
    public void RequestLogLevel_CoNgoaiLeChuaXuLy_LaError() =>
        Assert.Equal(LogEventLevel.Error, RequestLogLevel.For(Ctx(200), 1, new InvalidOperationException()));

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized)]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    [InlineData(HttpStatusCode.Conflict)]
    public async Task LoggingBehavior_LoiNghiepVu_KhongGhiError(HttpStatusCode code)
    {
        var logger = new CaptureLogger<LoggingBehavior<Ping, string>>();
        var behavior = new LoggingBehavior<Ping, string>(logger);

        await Assert.ThrowsAsync<CustomException>(() =>
            behavior.Handle(new Ping(), () => throw new CustomException("x", code), default));

        Assert.DoesNotContain(LogLevel.Error, logger.Levels);
        Assert.Contains(LogLevel.Warning, logger.Levels);
    }

    [Fact]
    public async Task LoggingBehavior_LoiBatNgo_VanGhiError()
    {
        var logger = new CaptureLogger<LoggingBehavior<Ping, string>>();
        var behavior = new LoggingBehavior<Ping, string>(logger);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            behavior.Handle(new Ping(), () => throw new InvalidOperationException(), default));

        Assert.Contains(LogLevel.Error, logger.Levels);
    }
}
