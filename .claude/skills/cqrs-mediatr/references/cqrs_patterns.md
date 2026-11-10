# CQRS Patterns Deep-Dive — Nail Booking

## When to Use Command vs Query

| Scenario | Use | Why |
|----------|-----|-----|
| Create entity | Command | Mutates state |
| Update entity | Command | Mutates state |
| Soft delete | Command | Mutates state |
| Domain action (check-in, cancel) | Command | State transition |
| Get single item | Query | Read-only |
| Get paginated list | Query | Read-only |
| Get list by filter | Query | Read-only |
| Bulk status update | Command | Mutates state |
| Export/report data | Query (or Hangfire job) | Read-only |
| Send SMS/email | Command (fire-and-forget) | Side effect |

## Command Structure Variations

### Standard Create/Update Command
```csharp
// Model carries all data
public class CreateBookingCustomerCommand : IRequest<UpdateBookingCustomerModel>
{
    public UpdateBookingCustomerModel Model { get; }
    public CreateBookingCustomerCommand(UpdateBookingCustomerModel model) => Model = model;
}
```

### Simple Action Command (no model needed)
```csharp
public class CheckInBookingCustomerCommand : IRequest<UpdateBookingCustomerModel>
{
    public Guid BookingId { get; }
    public CheckInBookingCustomerCommand(Guid bookingId) => BookingId = bookingId;
}

public class CheckInBookingCustomerCommandHandler
    : IRequestHandler<CheckInBookingCustomerCommand, UpdateBookingCustomerModel>
{
    public async Task<UpdateBookingCustomerModel> Handle(
        CheckInBookingCustomerCommand request, CancellationToken ct)
    {
        var entity = await _context.BookingManagement
            .FirstOrDefaultAsync(x => x.Id == request.BookingId
                                   && x.TenantId == _currentUser.TenantId, ct)
            ?? throw new NotFoundException(nameof(BookingManagement), request.BookingId);

        // Domain state transition
        if (entity.Status != BookingStatus.Confirmed)
            throw new ValidationException("Can only check-in confirmed bookings");

        entity.Status = BookingStatus.CheckedIn;
        entity.CheckedInAt = DateTimeOffset.UtcNow;
        entity.UpdatedAt = DateTimeOffset.UtcNow;
        entity.UpdatedBy = _currentUser.UserId.ToString();

        await _context.SaveChangesAsync(ct);

        await _queue.Publish(new BookingManagementChangedEvent(entity.TenantId));

        return entity.Adapt<UpdateBookingCustomerModel>();
    }
}
```

### Bulk Command
```csharp
public class BulkCancelBookingCommand : IRequest<int>
{
    public List<Guid> BookingIds { get; }
    public string Reason { get; }
}

// Handler uses ExecuteUpdateAsync for performance
public async Task<int> Handle(BulkCancelBookingCommand request, CancellationToken ct)
{
    var count = await _context.BookingManagement
        .Where(b => request.BookingIds.Contains(b.Id)
                 && b.TenantId == _currentUser.TenantId
                 && b.Status != BookingStatus.Cancelled)
        .ExecuteUpdateAsync(s => s
            .SetProperty(b => b.Status, BookingStatus.Cancelled)
            .SetProperty(b => b.UpdatedAt, DateTimeOffset.UtcNow)
            .SetProperty(b => b.UpdatedBy, _currentUser.UserId.ToString()), ct);

    await _queue.Publish(new BookingManagementChangedEvent(_currentUser.TenantId));
    return count;
}
```

## Query Structure Variations

### Paginated List Query
```csharp
public class GetPaginatedBookingCustomerQuery
    : IRequest<PaginatedList<BookingManagementModel>>
{
    public BookingCustomerFilterModel Filter { get; }
    public GetPaginatedBookingCustomerQuery(BookingCustomerFilterModel filter) => Filter = filter;
}
```

### Single Item Query
```csharp
public class GetBookingCustomerQuery : IRequest<BookingManagementModel>
{
    public Guid Id { get; }
    public GetBookingCustomerQuery(Guid id) => Id = id;
}
```

### List (non-paginated, for dropdowns)
```csharp
public class GetListStaffByTenantQuery : IRequest<List<StaffModel>>
{
    public Guid TenantId { get; }
    public GetListStaffByTenantQuery(Guid tenantId) => TenantId = tenantId;
}

// Handler — no pagination, AsNoTracking, lightweight model
public async Task<List<StaffModel>> Handle(
    GetListStaffByTenantQuery request, CancellationToken ct)
{
    return await _context.Staff
        .AsNoTracking()
        .Where(s => s.TenantId == request.TenantId && !s.IsLocked)
        .OrderBy(s => s.Name)
        .ProjectToType<StaffModel>()
        .ToListAsync(ct);
}
```

## Event Pattern Details

### INotification vs Integration Message
```csharp
// INotification — in-process, raised by command handler
// → handled within same service (NotificationHandler → publish to RabbitMQ)
public class BookingManagementChangedEvent : INotification
{
    public Guid TenantId { get; }
}

// Integration Message — cross-process, consumed by other services
// → defined in BuildingBlock/Messages/ (shared between services)
public class ListBookingManagementChangedMessage
{
    public Guid TenantId { get; set; }
}
```

### Fire-and-Forget (IBackgroundMediatRQueue)
```csharp
// Never await in a try-catch expecting handler failures to surface
// The notification runs asynchronously — handler failures are logged but don't affect the command response

// Command handler:
await _context.SaveChangesAsync(ct); // DB write succeeds
await _queue.Publish(new BookingChangedEvent(...)); // async notification — may fail silently
return result; // returns even if notification hasn't completed
```

## Common Mistakes

### Handler Calling Handler
```csharp
// WRONG — creates tight coupling between use cases
public async Task<Model> Handle(CreateCommand request, CancellationToken ct)
{
    var result = await _sender.Send(new SomeOtherCommand(...)); // wrong
}

// RIGHT — extract shared logic into a service
public async Task<Model> Handle(CreateCommand request, CancellationToken ct)
{
    await _bookingCodeService.GenerateCodeAsync(entity); // shared service
}
```

### Missing TenantId Override
```csharp
// WRONG — model.TenantId comes from HTTP request body (attacker can supply any value)
public async Task<Model> Handle(CreateCommand request, CancellationToken ct)
{
    var entity = request.Model.Adapt<BookingManagement>();
    // entity.TenantId = whatever came from client
    await _context.AddAsync(entity, ct);
}

// RIGHT — always override from token
model.TenantId = _currentUser.TenantId;
var entity = model.Adapt<BookingManagement>();
```
