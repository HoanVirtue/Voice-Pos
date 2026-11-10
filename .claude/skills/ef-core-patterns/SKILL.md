---
name: ef-core-patterns
description: Entity Framework Core 8 patterns for the Nail Booking SQL Server microservices. Covers entity base classes, multi-tenant global filters, soft delete, Mapster projection, migration workflow, DbContext configuration, and SQL Server-specific optimizations. Use when creating entities, writing migrations, configuring DbContext, or optimizing EF Core queries.
---

# EF Core 8 Patterns — Nail Booking

Complete EF Core patterns for BookingService and PortalService.

## Entity Base Classes

```csharp
// AuditableEntity — base for all entities with auditing
public abstract class AuditableEntity
{
    public Guid Id { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public DateTimeOffset? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
    public bool IsDeleted { get; set; }
}

// TenantEntity — all domain entities that belong to a tenant
public abstract class TenantEntity : AuditableEntity
{
    public Guid TenantId { get; set; }
    public virtual Tenant Tenant { get; set; } = null!;
}
```

## Entity Implementation

```csharp
public class BookingManagement : TenantEntity
{
    public string Code { get; set; } = string.Empty;
    public BookingStatus Status { get; set; }
    public DateTimeOffset BookingDate { get; set; }
    public string? Note { get; set; }

    // Navigation properties — ALWAYS virtual (enables proxy + eager/lazy loading)
    public virtual ICollection<BookingManagement_Service> Services { get; set; } = [];
    public virtual BookingManagement_Customer? Customer { get; set; }
    public virtual BookingManagement_Payment? Payment { get; set; }

    // Foreign keys (explicit, no shadow properties)
    public Guid? CustomerId { get; set; }
}

// Join table (many-to-many)
public class BookingManagement_Service : AuditableEntity
{
    public Guid BookingManagementId { get; set; }
    public Guid ServiceManagementId { get; set; }
    public Guid? StaffId { get; set; }
    public int Duration { get; set; }

    public virtual BookingManagement BookingManagement { get; set; } = null!;
    public virtual ServiceManagement ServiceManagement { get; set; } = null!;
}
```

## DbContext Configuration

```csharp
public class BookingDbContext : DbContext, IBookingDbContext
{
    private readonly ICurrentUserProvider _currentUser;

    public BookingDbContext(
        DbContextOptions<BookingDbContext> options,
        ICurrentUserProvider currentUser)
        : base(options)
    {
        _currentUser = currentUser;
    }

    // DbSets — PascalCase, join tables use underscore
    public DbSet<BookingManagement> BookingManagement { get; set; }
    public DbSet<BookingManagement_Service> BookingManagement_Service { get; set; }
    public DbSet<Customer> Customer { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Apply all entity configurations from assembly
        builder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());

        // Schema prefix (dev vs production)
        var schema = GetSchema();
        builder.HasDefaultSchema(schema);

        // Global filters per entity
        ConfigureBookingManagement(builder);
        ConfigureCustomer(builder);
    }

    private void ConfigureBookingManagement(ModelBuilder builder)
    {
        builder.Entity<BookingManagement>(entity =>
        {
            // Soft delete + tenant filter
            entity.HasQueryFilter(e =>
                !e.IsDeleted && e.TenantId == _currentUser.TenantId);

            // Indexes
            entity.HasIndex(e => e.TenantId);
            entity.HasIndex(e => new { e.TenantId, e.BookingDate });
            entity.HasIndex(e => new { e.TenantId, e.Status, e.IsDeleted });
        });
    }

    private string GetSchema() =>
        Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") == "Production"
            ? "BookingServicePro"
            : "BookingService";
}
```

## Interface for Testability

```csharp
// Application layer references interface, not concrete DbContext
public interface IBookingDbContext
{
    DbSet<BookingManagement> BookingManagement { get; }
    DbSet<Customer> Customer { get; }
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
```

## Mapster Configuration

```csharp
// BuildingBlock/Mapster/BookingMappingConfig.cs
public class BookingMappingConfig : IRegister
{
    public void Register(TypeAdapterConfig config)
    {
        // Entity → Model (projection-safe)
        config.NewConfig<BookingManagement, BookingManagementModel>()
            .Map(dest => dest.CustomerName,
                src => src.Customer != null ? src.Customer.Name : null)
            .Map(dest => dest.ServiceCount,
                src => src.Services.Count);

        // Model → Entity (for create/update)
        config.NewConfig<UpdateBookingCustomerModel, BookingManagement>()
            .Ignore(dest => dest.Id)           // Set in handler
            .Ignore(dest => dest.CreatedAt)    // Set in handler
            .Ignore(dest => dest.TenantId);    // From token, not model
    }
}

// Registration in DI
services.AddMapster(); // or TypeAdapterConfig.GlobalSettings.Scan(assembly)
```

## Query Patterns

