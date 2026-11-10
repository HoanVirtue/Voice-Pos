---
name: senior-backend
description: Backend development skill for the Nail Booking ASP.NET Core 8 microservices. Covers CQRS/MediatR command+query patterns, EF Core entities and migrations, MassTransit messaging, Hangfire jobs, Mapster mapping, multi-tenant filtering, and REST API design. Use when implementing commands, queries, entities, DTOs, controllers, event handlers, or background jobs.
---

# Senior Backend — Nail Booking ASP.NET Core

Complete patterns for ASP.NET Core 8 backend development in this codebase.

## Stack
- **ASP.NET Core 8** — `WebApplication.CreateBuilder`, minimal API + controllers
- **MediatR** — CQRS commands, queries, notifications, pipeline behaviors
- **EF Core 8** — Code-first, SQL Server, global query filters, migrations
- **MassTransit** — RabbitMQ consumers, exponential retry, `IConsumer<T>`
- **Mapster** — DTO↔Domain model mapping
- **Hangfire** — Background/recurring jobs, SQL Server store
- **Serilog** — Structured logging with Seq sink
- **Services**: BookingService (4031), PortalService (4030), StorageService (4035)

## Entity Pattern

```csharp
// Base entity — always extend one of these
public abstract class AuditableEntity
{
    public Guid Id { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string CreatedBy { get; set; }
    public DateTimeOffset? UpdatedAt { get; set; }
    public string? UpdatedBy { get; set; }
    public bool IsDeleted { get; set; }
}

// Multi-tenant entity — all domain entities use this
public abstract class TenantEntity : AuditableEntity
{
    public Guid TenantId { get; set; }
    public virtual Tenant Tenant { get; set; }
}

// Example domain entity
public class BookingManagement : TenantEntity
{
    public string Code { get; set; }
    public BookingStatus Status { get; set; }
    public DateTimeOffset BookingDate { get; set; }

    // Navigation — always virtual for lazy loading support
    public virtual ICollection<BookingManagement_Service> Services { get; set; }
    public virtual BookingManagement_Customer Customer { get; set; }
}
```

## Command Pattern

```csharp
// Model (domain input/output — NOT the DTO)
public class UpdateBookingCustomerModel
{
    public Guid? Id { get; set; }
    public Guid TenantId { get; set; }
    public DateTimeOffset BookingDate { get; set; }
    public List<BookingServiceModel> Services { get; set; }
}

// Command — wraps the model
public class CreateBookingCustomerCommand : IRequest<UpdateBookingCustomerModel>
{
    public UpdateBookingCustomerModel Model { get; }
    public CreateBookingCustomerCommand(UpdateBookingCustomerModel model) => Model = model;
}

// Handler
public class CreateBookingCustomerCommandHandler
    : IRequestHandler<CreateBookingCustomerCommand, UpdateBookingCustomerModel>
{
    private readonly IBookingDbContext _context;
    private readonly ICurrentUserProvider _currentUser;
    private readonly IBackgroundMediatRQueue _queue;

    public async Task<UpdateBookingCustomerModel> Handle(
        CreateBookingCustomerCommand request, CancellationToken ct)
    {
        var model = request.Model;
        model.TenantId = _currentUser.TenantId; // NEVER hardcode TenantId

        var entity = model.Adapt<BookingManagement>();
        entity.Id = Guid.NewGuid();

        await _context.BookingManagement.AddAsync(entity, ct);
        await _context.SaveChangesAsync(ct);

        // Fire domain event (async, non-blocking)
        await _queue.Publish(new BookingManagementChangedEvent(entity.TenantId));

        return entity.Adapt<UpdateBookingCustomerModel>();
    }
}
```

## Query Pattern

