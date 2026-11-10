# API Design Patterns — Nail Booking ASP.NET Core

## REST Conventions

### URL Structure
```
GET    /api/bookingcustomer              — paginated list (with ?pageIndex=&pageSize=)
GET    /api/bookingcustomer/{id}         — single item
POST   /api/bookingcustomer             — create
PUT    /api/bookingcustomer/{id}         — full update
DELETE /api/bookingcustomer/{id}         — soft delete (IsDeleted = true)
POST   /api/bookingcustomer/{id}/checkin — domain action
POST   /api/bookingcustomer/{id}/cancel  — domain action
```

**Controller naming**: `BookingCustomerController` → route `/api/bookingcustomer`
**Route template**: `[Route("api/[controller]")]` — controller name lowercased, no suffix

### HTTP Status Codes
| Code | Meaning in this codebase |
|------|--------------------------|
| 200  | Successful GET, PUT, DELETE, domain action |
| 201  | Successful POST (optional) |
| 400  | Validation error, bad request body |
| 401  | Missing/expired JWT |
| 403  | Valid JWT but missing Permission claim |
| 404  | Entity not found |
| 500  | Unhandled exception |

## Pagination

### Request (query params)
```http
GET /api/bookingcustomer?pageIndex=1&pageSize=20&keyword=john&status=1
```

### Filter DTO (input)
```csharp
public class BookingCustomerFilterDto : PaginationFilterDto
{
    public BookingStatus? Status { get; set; }
    [FromQuery(Name = "from")]
    public DateTimeOffset? FromDate { get; set; }
    [FromQuery(Name = "to")]
    public DateTimeOffset? ToDate { get; set; }
    public Guid? TenantId { get; set; }
    public string? Keyword { get; set; }
}

public class PaginationFilterDto
{
    public int PageIndex { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}
```

### Response wrapper
```csharp
public class PaginatedList<T>
{
    public List<T> Items { get; }
    public int TotalItems { get; }
    public int PageIndex { get; }
    public int PageSize { get; }
    public int TotalPages => (int)Math.Ceiling(TotalItems / (double)PageSize);
}
```

## Request/Response DTOs

### Create DTO — validation only, no business logic
```csharp
public class BookingCustomer_CreateDto
{
    [Required]
    public Guid TenantId { get; set; }

    [Required]
    public DateTimeOffset BookingDate { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    public List<BookingService_CreateDto> Services { get; set; } = [];
}
```

### Response DTO — constructor from domain model
```csharp
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

### Command response — always AuditableResponseDto
```csharp
// Controller returns this for all create/update/delete
return new AuditableResponseDto(result); // result is domain model with Id + timestamps
```

## Controller Base

```csharp
[ApiController]
[Authorize]
public abstract class BaseProviderController : ControllerBase
{
    protected ISender _sender;
    protected ICurrentUserProvider _currentUser;

    // Injected via DI in concrete controllers
}
```

## Error Handling

### Global exception handler (Program.cs)
```csharp
app.UseExceptionHandler(handler =>
{
    handler.Run(async ctx =>
    {
        ctx.Response.ContentType = "application/json";
        var ex = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;

        var (status, message) = ex switch
        {
            NotFoundException e     => (404, e.Message),
            ValidationException e   => (400, e.Message),
            UnauthorizedException   => (401, "Unauthorized"),
            ForbiddenException      => (403, "Forbidden"),
            _                       => (500, "An error occurred"),
        };

        ctx.Response.StatusCode = status;
        await ctx.Response.WriteAsJsonAsync(new { error = message });
    });
});
```

### Domain exceptions
```csharp
public class NotFoundException : Exception
{
    public NotFoundException(string entity, Guid id)
        : base($"{entity} '{id}' not found") { }
}
```

## Swagger Configuration

```csharp
builder.Services.AddSwaggerGen(c =>
{
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Enter JWT token"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme { Reference = new OpenApiReference
                { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            Array.Empty<string>()
        }
    });
});
```

## Content Negotiation

- Requests: `application/json` (default for body)
- File upload: `multipart/form-data` (StorageService only)
- Responses: always `application/json`
- Date format: ISO 8601 (`DateTimeOffset` serialized as `"2024-01-15T10:30:00+07:00"`)

## Versioning Strategy

No explicit versioning currently. Convention: URL prefix implicitly v1.
If breaking change needed: add `/v2/` prefix route, keep old route with `[Obsolete]` attribute for backward compat.
