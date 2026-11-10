using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BanHang.Domain.Entities.Identity;

namespace BanHang.Infrastructure.Persistence.Configurations.Identity;

public sealed class RolePermissionConfiguration : IEntityTypeConfiguration<RolePermission>
{
    public void Configure(EntityTypeBuilder<RolePermission> builder)
    {
        builder.ToTable("RolePermission");
        builder.HasKey(x => x.Id);

        builder.Property(x => x.RoleId).IsRequired();
        builder.Property(x => x.UserId).IsRequired();
        builder.Property(x => x.PermissionKey).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Allow).IsRequired();

        builder.HasIndex(x => new { x.RoleId, x.UserId, x.PermissionKey })
            .IsUnique();
        builder.HasIndex(x => x.UserId);

        builder.HasOne<Role>()
            .WithMany()
            .HasForeignKey(x => x.RoleId)
            .OnDelete(DeleteBehavior.Cascade);

        // Cố ý KHÔNG đặt khoá ngoại sang Permission: catalog được seed lại mỗi lần khởi động và
        // PermissionCatalogSeeder không xoá key cũ, nên ràng buộc cứng ở đây chỉ tạo rủi ro vỡ dữ
        // liệu khi đổi tên quyền mà không mang lại gì thêm.
        builder.HasIndex(x => x.PermissionKey);
    }
}
