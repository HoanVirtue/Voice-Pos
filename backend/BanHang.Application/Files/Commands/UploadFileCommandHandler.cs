using MediatR;
using BanHang.SharedKernel.Storage;

namespace BanHang.Application.Files.Commands;

public sealed class UploadFileCommandHandler(IFileStorageService fileStorageService) : IRequestHandler<UploadFileCommand, string>
{
    public Task<string> Handle(UploadFileCommand request, CancellationToken cancellationToken)
    {
        return fileStorageService.UploadAsync(request.Content, request.FileName, request.Folder, cancellationToken);
    }
}
