using MediatR;

namespace BanHang.Application.Files.Queries;

public sealed record GetFileDownloadUrlQuery(string ObjectPath) : IRequest<string>;
