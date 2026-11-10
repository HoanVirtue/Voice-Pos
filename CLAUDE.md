# Hướng dẫn cho Claude Code

Dự án: app bán thịt lợn bằng giọng nói (backend .NET 8 + app Flutter). Plan: xem `docs/` và README.

## Quy ước
- Tiếng Việt cho thông báo lỗi, commit (`feat(app): ...`), tài liệu.
- Backend: namespace `BanHang.*`, CQRS/MediatR (Commands/Requests + Handlers + Queries + Dtos), FluentValidation, phản hồi `ActionResponse<T>`, route `api/v1`. Xem `.claude/skills`.
- Tiền: `long` đồng. Khối lượng: `int` gram. Id: Guid do client sinh. Xóa mềm. Thời gian lưu UTC, hiển thị giờ VN.
- App: Riverpod + go_router + Dio; offline-first (ghi drift → outbox → sync). Không nhúng token Blaze vào app (lấy từ `GET /api/v1/Voice/stt-token`).
- Không commit `.env`, secret, mật khẩu.
