---
name: cqrs-mediatr
description: CQRS and MediatR patterns specific to the Nail Booking ASP.NET Core microservices. Covers command handlers, query handlers, pipeline behaviors, domain events, IBackgroundMediatRQueue fire-and-forget, and the full request lifecycle from controller to database. Use when implementing any new command, query, domain event, or MediatR pipeline behavior.
---

# CQRS + MediatR — Nail Booking Patterns

Deep-dive into CQRS implementation patterns used across all services in this codebase.

## MediatR Request Lifecycle

```
HTTP Request
  ↓
Controller (maps DTO → Model via Mapster.Adapt<T>())
  ↓
ISender.Send(IRequest<TResponse>)
  ↓
MediatR Pipeline:
  → LoggingBehavior (logs request name + start time)
  → [ValidationBehavior] (if validators registered)
  → IRequestHandler<TRequest, TResponse>.Handle()
  ↓
Handler:
  → Validate business rules
  → Mutate/query DB via IDbContext
  → Publish domain events via IBackgroundMediatRQueue (non-blocking)
  → Return result
  ↓
Controller maps result → ResponseDto → HTTP response
```

## Command Pattern

### Command Definition
```csharp
// Location: Application/Commands/[Domain]/[Action][Domain]Command.cs
public class CreateBookingCustomerCommand : IRequest<UpdateBookingCustomerModel>
{
    public UpdateBookingCustomerModel Model { get; }
    public CreateBookingCustomerCommand(UpdateBookingCustomerModel model) => Model = model;
}
```

### Command Handler
```csharp
// Location: Application/Commands/[Domain]/[Action][Domain]CommandHandler.cs
public class CreateBookingCustomerCommandHandler
    : IRequestHandler<CreateBookingCustomerCommand, UpdateBookingCustomerModel>
{
    private readonly IBookingDbContext _context;
    private readonly ICurrentUserProvider _currentUser;
    private readonly IBackgroundMediatRQueue _queue;

    public CreateBookingCustomerCommandHandler(
        IBookingDbContext context,
        ICurrentUserProvider currentUser,
        IBackgroundMediatRQueue queue)
    {
        _context = context;
        _currentUser = currentUser;
        _queue = queue;
    }

    public async Task<UpdateBookingCustomerModel> Handle(
        CreateBookingCustomerCommand request, CancellationToken cancellationToken)
    {
        var model = request.Model;

        // 1. Set tenant from token — NEVER trust client-supplied TenantId
        model.TenantId = _currentUser.TenantId;

        // 2. Map model → entity
        var entity = model.Adapt<BookingManagement>();
        entity.Id = Guid.NewGuid();
        entity.CreatedAt = DateTimeOffset.UtcNow;
        entity.CreatedBy = _currentUser.UserId.ToString();

        // 3. Persist
        await _context.BookingManagement.AddAsync(entity, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);

        // 4. Publish domain event (fire-and-forget — does NOT block response)
        await _queue.Publish(new BookingManagementChangedEvent(entity.TenantId));
        await _queue.Publish(new BookingSendNotificationEvent(entity.Id));

        // 5. Return domain model
        return entity.Adapt<UpdateBookingCustomerModel>();
    }
}
```

### Update Command Pattern
```csharp
public class UpdateBookingCustomerCommandHandler
    : IRequestHandler<UpdateBookingCustomerCommand, UpdateBookingCustomerModel>
{
    public async Task<UpdateBookingCustomerModel> Handle(
        UpdateBookingCustomerCommand request, CancellationToken ct)
    {
        var model = request.Model;

        // Fetch with tracking (mutation needs tracking)
        var entity = await _context.BookingManagement
            .Include(x => x.Services)
            .FirstOrDefaultAsync(x => x.Id == model.Id && x.TenantId == _currentUser.TenantId, ct)
            ?? throw new NotFoundException(nameof(BookingManagement), model.Id!.Value);

        // Update entity properties
        model.Adapt(entity); // Mapster updates in-place
        entity.UpdatedAt = DateTimeOffset.UtcNow;
        entity.UpdatedBy = _currentUser.UserId.ToString();

        await _context.SaveChangesAsync(ct);

        await _queue.Publish(new BookingManagementChangedEvent(entity.TenantId));

        return entity.Adapt<UpdateBookingCustomerModel>();
    }
}
```

## Query Pattern

### Query Definition
```csharp
// Location: Application/Queries/[Domain]/Get[Modifier][Domain]Query.cs
public class GetPaginatedBookingCustomerQuery
    : IRequest<PaginatedList<BookingManagementModel>>
{
    public BookingCustomerFilterModel Filter { get; }
    public GetPaginatedBookingCustomerQuery(BookingCustomerFilterModel filter) => Filter = filter;
}

public class GetBookingCustomerQuery : IRequest<BookingManagementModel>
{
    public Guid Id { get; }
    public GetBookingCustomerQuery(Guid id) => Id = id;
}
```

