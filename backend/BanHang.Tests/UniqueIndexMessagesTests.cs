using BanHang.Infrastructure.Persistence;

namespace BanHang.Tests;

public class UniqueIndexMessagesTests
{
    [Theory]
    [InlineData("Duplicate entry 'bo' for key 'User.IX_User_Username'", "Tên đăng nhập đã tồn tại.")]
    [InlineData("Duplicate entry 'bo' for key 'IX_User_Username'", "Tên đăng nhập đã tồn tại.")]
    [InlineData("Duplicate entry 'x' for key 'Customer.PRIMARY'", "Bản ghi này đã tồn tại.")]
    [InlineData("Duplicate entry 'x' for key 'Something.IX_Unknown'", "Dữ liệu bị trùng với bản ghi đã có, vui lòng kiểm tra lại.")]
    [InlineData("lỗi lạ không có tên khóa", "Dữ liệu bị trùng với bản ghi đã có, vui lòng kiểm tra lại.")]
    [InlineData(null, "Dữ liệu bị trùng với bản ghi đã có, vui lòng kiểm tra lại.")]
    public void Resolve_MapsMySqlDuplicateMessage(string? message, string expected) =>
        Assert.Equal(expected, UniqueIndexMessages.Resolve(message));
}
