# Database Optimization Guide — EF Core + SQL Server

## Core Rules

### Always AsNoTracking on Queries
```csharp
// MANDATORY in all query handlers
var items = await _context.BookingManagement
    .AsNoTracking()
    .Where(x => x.TenantId == tenantId)
    .ToListAsync(ct);
```
Skips change tracker — 10-30% performance improvement on read-heavy endpoints.

### Prefer Mapster Projection Over Include
```csharp
// PREFERRED — projects to DTO directly in SQL
var items = await _context.BookingManagement
    .AsNoTracking()
    .Where(x => x.TenantId == tenantId)
    .ProjectToType<BookingManagementModel>()
    .ToListAsync(ct);

// AVOID — over-fetches all columns, maps in memory
var entities = await _context.BookingManagement
    .Include(x => x.Services).Include(x => x.Customer)
    .ToListAsync(ct);
```

### Always Paginate
```csharp
var total = await query.CountAsync(ct);
var items = await query
    .OrderByDescending(x => x.CreatedAt)
    .Skip((pageIndex - 1) * pageSize)
    .Take(pageSize)
    .ProjectToType<BookingManagementModel>()
    .ToListAsync(ct);
return new PaginatedList<BookingManagementModel>(items, total, pageIndex, pageSize);
```

## Indexing Strategy

### Standard Indexes Per Entity Type
```csharp
// In OnModelCreating for every TenantEntity subclass
entity.HasIndex(e => e.TenantId);

// Soft delete + tenant — very common filter combination
entity.HasIndex(e => new { e.TenantId, e.IsDeleted });

// Date range queries
entity.HasIndex(e => new { e.TenantId, e.BookingDate });

// Status filter
entity.HasIndex(e => new { e.TenantId, e.Status, e.IsDeleted });
```

**Rule**: If a column appears in `WHERE`, `JOIN`, or `ORDER BY` on a large table → add index.
Composite index: order matters — most selective column first.

## Global Query Filters

```csharp
// Defined once in OnModelCreating, automatically applied
modelBuilder.Entity<BookingManagement>()
    .HasQueryFilter(e => !e.IsDeleted && e.TenantId == _currentUser.TenantId);

// Admin bypass — explicit, documented
var archivedItems = _context.BookingManagement
    .IgnoreQueryFilters()    // intentional: admin viewing all tenants
    .Where(e => e.IsDeleted);
```

## Migration Management

### Add Column Workflow
```powershell
# 1. Modify entity
# 2. Generate migration
dotnet ef migrations add Add_[Entity]_[Column] `
    --project [ServiceName] --startup-project [ServiceName].WebApi
# 3. Review generated file in [ServiceName]/Migrations/
# 4. Apply
dotnet ef database update `
    --project [ServiceName] --startup-project [ServiceName].WebApi
```

### Migration Naming Convention
`[Action]_[Entity]_[Column]` — e.g., `Add_BookingManagement_Note`, `Remove_Staff_OldField`

### Schema Conventions
| Environment | Schema Prefix |
|-------------|--------------|
| Development | `BookingService` |
| Production  | `BookingServicePro` |

Join table naming: `[TableA]_[TableB]` — e.g., `BookingManagement_Service`, `Promotion_CustomerGroup`

### Safe vs Risky Migrations
```csharp
// SAFE — adding nullable column
migrationBuilder.AddColumn<string>(name: "Note", table: "BookingManagement", nullable: true);

// RISKY — changing type on populated table
// → Generate SQL, review on staging first:
// dotnet ef migrations script --project ... -o migration.sql
```

## Bulk Operations

```csharp
// EF Core 8 bulk update (no entity load)
await _context.BookingManagement
    .Where(b => b.Status == BookingStatus.Pending && b.BookingDate < cutoff)
    .ExecuteUpdateAsync(s => s
        .SetProperty(b => b.Status, BookingStatus.Cancelled)
        .SetProperty(b => b.UpdatedAt, DateTimeOffset.UtcNow));

// EF Core 8 bulk delete
await _context.BookingManagement
    .Where(b => b.CreatedAt < retentionDate)
    .ExecuteDeleteAsync();
```

## Avoiding N+1 Queries

```csharp
// N+1 problem — each booking triggers another query for services
var bookings = await _context.BookingManagement.ToListAsync();
foreach (var b in bookings)
    _ = b.Services; // lazy load — 1 query per booking = N+1

// Fix — single query via Include
var bookings = await _context.BookingManagement
    .AsNoTracking()
    .Include(b => b.Services)
    .ToListAsync();

// Better fix — Mapster projection handles joins automatically
var models = await _context.BookingManagement
    .AsNoTracking()
    .ProjectToType<BookingManagementModel>()
    .ToListAsync();
```

## Diagnosing Slow Queries

```json
// appsettings.Development.json — log all EF SQL
{
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  }
}
```

Check Seq at http://10.100.1.126:5341 — filter `SourceContext` = `Microsoft.EntityFrameworkCore.Database.Command`, look for commands > 100ms.

## Connection String Tuning

```
Server=10.100.1.126,1433;Database=NailBooking_Testing;
User Id=sa;Password=xxx;TrustServerCertificate=True;
Max Pool Size=100;Connection Timeout=30;Command Timeout=60;
```

- `Max Pool Size=100`: match expected concurrent requests per service
- `Command Timeout=60`: prevent long-running queries from holding connections
