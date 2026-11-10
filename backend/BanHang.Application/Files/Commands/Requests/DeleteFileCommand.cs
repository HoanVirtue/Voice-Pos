using MediatR;

namespace BanHang.Application.Files.Commands;

public sealed record DeleteFileCommand(string ObjectPath) : IRequest;
