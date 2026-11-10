using System.Net;

namespace BanHang.BuildingBlocks.Exceptions;

public class CustomException(string message, HttpStatusCode statusCode = HttpStatusCode.BadRequest)
    : Exception(message)
{
    public HttpStatusCode StatusCode { get; } = statusCode;
}

public sealed class NotFoundException(string entityName, object key)
    : CustomException($"{entityName} với id '{key}' không tồn tại.", HttpStatusCode.NotFound);

public sealed class UnauthorizedException(string message = "Sai tên đăng nhập hoặc mật khẩu.")
    : CustomException(message, HttpStatusCode.Unauthorized);
