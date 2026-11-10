# Nhật ký sửa lỗi (từ FINDINGS.md, ngày 10/11/2026)

Kết quả sau sửa: `flutter analyze` sạch; `flutter test` 252 pass; `dotnet build BanHang.sln` 0 cảnh báo/0 lỗi; `dotnet test` 69 pass.

## BUG-001 - Outbox không tự thử lại khi API tạm không tới được (ĐÃ SỬA)
- Nguyên nhân gốc (xác minh bằng đọc code): `SyncService.start()` chỉ sync một lần và nghe connectivity; `_run()` khi `push.completed == false` hoặc có `DioException` chỉ đặt trạng thái `error/offline`, không hẹn lại. Thiết bị vẫn báo "có mạng" nên không có sự kiện connectivity nào kích hoạt.
- Sửa: `app/lib/core/sync/sync_service.dart` - thêm `_afterRun()` gọi sau mỗi vòng; vòng không hoàn tất (`completed == false`) thì hẹn `Timer` thử lại theo bảng lùi dần 15s -> 30s -> 60s -> 2 phút -> 5 phút (phần tử cuối lặp lại), thành công thì reset và hủy timer; `dispose()` (provider autoDispose khi đăng xuất) hủy timer. Tham số `retryDelays` để test tiêm giá trị nhỏ. Vòng thành công không hẹn thêm nên khi hết outbox và kéo ổn thì không chạy nền.
- Kiểm chứng: `app/test/core/sync/sync_retry_test.dart` (4 ca): lỗi mạng 2 lần rồi lên server (3 lần gọi, outbox rỗng, trạng thái về idle); thành công không gọi lại; dispose hủy hẹn giờ; khoảng cách lùi dần đúng bảng. Toàn bộ `flutter test` xanh. Chưa chạy lại trên giao diện thật: agent test chạy lại ca Z2 (đợi tối đa ~15s sau khi bỏ chặn, nay phải tự lên server; lưu ý tăng ngưỡng chờ nếu đã trượt qua mốc 30s/60s do nhiều lần lỗi liên tiếp).

## BUG-002 - Nút đổi ngày màn Chốt sổ thiếu tên accessibility (ĐÃ SỬA)
- Nguyên nhân: hai `IconButton` `settle_prev/settle_next` không có `tooltip` (màn Sổ có).
- Sửa: `app/lib/features/settlements/presentation/settlement_screen.dart` thêm `tooltip: 'Ngày trước'` / `'Ngày sau'`.
- Kiểm chứng: test mới trong `app/test/features/settlements/settlement_screen_test.dart` kiểm tooltip. Agent test có thể tìm nút theo tên "Ngày trước"/"Ngày sau" ở tab Chốt sổ.

## BUG-003 - Log [ERR] "responded 500" cho 401/503 (ĐÃ SỬA)
- Nguyên nhân gốc (đọc `ExceptionHandlingMiddleware`, `BuilderExtensions.UseBuildingBlocks`, `api.log`): `UseSerilogRequestLogging()` được đăng ký SAU middleware xử lý ngoại lệ, nên nằm bên trong nó, thấy ngoại lệ lan lên và ghi `responded 500` mức Error kèm stack, trước khi middleware ghi 401/503 vào response. Thêm nữa `LoggingBehavior` (MediatR) ghi `LogError` cho mọi ngoại lệ kể cả `CustomException`.
- Sửa: `backend/BanHang.BuildingBlocks/BuilderExtensions.cs` đổi thứ tự (request logging ngoài, exception middleware trong) và dùng `GetLevel` mới `backend/BanHang.BuildingBlocks/Logging/RequestLogLevel.cs` (2xx/3xx Info; 4xx và 5xx khác 500 Warning; 500 hoặc có ngoại lệ Error). `backend/BanHang.BuildingBlocks/Behaviors/LoggingBehavior.cs`: `CustomException`/`ValidationException` ghi Warning (không stack), ngoại lệ bất ngờ vẫn Error. Hợp đồng API và mã trả về không đổi (stt-token chưa cấu hình vẫn 503).
- Kiểm chứng: `backend/BanHang.Tests/Behaviors/LoggingLevelTests.cs` (mức log theo mã trạng thái; lỗi nghiệp vụ không ghi Error; lỗi bất ngờ vẫn Error). Cần agent test xem lại `api.log` sau lượt chạy mới: 401 login và 503 stt-token phải là `[WRN] ... responded 401/503`, không còn `[ERR]`. Lưu ý: middleware ngoại lệ vẫn ghi một dòng `[WRN] Request to ... failed` có stack cho CustomException (giữ nguyên, chủ đích).

## BUG-004 - RangeError (start) không ổn định ở ca F3 (KHÔNG SỬA)
- Điều tra: mã app không dùng `selection`/`TextSelection`; `substring` duy nhất (`market_parser.dart:1016`, `_title`) có điều kiện `isEmpty` và `substring(1)` nên không thể ném lỗi dạng "0..32: 37". Thông báo "Not in inclusive range 0..32: 37" nghĩa là vùng chọn (37) lớn hơn độ dài chữ (32) trong lớp text-editing của Flutter web sau `fill()` của Playwright; chỉ 1/4 lượt, giao diện vẫn đúng, ca PASS, không tái hiện được. Kết luận: nhiều khả năng do tương tác Playwright `fill` với engine, không phải lỗi người dùng thật; theo dõi nếu gặp lại khi gõ tay.

## Quan sát
- Đăng nhập sai 5 lần không bị khóa/làm chậm: KHÔNG tự thêm (quyết định sản phẩm). Khuyến nghị: nếu cần, làm giãn dần theo tài khoản + IP (ví dụ trễ tăng sau 5 lần sai, khóa 5-15 phút sau 10 lần) hoặc rate limiting trên `Auth/login`, kèm cách chủ cửa hàng mở khóa; cân nhắc rủi ro khóa nhầm người dùng thật.
- Nhãn lặp "Quay lại Quay lại", "Ngày trước Ngày trước": KHÔNG sửa. Mã app không đặt nhãn "Quay lại"; đó là tooltip mặc định của `BackButton` do Flutter localization, và web semantics ghép nhãn + tooltip nên lặp. Hành vi framework, không đơn giản sửa trong app (sửa sẽ phải bọc `ExcludeSemantics`/tự dựng nút, rủi ro mất accessibility).
