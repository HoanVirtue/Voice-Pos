using BanHang.Domain.Entities.Customers;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BanHang.Infrastructure.Persistence.Configurations.Customers;

public sealed class CustomerConfiguration : IEntityTypeConfiguration<Customer>
{
    public void Configure(EntityTypeBuilder<Customer> builder)
    {
        builder.ToTable("Customer");
        builder.HasKey(x => x.Id);

        // Id do client sinh (UUID) — server không tự sinh, kể cả khi Guid.Empty phải bị chặn ở tầng validate.
        builder.Property(x => x.Id).ValueGeneratedNever();

        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Alias).HasMaxLength(100);
        builder.Property(x => x.Phone).HasMaxLength(30);
        builder.Property(x => x.Note).HasMaxLength(1000);
        builder.Property(x => x.UpdatedAt).IsRequired();
        builder.Property(x => x.ConcurrencyStamp).IsConcurrencyToken().HasMaxLength(40).IsRequired();

        // Kéo thay đổi cho app: WHERE UpdatedAt > @since ORDER BY UpdatedAt.
        builder.HasIndex(x => x.UpdatedAt);
        builder.HasIndex(x => x.Name);
        builder.HasIndex(x => x.Phone);
    }
}
