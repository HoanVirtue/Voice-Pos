# Trạng thái sau khi sửa (kiểm lại ngày 10/11/2026 11:15)

Lượt chạy kiểm lại bằng bản đã sửa (`bash docs/ui-test/run_all.sh`, log `run_all-stdout.txt`, `ui-test-20261110-110901.log`, `api.log`):
- ui_test.py: **32 PASS / 0 FAIL**. ui_test_extra.py: **39 PASS / 0 FAIL**. Không còn dòng overflow.

| Mã | Trạng thái | Bằng chứng |
|---|---|---|
| BUG-001 | **Đã sửa, xác nhận** | Ca Z2 PASS (35.9s): giao dịch ghi lúc API không với tới được tự lên server sau khi bỏ chặn, không cần tải lại. |
| BUG-002 | **Đã sửa, xác nhận** | Ca C0 PASS: nút 'Ngày trước'/'Ngày sau' ở Chốt sổ tìm được theo tên và hoạt động. |
| BUG-003 | **Đã sửa, xác nhận** | `api.log`: 0 dòng `[ERR]`; 401 login và 503 stt-token ghi là `[WRN]`. |
| BUG-004 | Không sửa | Không tái hiện lại; nghi do Playwright/lớp nhập liệu Flutter web (xem FIX-LOG.md). |
| Khóa đăng nhập sai | Chờ quyết định sản phẩm | Khuyến nghị trong FIX-LOG.md. |

Phần dưới là báo cáo gốc của lượt test trước khi sửa (giữ làm bằng chứng).

---

# Kết quả test giao diện và danh sách lỗi (ngày 10/11/2026)

## Số liệu lượt chạy cuối (chạy bằng `bash docs/ui-test/run_all.sh`: reset DB -> API -> ui_test.py -> ui_test_extra.py)
| Bộ test | Kết quả | Log |
|---|---|---|
| ui_test.py (luồng chính A-M) | **32 PASS / 0 FAIL**, HTTP lỗi 2 (401 đăng nhập sai, 503 stt-token: chủ đích), JS lỗi 2 (chính là 2 dòng console của 401/503) | `ui-test-20261110-094835.log` |
| ui_test_extra.py (mở rộng, 38 ca) | **37 PASS / 1 FAIL** (Z2 = BUG-001) ; HTTP lỗi 3 (503 stt-token), request fail 4 và console `ERR_INTERNET_DISCONNECTED/ERR_FAILED` do cố ý giả lập offline | `ui-test-extra-20261110-095137.log` |
| Server | `api.log` (API chạy từ run_all.sh) | `api.log` |

Xác nhận: cảnh báo **RenderFlex overflow 2px đã hết** (0 dòng "overflow" trong cả 2 log cuối; Chrome headless, màn 420x900).
Mọi ca ghi dữ liệu đều đối chiếu lại server (khách/món/lô/giao dịch/chốt sổ/báo cáo nợ/Reports/Daily): khớp.
Các lượt chạy trước (để lại làm bằng chứng quá trình): `ui-test-20261110-092708.log` (32/32, có RangeError, xem BUG-004), `ui-test-extra-20261110-093253.log` (29/9: toàn lỗi script, đã sửa, xem mục "Lỗi do script").
Ảnh lỗi: `shots/`. Kế hoạch ca: `../KE-HOACH-TEST.md`.

## Lỗi thật của app/backend

