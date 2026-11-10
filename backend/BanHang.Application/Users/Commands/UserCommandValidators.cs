using FluentValidation;

namespace BanHang.Application.Users.Commands;

public sealed class CreateUserCommandValidator : AbstractValidator<CreateUserCommand>
{
    public CreateUserCommandValidator()
    {
        RuleFor(x => x.Username).NotEmpty().MaximumLength(100).WithName("Tên đăng nhập");
        RuleFor(x => x.Password).NotEmpty().MinimumLength(8).WithName("Mật khẩu");
        RuleFor(x => x.RoleId).GreaterThan(0).WithName("Vai trò");
        RuleFor(x => x.DisplayName).MaximumLength(100).WithName("Tên hiển thị");
    }
}

public sealed class UpdateUserCommandValidator : AbstractValidator<UpdateUserCommand>
{
    public UpdateUserCommandValidator()
    {
        RuleFor(x => x.Id).GreaterThan(0);
        RuleFor(x => x.RoleId).GreaterThan(0).WithName("Vai trò");
        RuleFor(x => x.DisplayName).MaximumLength(100).WithName("Tên hiển thị");
    }
}

public sealed class DeleteUserCommandValidator : AbstractValidator<DeleteUserCommand>
{
    public DeleteUserCommandValidator() => RuleFor(x => x.Id).GreaterThan(0);
}

public sealed class ResetPasswordCommandValidator : AbstractValidator<ResetPasswordCommand>
{
    public ResetPasswordCommandValidator()
    {
        RuleFor(x => x.UserId).GreaterThan(0).WithName("Mã tài khoản");
        RuleFor(x => x.NewPassword).NotEmpty().MinimumLength(8).WithName("Mật khẩu mới");
    }
}

public sealed class SetUserStatusCommandValidator : AbstractValidator<SetUserStatusCommand>
{
    public SetUserStatusCommandValidator() => RuleFor(x => x.Id).GreaterThan(0);
}

public sealed class ChangeMyPasswordCommandValidator : AbstractValidator<ChangeMyPasswordCommand>
{
    public ChangeMyPasswordCommandValidator()
    {
        RuleFor(x => x.CurrentPassword).NotEmpty().WithName("Mật khẩu hiện tại");
        RuleFor(x => x.NewPassword).NotEmpty().MinimumLength(8).WithName("Mật khẩu mới");
    }
}
