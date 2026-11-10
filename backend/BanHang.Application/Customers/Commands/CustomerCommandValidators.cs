using FluentValidation;

namespace BanHang.Application.Customers.Commands;

public sealed partial class UpsertCustomerCommandValidator : AbstractValidator<UpsertCustomerCommand>
{
    public UpsertCustomerCommandValidator()
    {
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã khách hàng không hợp lệ.");

        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Tên khách hàng không được để trống.")
            .MaximumLength(200).WithMessage("Tên khách hàng tối đa 200 ký tự.");

        RuleFor(x => x.Alias)
            .MaximumLength(100).WithMessage("Tên gọi tối đa 100 ký tự.");

        RuleFor(x => x.Phone)
            .MaximumLength(30).WithMessage("Số điện thoại tối đa 30 ký tự.")
            .Matches(PhonePattern()).WithMessage("Số điện thoại chỉ gồm chữ số, dấu cách và các ký tự + - ( ) .")
            .When(x => !string.IsNullOrEmpty(x.Phone));

        RuleFor(x => x.Note)
            .MaximumLength(1000).WithMessage("Ghi chú tối đa 1000 ký tự.");
    }

    [System.Text.RegularExpressions.GeneratedRegex(@"^[0-9+\-\s().]+$")]
    private static partial System.Text.RegularExpressions.Regex PhonePattern();
}

public sealed class DeleteCustomerCommandValidator : AbstractValidator<DeleteCustomerCommand>
{
    public DeleteCustomerCommandValidator() =>
        RuleFor(x => x.Id).NotEqual(Guid.Empty).WithMessage("Mã khách hàng không hợp lệ.");
}
