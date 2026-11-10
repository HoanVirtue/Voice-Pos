using MediatR;
using BanHang.SharedKernel.Storage;

namespace BanHang.Application.Files.Queries;

public sealed class GetFileDownloadUrlQueryHandler(IFileStorageService fileStorageService)
    : IRequestHandler<GetFileDownloadUrlQuery, string>
{
    public Task<string> Handle(GetFileDownloadUrlQuery request, CancellationToken cancellationToken)
    {
        return fileStorageService.GetPresignedUrlAsync(request.ObjectPath, cancellationToken);
    }
}
