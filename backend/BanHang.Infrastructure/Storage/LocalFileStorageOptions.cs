namespace BanHang.Infrastructure.Storage;

public sealed class LocalFileStorageOptions
{
    public const string SectionName = "FileStorage";

    /// <summary>Thư mục gốc lưu file; đường dẫn tương đối tính từ thư mục chạy app. Mặc định <c>./data/files</c>.</summary>
    public string RootPath { get; set; } = "./data/files";

    /// <summary>Đường dẫn API trả cho client để tải file (ghép thêm <c>?path=...</c>).</summary>
    public string DownloadRoute { get; set; } = "/api/v1/Files/download";
}