```csharp
// Filter model
public class BookingCustomerFilterModel : PaginationFilter
{
    public Guid? TenantId { get; set; }
    public BookingStatus? Status { get; set; }
    public DateTimeOffset? FromDate { get; set; }
    public DateTimeOffset? ToDate { get; set; }
}

// Query
public class GetPaginatedBookingCustomerQuery
    : IRequest<PaginatedList<BookingManagementModel>>
{
    public BookingCustomerFilterModel Filter { get; }
    public GetPaginatedBookingCustomerQuery(BookingCustomerFilterModel filter) => Filter = filter;
}

// Handler — always AsNoTracking, always paginate
public class GetPaginatedBookingCustomerQueryHandler
    : IRequestHandler<GetPaginatedBookingCustomerQuery, PaginatedList<BookingManagementModel>>
{
    public async Task<PaginatedList<BookingManagementModel>> Handle(
        GetPaginatedBookingCustomerQuery request, CancellationToken ct)
    {
        var filter = request.Filter;
        var query = _context.BookingManagement
            .AsNoTracking()
            .Include(x => x.Services)
            .Include(x => x.Customer)
            .Where(x => x.TenantId == filter.TenantId);

        if (filter.Status.HasValue)
            query = query.Where(x => x.Status == filter.Status);

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(x => x.BookingDate)
            .Skip((filter.PageIndex - 1) * filter.PageSize)
            .Take(filter.PageSize)
            .ProjectToType<BookingManagementModel>() // Mapster projection
            .ToListAsync(ct);

        return new PaginatedList<BookingManagementModel>(items, total, filter.PageIndex, filter.PageSize);
    }
}
```

## Controller Pattern

```csharp
[ApiController]
[Route("api/[controller]")]
public class BookingCustomerController : BaseProviderController
{
    // BaseProviderController injects ISender _sender

    [HttpGet]
    [Permission(MenuEnum.Booking, EnumAction.View)]  // ALWAYS add Permission attribute
    public async Task<ActionResult<PaginatedList<BookingManagement_ResponseDto>>> List(
        [FromQuery] BookingCustomerFilterDto request)
    {
        var filter = request.Adapt<BookingCustomerFilterModel>(); // DTO → Model
        var model = await _sender.Send(new GetPaginatedBookingCustomerQuery(filter));

        // Map domain model → response DTO
        var result = new PaginatedList<BookingManagement_ResponseDto>(
            model.Items.Select(x => new BookingManagement_ResponseDto(x)).ToList(),
            model.TotalItems, model.PageIndex, model.PageSize);
        return result;
    }

    [HttpPost]
    [Permission(MenuEnum.Booking, EnumAction.Create)]
    public async Task<ActionResult<AuditableResponseDto>> Create(
        [FromBody] BookingCustomer_CreateDto request)
    {
        var model = request.Adapt<UpdateBookingCustomerModel>();
        var result = await _sender.Send(new CreateBookingCustomerCommand(model));
        return new AuditableResponseDto(result);
    }

    [HttpPut("{id}")]
    [Permission(MenuEnum.Booking, EnumAction.Update)]
    public async Task<ActionResult<AuditableResponseDto>> Update(
        Guid id, [FromBody] BookingCustomer_UpdateDto request)
    {
        var model = request.Adapt<UpdateBookingCustomerModel>();
        model.Id = id;
        var result = await _sender.Send(new UpdateBookingCustomerCommand(model));
        return new AuditableResponseDto(result);
    }
}
```

## DTO Pattern

```csharp
// Create DTO — input validation only
public class BookingCustomer_CreateDto
{
    [Required] public Guid TenantId { get; set; }
    [Required] public DateTimeOffset BookingDate { get; set; }
    public List<BookingService_CreateDto> Services { get; set; } = [];
}

// Update DTO — same structure, Id optional (from route)
public class BookingCustomer_UpdateDto : BookingCustomer_CreateDto { }

// Response DTO — constructor from domain model
public class BookingManagement_ResponseDto : AuditableResponseDto
{
    public string Code { get; set; }
    public BookingStatus Status { get; set; }
    public DateTimeOffset BookingDate { get; set; }
    public List<BookingService_ResponseDto> Services { get; set; }

    public BookingManagement_ResponseDto(BookingManagementModel model) : base(model)
    {
        Code = model.Code;
        Status = model.Status;
        BookingDate = model.BookingDate;
        Services = model.Services?.Select(s => new BookingService_ResponseDto(s)).ToList() ?? [];
    }
}
```

## Domain Event Pattern

