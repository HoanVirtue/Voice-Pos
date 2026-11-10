using BanHang.SharedKernel.Storage;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BanHang.Infrastructure.Storage;

/// <summary>
/// Lưu file trên ổ đĩa cục bộ. Đường dẫn trả về dạng tương đối "folder/guid.ext" (dùng dấu '/'),
/// luôn được kiểm tra nằm trong thư mục gốc để chặn path traversal.
/// </summary>
public sealed class LocalFileStorageService : IFileStorageService
{
    private static readonly FileExtensionContentTypeProvider ContentTypeProvider = new();

    private readonly string _root;
    private readonly string _downloadRoute;
    private readonly ILogger<LocalFileStorageService> _logger;

    public LocalFileStorageService(IOptions<LocalFileStorageOptions> options, ILogger<LocalFileStorageService> logger)
    {
        _logger = logger;
        _root = Path.GetFullPath(options.Value.RootPath);
        _downloadRoute = options.Value.DownloadRoute;
        Directory.CreateDirectory(_root);
    }

    public async Task<string> UploadAsync(Stream content, string fileName, string folder, CancellationToken cancellationToken = default)
    {
        var safeFolder = folder.Trim().Trim('/', '\\');
        var objectName = $"{Guid.NewGuid()}{Path.GetExtension(fileName)}";
        var objectPath = string.IsNullOrEmpty(safeFolder) ? objectName : $"{safeFolder}/{objectName}";

        var fullPath = ResolvePath(objectPath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);

        await using (var target = new FileStream(fullPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        {
            await content.CopyToAsync(target, cancellationToken);
        }

        _logger.LogInformation("Đã lưu file {ObjectPath}", objectPath);
        return objectPath;
    }

    public Task<string> GetPresignedUrlAsync(string objectPath, CancellationToken cancellationToken = default)
    {
        // File nằm cục bộ nên không có URL ký sẵn: trả về route tải của chính API (cần đăng nhập).
        _ = ResolvePath(objectPath);
        return Task.FromResult($"{_downloadRoute}?path={Uri.EscapeDataString(objectPath)}");
    }

    public Task<StoredFile?> OpenReadAsync(string objectPath, CancellationToken cancellationToken = default)
    {
        var fullPath = ResolvePath(objectPath);
        if (!File.Exists(fullPath))
        {
            return Task.FromResult<StoredFile?>(null);
        }

        var stream = new FileStream(fullPath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, useAsync: true);
        var fileName = Path.GetFileName(fullPath);
        var contentType = ContentTypeProvider.TryGetContentType(fileName, out var type) ? type : "application/octet-stream";
        return Task.FromResult<StoredFile?>(new StoredFile(stream, contentType, fileName));
    }

    public Task DeleteAsync(string objectPath, CancellationToken cancellationToken = default)
    {
        var fullPath = ResolvePath(objectPath);
        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }

        return Task.CompletedTask;
    }

    private string ResolvePath(string objectPath)
    {
        var relative = objectPath.Replace('\\', '/').TrimStart('/');
        var fullPath = Path.GetFullPath(Path.Combine(_root, relative));
        var rootWithSeparator = _root.EndsWith(Path.DirectorySeparatorChar) ? _root : _root + Path.DirectorySeparatorChar;

        if (!fullPath.StartsWith(rootWithSeparator, StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Đường dẫn file không hợp lệ.");
        }

        return fullPath;
    }
}
