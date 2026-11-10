# Backend Security Practices — Nail Booking ASP.NET Core

## Authentication Architecture

### JWT Flow
```
1. Client → POST /api/appuser/login { username, password }
2. PortalService validates credentials → generates JWT with claims
3. Client stores token → sends as Authorization: Bearer <token>
4. API Gateway passes token to upstream services
5. Each service validates token signature + claims
```

### Required JWT Claims
```
sub     — UserId (Guid)
tenantId — TenantId (Guid) — CRITICAL for data isolation
email   — user email
role    — user role
permission — array of "MenuEnum:EnumAction" strings (e.g., "Booking:View")
exp     — expiration timestamp
```

### Token Validation Setup
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = config["Jwt:Issuer"],
            ValidAudience = config["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(config["Jwt:Secret"])),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
```

## Authorization: Permission-Based RBAC

### Attribute Pattern
```csharp
// Every action MUST have [Permission] — no exceptions
[HttpGet]
[Permission(MenuEnum.Booking, EnumAction.View)]
public async Task<IActionResult> List(...) { }

[HttpPost]
[Permission(MenuEnum.Booking, EnumAction.Create)]
public async Task<IActionResult> Create(...) { }

[HttpDelete("{id}")]
[Permission(MenuEnum.Booking, EnumAction.Delete)]
public async Task<IActionResult> Delete(Guid id) { }
```

### Permission Claim Format
```
"Booking:View"
"Booking:Create"
"Staff:Update"
"Tenant:Delete"
```

### Custom Policy Provider
```csharp
public class PermissionPolicyProvider : IAuthorizationPolicyProvider
{
    public Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        // policyName = "Booking:View"
        var policy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .RequireClaim("permission", policyName)
            .Build();
        return Task.FromResult<AuthorizationPolicy?>(policy);
    }
}
```

## Multi-Tenant Security

### TenantId Source of Truth
```csharp
// CORRECT — TenantId from JWT claim
public Guid TenantId => Guid.Parse(
    _httpContext.User.FindFirstValue("tenantId")
    ?? throw new UnauthorizedException("TenantId not in token"));

// WRONG — never trust client-supplied TenantId for data isolation
public async Task<IActionResult> List([FromQuery] Guid tenantId)
{
    // Don't use tenantId directly for filtering — attacker can supply any value
    var items = await _sender.Send(new GetQuery(tenantId)); // WRONG
}

// CORRECT — override with token claim in handler
var filter = request.Adapt<FilterModel>();
filter.TenantId = _currentUser.TenantId; // overrides any client-supplied value
```

## CORS Security

```csharp
// NEVER use AllowAnyOrigin() with AllowCredentials() — ASP.NET Core throws
// CORRECT — explicit origins
options.AddPolicy("CorsPolicy", policy =>
    policy.WithOrigins(config.GetSection("AllowedOrigins").Get<string[]>()!)
          .AllowAnyMethod()
          .AllowAnyHeader()
          .AllowCredentials());

// Production AllowedOrigins in appsettings.json:
// "AllowedOrigins": ["http://10.100.1.126:3030", "http://10.100.1.126:3031", ...]
```

## SQL Injection Prevention

```csharp
// ALWAYS EF Core LINQ — parameterized automatically
var result = await _context.BookingManagement
    .Where(b => b.Code == userInput) // safe — EF parameterizes
    .FirstOrDefaultAsync();

// Raw SQL — only when necessary, ALWAYS parameterized
var result = await _context.Database.ExecuteSqlRawAsync(
    "SELECT * FROM BookingManagement WHERE Code = {0}", userInput); // safe

// NEVER — string interpolation in raw SQL
var sql = $"SELECT * FROM BookingManagement WHERE Code = '{userInput}'"; // SQL injection
```

## Sensitive Config Protection

**Never commit to source control:**
- Connection strings with passwords
- JWT Secret keys
- RabbitMQ credentials
- MinIO access/secret keys

**Local development:**
```powershell
dotnet user-secrets set "ConnectionStrings:BookingDbContext" "Server=...;Password=..."
dotnet user-secrets set "Jwt:Secret" "your-secret"
```

**Docker production:**
```
# Config file mounted at /app/Config/appsettings.json
# Managed outside Docker image — NOT baked in
```

## Input Validation

```csharp
// Data Annotations on all DTOs
public class BookingCustomer_CreateDto
{
    [Required]
    public Guid TenantId { get; set; }

    [Required]
    public DateTimeOffset BookingDate { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }

    [Range(1, 100)]
    public int ServiceCount { get; set; }
}
```

## Security Checklist for New Endpoints

- [ ] `[Authorize]` on controller (via `BaseProviderController`) or action
- [ ] `[Permission(MenuEnum.X, EnumAction.Y)]` on every action
- [ ] TenantId from `_currentUser.TenantId` (not request body)
- [ ] All DTO properties have appropriate validation attributes
- [ ] No raw SQL strings — EF Core LINQ only
- [ ] No sensitive data in response DTOs (passwords, secrets)
- [ ] Exception handler configured — no stack traces to client in production

## Known Weakness to Address

- **Password hashing**: Current implementation uses SHA256 without salt. Consider upgrading to `BCrypt.Net` or `Microsoft.AspNetCore.Identity` password hasher with per-user salt.
- **Token refresh**: No token refresh flow documented. Ensure short expiry + refresh token if needed.
- **Rate limiting**: No rate limiting on login endpoint. Consider `Microsoft.AspNetCore.RateLimiting` middleware.
