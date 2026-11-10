using MediatR;
using BanHang.SharedKernel.Storage;

namespace BanHang.Application.Files.Commands;

public sealed class DeleteFileCommandHandler(IFileStorageService fileStorageService) : IRequestHandler<DeleteFileCommand>
{
    public Task Handle(DeleteFileCommand request, CancellationToken cancellationToken)
    {
        return fileStorageService.DeleteAsync(request.ObjectPath, cancellationToken);
    }
}
