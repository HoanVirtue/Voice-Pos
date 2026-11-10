using BanHang.Application.Voice.Dtos;
using MediatR;

namespace BanHang.Application.Voice.Queries;

public sealed record GetSttTokenQuery : IRequest<SttTokenDto>;
