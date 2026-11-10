using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BanHang.Domain.Entities.Identity;

namespace BanHang.Infrastructure.Persistence.Configurations.Identity;

public sealed class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> builder)
    {
        builder.ToTable("Role");
        builder.HasKey(x => x.Id);

        builder.Property(x => x.Key).HasMaxLength(50).IsRequired();
        builder.Property(x => x.DisplayName).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Description).HasMaxLength(500);
        builder.Property(x => x.IsFullBypass).IsRequired();
        builder.Property(x => x.IsSystem).IsRequired();
        builder.Property(x => x.SortOrder).IsRequired();
        builder.Property(x => x.Status).IsRequired();

        builder.HasIndex(x => x.Key).IsUnique();
    }
}
