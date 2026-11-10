using BanHang.Domain.Entities.Batches;
using BanHang.Domain.Entities.DaySettlements;
using BanHang.Domain.Entities.Products;
using BanHang.Domain.Entities.Transactions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BanHang.Infrastructure.Persistence.Configurations.Sales;

public sealed class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.ToTable("Product");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();

        builder.Property(x => x.Name).HasMaxLength(100).IsRequired();
        builder.Property(x => x.Alias).HasMaxLength(100);
        builder.Property(x => x.PricePerKg).IsRequired();
        builder.Property(x => x.UpdatedAt).IsRequired();
        builder.Property(x => x.ConcurrencyStamp).IsConcurrencyToken().HasMaxLength(40).IsRequired();

        builder.HasIndex(x => x.UpdatedAt);
        builder.HasIndex(x => x.Name);
    }
}

public sealed class BatchConfiguration : IEntityTypeConfiguration<Batch>
{
    public void Configure(EntityTypeBuilder<Batch> builder)
    {
        builder.ToTable("Batch");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();

        builder.Property(x => x.Date).IsRequired();
        builder.Property(x => x.Note).HasMaxLength(1000);
        builder.Property(x => x.UpdatedAt).IsRequired();
        builder.Property(x => x.ConcurrencyStamp).IsConcurrencyToken().HasMaxLength(40).IsRequired();

        builder.HasIndex(x => x.UpdatedAt);
        builder.HasIndex(x => x.Date);
    }
}

public sealed class TransactionConfiguration : IEntityTypeConfiguration<Transaction>
{
    public void Configure(EntityTypeBuilder<Transaction> builder)
    {
        builder.ToTable("Transaction");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();

        builder.Property(x => x.Type).HasConversion<string>().HasMaxLength(20).IsRequired();
        builder.Property(x => x.OccurredAt).IsRequired();
        builder.Property(x => x.RawText).HasMaxLength(1000);
        builder.Property(x => x.Note).HasMaxLength(1000);
        builder.Property(x => x.UpdatedAt).IsRequired();
        builder.Property(x => x.ConcurrencyStamp).IsConcurrencyToken().HasMaxLength(40).IsRequired();

        // Không có khóa ngoại: app đẩy offline có thể tới thứ tự bất kỳ; báo cáo nối theo Id khi đọc.
        builder.HasIndex(x => x.UpdatedAt);
        builder.HasIndex(x => x.OccurredAt);
        builder.HasIndex(x => new { x.CustomerId, x.Type });
        builder.HasIndex(x => x.BatchId);
    }
}

public sealed class DaySettlementConfiguration : IEntityTypeConfiguration<DaySettlement>
{
    public void Configure(EntityTypeBuilder<DaySettlement> builder)
    {
        builder.ToTable("DaySettlement");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Id).ValueGeneratedNever();

        builder.Property(x => x.Date).IsRequired();
        builder.Property(x => x.Note).HasMaxLength(1000);
        builder.Property(x => x.UpdatedAt).IsRequired();
        builder.Property(x => x.ConcurrencyStamp).IsConcurrencyToken().HasMaxLength(40).IsRequired();

        // Mỗi ngày một bản ghi chưa xóa: MySQL không có unique index có điều kiện (loại bản xóa mềm), nên việc chặn trùng ngày
        // do UpsertDaySettlementCommandHandler kiểm tra (409); ở DB chỉ đánh index thường để tra cứu nhanh.
        builder.HasIndex(x => x.Date);
        builder.HasIndex(x => x.UpdatedAt);
    }
}
