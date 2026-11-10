using System.Net;
using BanHang.Application.Voice.Dtos;
using BanHang.BuildingBlocks.Exceptions;
using MediatR;
using Microsoft.Extensions.Options;

namespace BanHang.Application.Voice.Queries;

public sealed class GetSttTokenQueryHandler(IOptions<BlazeOptions> options)
    : IRequestHandler<GetSttTokenQuery, SttTokenDto>
{
    public Task<SttTokenDto> Handle(GetSttTokenQuery request, CancellationToken cancellationToken)
    {
        var token = options.Value.Token;
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new CustomException(
                "Server chưa cấu hình token nhận dạng giọng nói (Blaze:Token).", HttpStatusCode.ServiceUnavailable);
        }

        return Task.FromResult(new SttTokenDto("blaze", token));
    }
}
