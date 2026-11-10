using System.Net;
using BanHang.BuildingBlocks.Exceptions;
using BanHang.BuildingBlocks.Persistence;
using BanHang.BuildingBlocks.Time;
using BanHang.BuildingBlocks.Web;
using BanHang.SharedKernel.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;
using MySqlConnector;

namespace BanHang.Infrastructure.Persistence;

public sealed class BanHangDbContext(
    DbContextOptions<BanHangDbContext> options,
    ICurrentUser currentUser,
    IDateTimeProvider dateTimeProvider,
    IPublisher publisher)
    : AppDbContextBase(options, currentUser, dateTimeProvider, publisher)
{
    /// <summary>Cấu hình MySQL dùng chung cho runtime và công cụ migration (design-time factory).</summary>
    public static DbContextOptionsBuilder Configure(DbContextOptionsBuilder builder, string? connectionString)
    {
        builder.UseMySql(
            connectionString,
            ServerVersion.Create(new Version(8, 0, 36), Pomelo.EntityFrameworkCore.MySql.Infrastructure.ServerType.MySql),
            mysql => mysql.EnableRetryOnFailure());
        return builder;
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(BanHangDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var insertsStampedEntity = ChangeTracker.Entries<IHasConcurrencyStamp>().Any(e => e.State == EntityState.Added);

        try
        {
            return await base.SaveChangesAsync(cancellationToken);
        }
        // Entity có ConcurrencyStamp bị insert trùng khóa (hai request cùng tạo một Id): coi như xung đột đồng thời để
        // middleware trả 409 — client gửi lại sẽ rơi vào nhánh "đã có" và ra kết quả idempotent.
        catch (DbUpdateException ex) when (insertsStampedEntity
            && ex is not DbUpdateConcurrencyException
            && ex.InnerException is MySqlException { Number: MySqlDuplicateEntry })
        {
            throw new DbUpdateConcurrencyException(
                "Bản ghi vừa được người khác tạo trước (trùng khóa duy nhất).", ex);
        }
        // Mọi unique index khác: quy về 409 kèm câu tiếng Việt tương ứng từng index để người dùng biết trùng ở đâu.
        catch (DbUpdateException ex) when (ex is not DbUpdateConcurrencyException
            && ex.InnerException is MySqlException { Number: MySqlDuplicateEntry } mysqlEx)
        {
            throw new CustomException(UniqueIndexMessages.Resolve(mysqlEx.Message), HttpStatusCode.Conflict);
        }
    }

    /// <summary>Mã lỗi MySQL 1062 (ER_DUP_ENTRY): Duplicate entry '...' for key '...'.</summary>
    private const int MySqlDuplicateEntry = 1062;
}
