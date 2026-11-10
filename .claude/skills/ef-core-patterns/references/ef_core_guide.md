# EF Core 8 Guide — Nail Booking

## DbContext Registration

```csharp
// Program.cs / DI setup
services.AddDbContext<BookingDbContext>(options =>
    options.UseSqlServer(
        connectionString,
        sql => sql.MigrationsAssembly(typeof(BookingDbContext).Assembly.FullName)
                  .CommandTimeout(60)));

// Register interface for testability
services.AddScoped<IBookingDbContext>(sp => sp.GetRequiredService<BookingDbContext>());
```

## Global Query Filter Implementation

```csharp
// DbContext constructor stores tenant context for filter use
public class BookingDbContext : DbContext
{
    private readonly Guid _tenantId;
    private readonly bool _isAdmin;

    public BookingDbContext(
        DbContextOptions<BookingDbContext> options,
        ICurrentUserProvider currentUser)
        : base(options)
    {
        _tenantId = currentUser.IsAdmin ? Guid.Empty : currentUser.TenantId;
        _isAdmin = currentUser.IsAdmin;
    }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        // Applied per entity type — cannot use navigation properties in filters
        builder.Entity<BookingManagement>()
            .HasQueryFilter(e => !e.IsDeleted
                && (_isAdmin || e.TenantId == _tenantId));

        builder.Entity<Customer>()
            .HasQueryFilter(e => !e.IsDeleted
                && (_isAdmin || e.TenantId == _tenantId));
    }
}
```

**Limitation**: Global filters cannot use navigation properties or subqueries — keep them simple.

## Relationship Configuration

```csharp
// One-to-many
builder.Entity<BookingManagement>()
    .HasMany(b => b.Services)
    .WithOne(s => s.BookingManagement)
    .HasForeignKey(s => s.BookingManagementId)
    .OnDelete(DeleteBehavior.Cascade);

// Many-to-many (via explicit join entity)
builder.Entity<Promotion>()
    .HasMany(p => p.Services)
    .WithMany(s => s.Promotions)
    .UsingEntity<Promotion_Service>(
        j => j.HasOne(ps => ps.Service).WithMany().HasForeignKey(ps => ps.ServiceId),
        j => j.HasOne(ps => ps.Promotion).WithMany().HasForeignKey(ps => ps.PromotionId));

// Computed column (SQL Server)
builder.Entity<Customer>()
    .Property(c => c.Code)
    .HasComputedColumnSql("'CUST' + RIGHT('000000' + CAST(Id AS VARCHAR), 6)");
```

## Mapster Projection vs Manual Include

### When to use ProjectToType (preferred)
```csharp
// Direct SQL projection — only fetches needed columns
var models = await query
    .ProjectToType<BookingManagementModel>()
    .ToListAsync();

// Mapster generates SQL like:
// SELECT b.Id, b.Code, b.Status, c.Name as CustomerName
// FROM BookingManagement b
// LEFT JOIN Customer c ON c.Id = b.CustomerId
```

### When to use Include
```csharp
// When you need to MODIFY navigation properties in the handler
var entity = await _context.BookingManagement
    .Include(b => b.Services)  // tracking needed for collection update
    .FirstOrDefaultAsync(b => b.Id == id);

// Update collection
entity.Services.Clear();
entity.Services.AddRange(newServices.Select(s => s.Adapt<BookingManagement_Service>()));
await _context.SaveChangesAsync();
```

## Migrations Best Practices

### Review Generated Migration
Always check auto-generated migration before applying:
```csharp
// Common issues to check:
// 1. Unexpected table drops (verify no entity was accidentally removed)
// 2. Data-destructive column type changes
// 3. Missing indexes that should be added
// 4. Incorrect nullable/required settings
```

### Add Index in Migration (manual)
```csharp
// If HasIndex in OnModelCreating, EF generates this automatically
// For manual additions:
migrationBuilder.CreateIndex(
    name: "IX_BookingManagement_TenantId_Status",
    table: "BookingManagement",
    schema: "BookingService",
    columns: new[] { "TenantId", "Status", "IsDeleted" });
```

### Migration with Data Transform
```csharp
// For columns requiring data backfill
migrationBuilder.AddColumn<string>(
    name: "NewCode",
    table: "BookingManagement",
    nullable: true); // Add nullable first

migrationBuilder.Sql(@"
    UPDATE BookingManagement
    SET NewCode = 'BK' + RIGHT('000000' + CAST(Id AS VARCHAR), 6)
    WHERE NewCode IS NULL"); // Backfill

migrationBuilder.AlterColumn<string>(
    name: "NewCode",
    table: "BookingManagement",
    nullable: false); // Make required after backfill
```

## Performance Patterns

### Split Queries for Large Includes
```csharp
// Default: single query with JOINs (can cause Cartesian explosion)
// For collections, use split query
var bookings = await _context.BookingManagement
    .AsNoTracking()
    .Include(b => b.Services)
    .Include(b => b.Customer)
    .AsSplitQuery()   // generates separate SELECT per Include
    .ToListAsync();
```

### Async Enumeration for Large Result Sets
```csharp
// For very large datasets (export/reporting)
await foreach (var item in _context.BookingManagement
    .AsNoTracking()
    .Where(filter)
    .AsAsyncEnumerable())
{
    await csvWriter.WriteAsync(item);
}
```

## EF Core + Hangfire (same DbContext)

Hangfire and EF Core share the same SQL Server but use different schemas:
```csharp
services.AddHangfire(config => config
    .UseSqlServerStorage(connectionString, new SqlServerStorageOptions
    {
        SchemaName = environment == "Production" ? "HangfirePro" : "Hangfire",
    }));
```

The `BookingDbContext` migrations do NOT include Hangfire tables — they're managed separately by Hangfire's schema installer.
