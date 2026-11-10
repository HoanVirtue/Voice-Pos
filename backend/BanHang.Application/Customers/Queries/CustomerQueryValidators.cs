using FluentValidation;

namespace BanHang.Application.Customers.Queries;

public sealed class GetCustomersQueryValidator : AbstractValidator<GetCustomersQuery>
{
    public GetCustomersQueryValidator()
    {
        RuleFor(x => x.PageIndex).GreaterThanOrEqualTo(1).WithMessage("Số trang phải từ 1 trở lên.");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 500).WithMessage("Số dòng mỗi trang phải từ 1 đến 500.");
    }
}
