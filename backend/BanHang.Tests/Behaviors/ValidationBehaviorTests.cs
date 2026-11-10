using BanHang.Application.Customers.Commands;
using BanHang.BuildingBlocks.Behaviors;
using FluentValidation;

namespace BanHang.Tests.Behaviors;

public class ValidationBehaviorTests
{
    private static ValidationBehavior<UpsertCustomerCommand, string> Create(params IValidator<UpsertCustomerCommand>[] validators) =>
        new(validators);

    [Fact]
    public async Task InvalidRequest_ThrowsValidationException_AndSkipsHandler()
    {
        var behavior = Create(new UpsertCustomerCommandValidator());
        var handlerCalled = false;

        var ex = await Assert.ThrowsAsync<ValidationException>(() => behavior.Handle(
            new UpsertCustomerCommand(Guid.NewGuid(), ""),
            () =>
            {
                handlerCalled = true;
                return Task.FromResult("ok");
            },
            default));

        Assert.False(handlerCalled);
        Assert.Contains(ex.Errors, e => e.ErrorMessage == "Tên khách hàng không được để trống.");
    }

    [Fact]
    public async Task ValidRequest_CallsNext_AndReturnsItsResponse()
    {
        var behavior = Create(new UpsertCustomerCommandValidator());

        var response = await behavior.Handle(
            new UpsertCustomerCommand(Guid.NewGuid(), "Chị Hoa"),
            () => Task.FromResult("done"),
            default);

        Assert.Equal("done", response);
    }

    [Fact]
    public async Task NoValidators_CallsNext()
    {
        var behavior = Create();

        var response = await behavior.Handle(
            new UpsertCustomerCommand(Guid.Empty, ""),
            () => Task.FromResult("done"),
            default);

        Assert.Equal("done", response);
    }

    [Fact]
    public async Task Errors_FromAllValidators_AreAggregated()
    {
        var behavior = Create(new UpsertCustomerCommandValidator(), new ExtraValidator());

        var ex = await Assert.ThrowsAsync<ValidationException>(() => behavior.Handle(
            new UpsertCustomerCommand(Guid.Empty, ""),
            () => Task.FromResult("ok"),
            default));

        Assert.Contains(ex.Errors, e => e.ErrorMessage == "Mã khách hàng không hợp lệ.");
        Assert.Contains(ex.Errors, e => e.ErrorMessage == "Lỗi bổ sung.");
    }

    private sealed class ExtraValidator : AbstractValidator<UpsertCustomerCommand>
    {
        public ExtraValidator() => RuleFor(x => x.Name).Must(_ => false).WithMessage("Lỗi bổ sung.");
    }
}
