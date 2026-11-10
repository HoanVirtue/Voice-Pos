using System.Diagnostics;
using BanHang.BuildingBlocks.Exceptions;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BanHang.BuildingBlocks.Behaviors;

public sealed class LoggingBehavior<TRequest, TResponse>(ILogger<LoggingBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var requestName = typeof(TRequest).Name;
        var stopwatch = Stopwatch.StartNew();

        logger.LogInformation("Handling {Request}", requestName);
        try
        {
            var response = await next();
            logger.LogInformation("Handled {Request} in {ElapsedMs}ms", requestName, stopwatch.ElapsedMilliseconds);
            return response;
        }
        catch (Exception ex) when (ex is CustomException or ValidationException)
        {
            // Lỗi nghiệp vụ đã biết (401, 404, 409, 503, 400...): client nhận mã tương ứng, không phải sự cố hệ thống.
            logger.LogWarning("Handling {Request} rejected after {ElapsedMs}ms: {Reason}", requestName, stopwatch.ElapsedMilliseconds, ex.Message);
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed handling {Request} after {ElapsedMs}ms", requestName, stopwatch.ElapsedMilliseconds);
            throw;
        }
    }
}