### BUG-001 (Trung bình) - Giao dịch chờ đồng bộ không được thử lại khi server không với tới nhưng máy vẫn "có mạng"
- Mô tả: đồng bộ chỉ chạy khi mở app (`start()`) và khi trạng thái kết nối đổi (`onConnectivityChanged`) hoặc bấm tay ở Tài khoản. Nếu lần đẩy outbox thất bại vì server tạm chết/đứt đường tới server (thiết bị vẫn báo có mạng), không có bộ hẹn giờ thử lại.
- Tái hiện (ca Z2): chặn mọi request tới `localhost:5299` (`ctx.route(... abort)`), ghi câu "Reload thử chi mua đá chín chục" ở Quầy và Lưu vào sổ (POST /Transactions bị `ERR_FAILED`), tải lại trang, bỏ chặn, đợi 75 giây.
- Thực tế: giao dịch vẫn hiện trong Sổ (không mất) nhưng KHÔNG lên server trong 75 giây; nó chỉ lên server (02:58:26Z) khi tôi tải lại trang ở ca Z3 (đồng bộ lúc khởi động). Mong đợi: tự thử lại định kỳ (ví dụ 30-60s, có lùi dần) hoặc khi app quay lại foreground.
- Đối chứng: ca O1 (giả lập offline thật bằng `set_offline`, có sự kiện connectivity) tự đồng bộ sau 3 giây: PASS.
- Bằng chứng: `ui-test-extra-20261110-095137.log` (dòng FAIL Z2, các REQFAILED lúc 09:56:29/09:56:52), ảnh `shots/20261110-095137-extra-Z2.png`.
- Nghi ngờ nguyên nhân: `app/lib/core/sync/sync_service.dart` `start()` (khoảng dòng 75-88) chỉ nghe connectivity + sync một lần; `_run()` khi `push.completed == false` chỉ đặt trạng thái `error`, không lên lịch lại.
- Phân loại: **lỗi thật** (độ ưu tiên vừa: dữ liệu không mất, chậm đồng bộ).

### BUG-002 (Thấp) - Nút đổi ngày ở màn Chốt sổ không có tên (tooltip/nhãn) cho trình đọc màn hình
- Mô tả: cây accessibility chỉ hiện `button` rỗng cho hai nút ‹ ›; màn Sổ thì có "Ngày trước"/"Ngày sau".
- Tái hiện: tab Chốt sổ, xem aria snapshot (log `ui-test-20261110-092708.log`, dòng "Chốt sổ: ... - button - button [disabled]"). Thực tế: không có tên; mong đợi: có nhãn "Ngày trước"/"Ngày sau". Cũng làm test tự động không tìm được nút theo tên.
- Nghi ngờ: `app/lib/features/settlements/presentation/settlement_screen.dart` dòng ~207-225 (`IconButton` `settle_prev`/`settle_next` thiếu `tooltip`).
- Phân loại: lỗi thật (nhỏ, khả năng tiếp cận).

### BUG-003 (Thấp) - Backend ghi log ERR "responded 500" cho lỗi nghiệp vụ mà client nhận mã 401/503
- Tái hiện: đăng nhập sai và gọi `GET /Voice/stt-token` khi chưa cấu hình Blaze. Client nhận 401 / 503, nhưng `api.log` ghi `[ERR] HTTP POST /api/v1/Auth/login responded 500` và `[ERR] HTTP GET /api/v1/Voice/stt-token responded 500` kèm stack (dòng 18-23, 69-75).
- Thực tế vs mong đợi: log nên ghi đúng mã trả về (401/503) và mức WARN, không phải 500/ERR (gây nhiễu khi giám sát).
- Nghi ngờ: middleware ghi log request chạy trước/độc lập với bộ xử lý exception -> mã trạng thái chưa được set khi ghi log (`LoggingBehavior.cs`, middleware xử lý lỗi trong `BanHang.WebAPI`).
- Phân loại: lỗi thật (chỉ ảnh hưởng log, hành vi API đúng).

