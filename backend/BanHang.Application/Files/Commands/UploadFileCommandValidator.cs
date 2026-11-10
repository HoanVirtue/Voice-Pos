using FluentValidation;

namespace BanHang.Application.Files.Commands;

public sealed partial class UploadFileCommandValidator : AbstractValidator<UploadFileCommand>
{
    public UploadFileCommandValidator()
    {
        RuleFor(x => x.FileName).NotEmpty().WithMessage("Tên file không được để trống.");

        RuleFor(x => x.Folder)
            .NotEmpty().WithMessage("Thư mục lưu trữ không được để trống.")
            .Matches(FolderPattern()).WithMessage("Thư mục chỉ gồm chữ cái không dấu, số, dấu gạch ngang/gạch dưới và dấu '/'.")
            .Must(folder => !folder.Contains("..")).WithMessage("Thư mục không hợp lệ.");
    }

    [System.Text.RegularExpressions.GeneratedRegex(@"^[A-Za-z0-9_\-/]+$")]
    private static partial System.Text.RegularExpressions.Regex FolderPattern();
}
