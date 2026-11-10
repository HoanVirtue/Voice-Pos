using Microsoft.EntityFrameworkCore;

namespace BanHang.BuildingBlocks.Exceptions;

/// <summary>
/// Lưu vấp unique index/constraint (MySQL lỗi 1062 - Duplicate entry): dữ liệu trùng với một bản ghi đã có, thường do
/// kiểm tra trùng ở tầng ứng dụng bị bỏ sót hoặc hai request ghi cùng lúc. Middleware trả 409 thay vì 500.
/// Giữ nguyên exception gốc của driver trong <see cref="Exception.InnerException"/>.
/// </summary>
public sealed class UniqueConstraintViolationException(string message, Exception driverException)
    : DbUpdateException(message, driverException);
