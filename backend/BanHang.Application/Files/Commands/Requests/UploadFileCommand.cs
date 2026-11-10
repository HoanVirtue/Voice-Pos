using MediatR;

namespace BanHang.Application.Files.Commands;

public sealed record UploadFileCommand(Stream Content, string FileName, string Folder) : IRequest<string>;
