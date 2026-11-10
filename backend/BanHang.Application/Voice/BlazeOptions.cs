namespace BanHang.Application.Voice;

/// <summary>Cấu hình nhà cung cấp nhận dạng giọng nói Blaze. Token chỉ nằm ở server; app lấy qua endpoint sau khi đăng nhập.</summary>
public sealed class BlazeOptions
{
    public const string SectionName = "Blaze";

    public string? Token { get; set; }
}
