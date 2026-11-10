using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BanHang.Domain.Entities.Identity;

namespace BanHang.Infrastructure.Persistence.Configurations.Identity;

public sealed class PermissionConfiguration : IEntityTypeConfiguration<Permission>
{
    public void Configure(EntityTypeBuilder<Permission> builder)
    {
        builder.ToTable("Permission");
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Key).HasMaxLength(200).IsRequired();
        builder.Property(x => x.DisplayLabel).HasMaxLength(200).IsRequired();
        builder.Property(x => x.GroupName).HasMaxLength(100).IsRequired();
        builder.Property(x => x.ParentKey).HasMaxLength(200);
        builder.Property(x => x.IsMenu).IsRequired();

        builder.HasIndex(x => x.Key).IsUnique();
        builder.HasIndex(x => x.GroupName);
    }
}
