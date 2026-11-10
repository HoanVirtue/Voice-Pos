namespace BanHang.SharedKernel.Storage;

/// <summary>
/// Cổng lưu file mà tầng Application phụ thuộc; Infrastructure cung cấp bản cài đặt cụ thể (mặc định: ổ đĩa cục bộ).
/// Dùng Stream để SharedKernel không phải tham chiếu ASP.NET Core (không có IFormFile ở đây).
/// </summary>
public interface IFileStorageService
{
    /// <summary>Lưu nội dung vào thư mục con <paramref name="folder"/> và trả về đường dẫn tương đối của file đã lưu.</summary>
    Task<string> UploadAsync(Stream content, string fileName, string folder, CancellationToken cancellationToken = default);

    /// <summary>Trả về URL (tương đối hoặc tuyệt đối) mà client dùng để tải file về.</summary>
    Task<string> GetPresignedUrlAsync(string objectPath, CancellationToken cancellationToken = default);

    /// <summary>Mở luồng đọc file; trả <c>null</c> nếu file không tồn tại.</summary>
    Task<StoredFile?> OpenReadAsync(string objectPath, CancellationToken cancellationToken = default);

    Task DeleteAsync(string objectPath, CancellationToken cancellationToken = default);
}

public sealed record StoredFile(Stream Content, string ContentType, string FileName);
