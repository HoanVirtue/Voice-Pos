using System.Net;
using FluentValidation;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BanHang.BuildingBlocks.Exceptions;

public sealed class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task Invoke(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (ValidationException ex)
        {
            logger.LogWarning(ex, "Validation failed for {Path}", context.Request.Path);
            await WriteAsync(context, HttpStatusCode.BadRequest, new ErrorDetail
            {
                Message = "Dữ liệu không hợp lệ.",
                Errors = ex.Errors.Select(e => e.ErrorMessage).ToArray()
            });
        }
        catch (CustomException ex)
        {
            logger.LogWarning(ex, "Request to {Path} failed", context.Request.Path);
            await WriteAsync(context, ex.StatusCode, new ErrorDetail { Message = ex.Message });
        }
        catch (DbUpdateConcurrencyException ex)
        {
            // Người khác đã lưu bản ghi này trước (đơn đã được duyệt/sửa/hủy, sổ phép vừa đổi...).
            logger.LogWarning(ex, "Concurrency conflict for {Path}", context.Request.Path);
            await WriteAsync(context, HttpStatusCode.Conflict, new ErrorDetail
            {
                Message = "Dữ liệu vừa được người khác thay đổi. Vui lòng tải lại và thử lại."
            });
        }
        catch (UniqueConstraintViolationException ex)
        {
            // Trùng khóa duy nhất mà tầng ứng dụng chưa chặn trước (hoặc hai request ghi cùng lúc).
            logger.LogWarning(ex, "Unique constraint violation for {Path}", context.Request.Path);
            await WriteAsync(context, HttpStatusCode.Conflict, new ErrorDetail
            {
                Message = "Dữ liệu bị trùng với một bản ghi đã có. Vui lòng kiểm tra lại hoặc tải lại trang."
            });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception for {Path}", context.Request.Path);
            await WriteAsync(context, HttpStatusCode.InternalServerError, new ErrorDetail
            {
                Message = "Đã có lỗi xảy ra, vui lòng thử lại sau."
            });
        }
    }

    private static Task WriteAsync(HttpContext context, HttpStatusCode statusCode, ErrorDetail error)
    {
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;
        return context.Response.WriteAsJsonAsync(error);
    }
}
