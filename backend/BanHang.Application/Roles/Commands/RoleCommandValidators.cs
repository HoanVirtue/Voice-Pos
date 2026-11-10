using System.Text.RegularExpressions;
using FluentValidation;

namespace BanHang.Application.Roles.Commands;

public sealed partial class CreateRoleCommandValidator : AbstractValidator<CreateRoleCommand>
{
    public CreateRoleCommandValidator()
    {
        RuleFor(x => x.Key).NotEmpty().MaximumLength(50).Matches(KeyPattern()).WithMessage("Mã vai trò chỉ gồm chữ cái không dấu, số và dấu gạch dưới, bắt đầu bằng chữ cái.").WithName("Mã vai trò");
        RuleFor(x => x.DisplayName).NotEmpty().MaximumLength(200).WithName("Tên vai trò");
        RuleFor(x => x.Description).MaximumLength(500).WithName("Mô tả");
        RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0);
    }

    [GeneratedRegex("^[A-Za-z][A-Za-z0-9_]*$")]
    private static partial Regex KeyPattern();
}
public sealed class UpdateRoleCommandValidator : AbstractValidator<UpdateRoleCommand>
{ public UpdateRoleCommandValidator() { RuleFor(x => x.Id).GreaterThan(0); RuleFor(x => x.DisplayName).NotEmpty().MaximumLength(200).WithName("Tên vai trò"); RuleFor(x => x.Description).MaximumLength(500).WithName("Mô tả"); RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0); } }
public sealed class DeleteRoleCommandValidator : AbstractValidator<DeleteRoleCommand>
{ public DeleteRoleCommandValidator() => RuleFor(x => x.Id).GreaterThan(0); }
public sealed class SetRoleStatusCommandValidator : AbstractValidator<SetRoleStatusCommand>
{ public SetRoleStatusCommandValidator() => RuleFor(x => x.Id).GreaterThan(0); }
