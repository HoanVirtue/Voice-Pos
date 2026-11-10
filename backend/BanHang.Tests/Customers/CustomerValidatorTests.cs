using BanHang.Application.Customers.Commands;
using BanHang.Application.Customers.Queries;

namespace BanHang.Tests.Customers;

public class CustomerValidatorTests
{
    private readonly UpsertCustomerCommandValidator _validator = new();

    [Fact]
    public void Valid_Command_Passes()
    {
        var result = _validator.Validate(new UpsertCustomerCommand(Guid.NewGuid(), "Chị Hoa", "Hoa chợ", "+84 901-234-567", "ghi chú"));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Empty_Name_And_Id_Fail_With_Vietnamese_Messages()
    {
        var result = _validator.Validate(new UpsertCustomerCommand(Guid.Empty, "  "));

        var messages = result.Errors.Select(e => e.ErrorMessage).ToList();
        Assert.Contains("Tên khách hàng không được để trống.", messages);
        Assert.Contains("Mã khách hàng không hợp lệ.", messages);
    }

    [Fact]
    public void Phone_With_Letters_Fails()
    {
        var result = _validator.Validate(new UpsertCustomerCommand(Guid.NewGuid(), "A", Phone: "09abc"));

        Assert.Contains(result.Errors, e => e.ErrorMessage.StartsWith("Số điện thoại chỉ gồm"));
    }

    [Theory]
    [InlineData(0, 20)]
    [InlineData(1, 0)]
    [InlineData(1, 501)]
    public void Query_Paging_Out_Of_Range_Fails(int pageIndex, int pageSize)
    {
        var result = new GetCustomersQueryValidator().Validate(
            new GetCustomersQuery { PageIndex = pageIndex, PageSize = pageSize });

        Assert.False(result.IsValid);
    }
}
