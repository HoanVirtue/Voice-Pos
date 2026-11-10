using BanHang.SharedKernel.Storage;
using MediatR;

namespace BanHang.Application.Files.Queries;

public sealed record GetFileContentQuery(string ObjectPath) : IRequest<StoredFile>;