### Query Handler
```csharp
public class GetPaginatedBookingCustomerQueryHandler
    : IRequestHandler<GetPaginatedBookingCustomerQuery, PaginatedList<BookingManagementModel>>
{
    public async Task<PaginatedList<BookingManagementModel>> Handle(
        GetPaginatedBookingCustomerQuery request, CancellationToken ct)
    {
        var filter = request.Filter;

        var query = _context.BookingManagement
            .AsNoTracking()          // MANDATORY on all queries
            .Where(x => x.TenantId == filter.TenantId);

        // Optional filters
        if (filter.Status.HasValue)
            query = query.Where(x => x.Status == filter.Status.Value);
        if (filter.FromDate.HasValue)
            query = query.Where(x => x.BookingDate >= filter.FromDate.Value);
        if (!string.IsNullOrEmpty(filter.Keyword))
            query = query.Where(x => x.Code.Contains(filter.Keyword)
                                  || x.Customer.Name.Contains(filter.Keyword));

        var total = await query.CountAsync(ct);
        var items = await query
            .OrderByDescending(x => x.BookingDate)
            .ProjectToType<BookingManagementModel>() // Mapster projection
            .ToPagedAsync(filter.PageIndex, filter.PageSize, ct); // BuildingBlock extension — prefer over hand-rolled Skip/Take

        return new PaginatedList<BookingManagementModel>(items, total, filter.PageIndex, filter.PageSize);
    }
}
```

## Domain Event Pattern

### Event Definition
```csharp
// In-process notification (MediatR INotification)
// Location: Application/Events/[Domain]/[Entity][Change]Event.cs
public class BookingManagementChangedEvent : INotification
{
    public Guid TenantId { get; }
    public BookingManagementChangedEvent(Guid tenantId) => TenantId = tenantId;
}
```

### Event Handler (converts to MassTransit message)
```csharp
public class BookingManagementChangedEventHandler
    : INotificationHandler<BookingManagementChangedEvent>
{
    private readonly IBus _bus;

    public BookingManagementChangedEventHandler(IBus bus) => _bus = bus;

    public async Task Handle(
        BookingManagementChangedEvent notification, CancellationToken ct)
    {
        await _bus.Publish(new ListBookingManagementChangedMessage
        {
            TenantId = notification.TenantId
        }, ct);
    }
}
```

### Fire-and-Forget via IBackgroundMediatRQueue
```csharp
// Publishes INotification WITHOUT blocking the request pipeline
// The notification is processed asynchronously after SaveChangesAsync
await _queue.Publish(new BookingManagementChangedEvent(entity.TenantId));

// Internal implementation wraps:
// Task.Run(() => _mediator.Publish(notification));
```

## Pipeline Behaviors

### LoggingBehavior (already registered)
```csharp
public class LoggingBehavior<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        var name = typeof(TRequest).Name;
        _logger.LogInformation("Handling {RequestName}", name);
        var sw = Stopwatch.StartNew();
        var result = await next();
        sw.Stop();
        _logger.LogInformation("Handled {RequestName} in {Elapsed}ms", name, sw.ElapsedMilliseconds);
        return result;
    }
}
```

### Adding Validation Behavior (if needed)
```csharp
public class ValidationBehavior<TRequest, TResponse>
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;

    public async Task<TResponse> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (!_validators.Any()) return await next();

        var failures = _validators
            .Select(v => v.Validate(request))
            .SelectMany(r => r.Errors)
            .Where(f => f != null)
            .ToList();

        if (failures.Any())
            throw new ValidationException(failures);

        return await next();
    }
}
```

## Registration in DI (BuildingBlock/MediatR/Extensions.cs)

```csharp
services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssembly(assembly);
    cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
    // cfg.AddBehavior(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>)); // if added
});

services.AddSingleton<IBackgroundMediatRQueue, BackgroundMediatRQueue>();
```

## Naming Convention Quick Reference

| Element | Pattern | Example |
|---------|---------|---------|
| Command | `[Action][Domain]Command` | `CreateBookingCustomerCommand` |
| Query (paginated) | `GetPaginated[Domain]Query` | `GetPaginatedBookingCustomerQuery` |
| Query (single) | `Get[Domain]Query` | `GetBookingCustomerQuery` |
| Query (list) | `GetList[Domain]Query` | `GetListStaffByTenantQuery` |
| Handler | `[Command/Query]Handler` suffix | `CreateBookingCustomerCommandHandler` |
| Event | `[Entity][Change]Event` | `BookingManagementChangedEvent` |
| Model (domain) | `[Domain]Model` | `BookingManagementModel` |
| Model (write) | `Update[Domain]Model` | `UpdateBookingCustomerModel` |
| Filter model | `[Domain]FilterModel` | `BookingCustomerFilterModel` |

## Reference Documentation
- `references/cqrs_patterns.md` — Pattern deep-dives, when to use which
- `references/mediatr_pipeline.md` — Pipeline behavior configuration and ordering
