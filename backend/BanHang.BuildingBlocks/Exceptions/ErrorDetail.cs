namespace BanHang.BuildingBlocks.Exceptions;

public sealed class ErrorDetail
{
    public required string Message { get; init; }
    public IReadOnlyCollection<string>? Errors { get; init; }
}