### Prefer BuildingBlock extensions over hand-rolled LINQ

Before writing raw `Skip`/`Take`/manual sort logic on an `IQueryable`, check `BuildingBlock` for an existing extension first (e.g. `BuildingBlock/Paginated/Extensions.cs` → `ToPagedAsync`). If a matching extension exists, use it — only fall back to writing `Skip`/`Take`/`OrderBy` by hand when no BuildingBlock extension covers the case. This keeps paging/sorting logic (page-size defaults, `IPaginatedQuery` sort-by-column support, etc.) in one place instead of re-implemented per query.

This does **not** apply to unrelated in-memory chunking (e.g. `list.Skip(i).Take(batchSize)` to batch a list of IDs for background processing) — that's plain LINQ-to-Objects batching, not DB paging, and `ToPagedAsync` doesn't apply there.

### Paginated Query
```csharp
var query = _context.BookingManagement
    .AsNoTracking()
    .Where(x => x.TenantId == tenantId); // EF global filter may handle this

var total = await query.CountAsync(ct);
var items = await query
    .OrderByDescending(x => x.BookingDate)
    .ProjectToType<BookingManagementModel>() // SQL-level projection
    .ToPagedAsync(pageIndex, pageSize, ct);  // BuildingBlock extension — don't hand-roll Skip/Take
```

### Single Item
```csharp
var entity = await _context.BookingManagement
    .AsNoTracking()
    .Include(x => x.Services)
    .FirstOrDefaultAsync(x => x.Id == id, ct)
    ?? throw new NotFoundException(nameof(BookingManagement), id);
```

### Admin Query (bypass tenant filter)
```csharp
// Explicitly documented admin operation
var allTenantBookings = await _context.BookingManagement
    .IgnoreQueryFilters()  // bypass soft-delete + tenant filter
    .AsNoTracking()
    .Where(x => !x.IsDeleted) // manually filter deleted
    .ProjectToType<BookingManagementModel>()
    .ToListAsync(ct);
```

## Migration Workflow

```powershell
# Create migration
dotnet ef migrations add [MigrationName] `
    --project [ServiceName] `
    --startup-project [ServiceName].WebApi `
    --output-dir Migrations

# Review generated file in [ServiceName]/Migrations/

# Apply to DB
dotnet ef database update `
    --project [ServiceName] `
    --startup-project [ServiceName].WebApi

# Generate SQL script (for review before production)
dotnet ef migrations script `
    --project [ServiceName] `
    --startup-project [ServiceName].WebApi `
    --output migration.sql

# List migrations
dotnet ef migrations list `
    --project [ServiceName] `
    --startup-project [ServiceName].WebApi

# Rollback to previous migration
dotnet ef database update [PreviousMigrationName] `
    --project [ServiceName] `
    --startup-project [ServiceName].WebApi
```

### Migration Naming
`[Action]_[Entity]_[Description]`
- `Add_BookingManagement_Note`
- `Add_Index_BookingManagement_TenantId_Status`
- `Remove_Staff_DeprecatedField`
- `Create_CustomerGroup`

### Safe Migration Checklist
- [ ] Generated migration reviewed (no unexpected changes)
- [ ] New columns are nullable or have default values
- [ ] Indexes added for new filter columns
- [ ] SQL script generated and reviewed for large tables
- [ ] Migration applied to staging before production

## SaveChanges Auditing (automatic)

```csharp
// Override SaveChangesAsync to auto-set audit fields
public override async Task<int> SaveChangesAsync(CancellationToken ct = default)
{
    var entries = ChangeTracker.Entries<AuditableEntity>();
    var now = DateTimeOffset.UtcNow;
    var userId = _currentUser.UserId.ToString();

    foreach (var entry in entries)
    {
        if (entry.State == EntityState.Added)
        {
            entry.Entity.CreatedAt = now;
            entry.Entity.CreatedBy = userId;
        }
        if (entry.State == EntityState.Modified)
        {
            entry.Entity.UpdatedAt = now;
            entry.Entity.UpdatedBy = userId;
        }
    }

    return await base.SaveChangesAsync(ct);
}
```

## Soft Delete Pattern

```csharp
// Delete command — sets IsDeleted = true, never physically deletes
public async Task<UpdateModel> Handle(DeleteCommand request, CancellationToken ct)
{
    var entity = await _context.BookingManagement
        .FirstOrDefaultAsync(x => x.Id == request.Id, ct)
        ?? throw new NotFoundException(nameof(BookingManagement), request.Id);

    entity.IsDeleted = true;
    entity.UpdatedAt = DateTimeOffset.UtcNow;
    entity.UpdatedBy = _currentUser.UserId.ToString();

    await _context.SaveChangesAsync(ct);
    return entity.Adapt<UpdateModel>();
}
```

## Reference Documentation
- `references/ef_core_guide.md` — Performance, migrations, configuration details
