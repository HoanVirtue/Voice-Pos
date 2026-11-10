using BanHang.BuildingBlocks.Exceptions;
using BanHang.SharedKernel.Storage;
using MediatR;

namespace BanHang.Application.Files.Queries;

public sealed class GetFileContentQueryHandler(IFileStorageService fileStorageService)
    : IRequestHandler<GetFileContentQuery, StoredFile>
{
    public async Task<StoredFile> Handle(GetFileContentQuery request, CancellationToken cancellationToken) =>
        await fileStorageService.OpenReadAsync(request.ObjectPath, cancellationToken)
        ?? throw new NotFoundException("File", request.ObjectPath);
}