```csharp
// 1. Define notification
public class BookingManagementChangedEvent : INotification
{
    public Guid TenantId { get; }
    public BookingManagementChangedEvent(Guid tenantId) => TenantId = tenantId;
}

// 2. Handle notification → publish MassTransit message
public class BookingManagementChangedEventHandler
    : INotificationHandler<BookingManagementChangedEvent>
{
    private readonly IBus _bus;

    public async Task Handle(BookingManagementChangedEvent notification, CancellationToken ct)
    {
        await _bus.Publish(new ListBookingManagementChangedMessage
        {
            TenantId = notification.TenantId
        }, ct);
    }
}

// 3. Fire from command handler (non-blocking)
await _queue.Publish(new BookingManagementChangedEvent(entity.TenantId));
```

## EF Core DbContext Pattern

```csharp
// Global filters applied in OnModelCreating
protected override void OnModelCreating(ModelBuilder builder)
{
    // Soft delete filter on all TenantEntity types
    builder.Entity<BookingManagement>()
        .HasQueryFilter(m => !m.IsDeleted);

    // Tenant isolation filter
    builder.Entity<BookingManagement>()
        .HasQueryFilter(m => m.TenantId == _tenantId || _tenantId == Guid.Empty);
}

// Bypass filters for admin operations
var allBookings = _context.BookingManagement
    .IgnoreQueryFilters()
    .Where(x => x.IsDeleted);
```

## Hangfire Background Jobs

```csharp
// Register recurring job in Program.cs
RecurringJob.AddOrUpdate<ITenantService>(
    "deactivate-expired-tenants",
    x => x.DeactivateExpiredTenantsAsync(),
    Cron.Minutely);

// One-off background job
BackgroundJob.Enqueue<INotificationService>(
    x => x.SendBookingReminderAsync(bookingId));
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Command | `[Domain][Action]Command` | `CreateBookingCustomerCommand` |
| Query | `Get[Type][Modifier]Query` | `GetPaginatedBookingCustomerQuery` |
| Handler | `[Command/Query]Handler` | `CreateBookingCustomerCommandHandler` |
| Event | `[Entity][Change]Event` | `BookingManagementChangedEvent` |
| Message | `[Entity][Action]Message` | `ListBookingManagementChangedMessage` |
| DTO (create) | `[Entity]_CreateDto` | `BookingCustomer_CreateDto` |
| DTO (response) | `[Entity]_ResponseDto` | `BookingManagement_ResponseDto` |
| Model | `[Entity]Model` or `Update[Entity]Model` | `BookingManagementModel` |
| DbSet | PascalCase + underscore for join tables | `BookingManagement_Service` |

## Shared Logic → Static Helper Pattern

If logic is used by more than one handler (or could plausibly be reused later — password/token generation, phone normalization, SMS/notification senders, cross-entity assignment rules), don't inline it in the handler. Extract it into a static helper class under `Services/` (or alongside the feature if it's feature-specific), following the existing convention:

```csharp
// PortalService/Services/PasswordGeneratorHelper.cs
namespace PortalService.Services;

public static class PasswordGeneratorHelper
{
    public static string Generate(int length = 8) { /* ... */ }
}

// Usage in a handler
var password = PasswordGeneratorHelper.Generate();
```

Existing examples in this codebase: `PasswordGeneratorHelper`, `StoreManagerAssignmentHelper`, `CustomerUsageHelper`. For logic that talks to an external system (SMS provider, etc.), extract an interface + implementation instead (e.g. `ISmsSender`/`SmsSender`) and register it in DI, so it's mockable and the handler doesn't own the HTTP/provider details.

Benefits: keeps handlers focused on orchestration, makes the logic unit-testable in isolation, and prevents copy-pasted drift when the same rule needs to change in two places later.

## Critical Rules

- **Never** hardcode `TenantId` — always from `_currentUserProvider.TenantId`
- **Never** skip `[Permission]` on controller actions
- **Always** use `AsNoTracking()` in query handlers
- **Always** publish events via `IBackgroundMediatRQueue` (non-blocking)
- **Never** call a command handler from another handler — extract shared service
- **Never** put business logic in controllers
- **Never** inline logic used by 2+ handlers — extract to a static helper (`Services/`) or a DI'd service/interface (see "Shared Logic → Static Helper Pattern" above)

## Reference Documentation
- `references/api_design_patterns.md` — REST conventions, error handling, pagination
- `references/database_optimization_guide.md` — EF Core query optimization, indexing
- `references/backend_security_practices.md` — Auth, permissions, multi-tenancy security
