namespace BanHang.SharedKernel.Entities;

public abstract class AuditableEntity<TId> : BaseEntity<TId>, IAuditable
{
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? ModifiedAt { get; set; }
    public string? ModifiedBy { get; set; }
    public bool IsDeleted { get; set; }
}

public abstract class AuditableEntity : AuditableEntity<long>;