### BUG-004 (Thấp, không ổn định) - `RangeError (start): Invalid value: Not in inclusive range 0..32: 37` (và `...: 40`) trên console khi gõ câu ở Quầy
- Xảy ra 1/4 lượt chạy ui_test.py (lượt 092708), đúng lúc ca F3 ("Chị Hoa trả nợ một trăm"); 3 lượt sau (093833, 094835 và các lượt khác) không tái hiện. Giao diện vẫn đúng, ca PASS.
- Bằng chứng: `ui-test-20261110-092708.log` dòng 23-24.
- Nguyên nhân chưa xác định: chuỗi dài 32 mà vị trí 37/40 nghĩa là vùng chọn (selection) của ô nhập còn cũ sau khi `_input.clear()`/điền lại; nhiều khả năng là tương tác giữa Playwright `fill` và lớp text-editing của Flutter web, không chắc là lỗi người dùng thật gặp. Cần lặp lại nhiều lần mới kết luận.
- Phân loại: chưa rõ (nghi do script/engine), ghi nhận để theo dõi.

### Quan sát (không phải lỗi, cần chủ sản phẩm quyết định)
- Đăng nhập sai 5 lần liên tiếp không bị khóa/làm chậm (R1/R2 PASS: sau đó đăng nhập đúng vẫn vào). Tốt cho "không khóa nhầm" nhưng chưa có chống dò mật khẩu.
- Cây accessibility lặp nhãn: "Quay lại Quay lại", "Ngày trước Ngày trước", "= 380.000 đ đ" (nhãn + tooltip/hậu tố đ lặp). Thấp, khả năng là hành vi Flutter web.

## Hành vi chủ đích (bình thường)
- HTTP 401 POST /Auth/login khi đăng nhập sai (A2, R1).
- HTTP 503 GET /Voice/stt-token: server chưa cấu hình `Blaze:Token`.
- `net::ERR_INTERNET_DISCONNECTED` / `ERR_FAILED`: do chủ động giả lập offline (O1, O2, Z2).
- Danh sách Sổ chỉ dựng các dòng trong khung nhìn (ListView lười) nên script chỉ chọn dòng đang hiển thị.
- Câu "hai trăm tám chục" cho 2.800.000 (thẻ vàng "Chưa chắc"): cách nói mơ hồ; app không tự ghi, đúng thiết kế.

## Lỗi do script test (đã sửa, đã chạy lại)
- R4: dùng sai đường dẫn `/api/v1/Role` (404) -> đổi `/api/v1/Role/List` (server trả 403, đúng).
- S1: cây accessibility không đưa giá trị ô nhập vào snapshot cho tới khi ô được focus -> thêm `fval()` (focus rồi `input_value()`); P1/P3 cũng đọc "Số cân" bằng `fval()`. S2 lỗi dây chuyền từ S1.
- Q5: câu thử "hai trăm tám chục" bị hiểu mơ hồ (thẻ vàng) và có tiền tố "Tự ghi" -> đổi câu thành "Chị Hoa, nạc vai, hai cân, hai trăm tám".
- L2: dòng cần mở nằm ngoài khung nhìn (ListView lười) -> chọn dòng 300k đang hiển thị.
- Z1/Z3: `reload()` mặc định 8s quá ngắn khi Flutter web nạp -> `timeout=90000`.
- Z2: `set_offline(True)` chặn luôn việc tải lại app từ :50792 -> chuyển sang chặn riêng route API (`ctx.route`). Sau khi sửa, ca này lộ ra BUG-001.
- Y1: lỗi dây chuyền do reload thất bại.

## Kết luận
Không có lỗi chức năng nghiêm trọng: sửa/xóa khách-món-lô (có xác nhận), Hoàn tác, thẻ chỉnh tay (đổi loại, sửa tiền, Trả hết/Ghi nợ hết), Tự ghi câu chắc chắn, Thu nợ, điều hướng ngày ở Sổ, sửa/xóa giao dịch từ Sổ, chốt sổ khớp/thừa/thiếu và chốt lại cùng ngày (1 bản ghi/ngày), quyền Seller (UI + server 403), parser câu khó, offline->đồng bộ, reload giữa chừng đều đúng cả giao diện lẫn dữ liệu server. Lỗi thật còn lại: BUG-001 (Trung bình), BUG-002/003 (Thấp), BUG-004 (Thấp, không ổn định).
