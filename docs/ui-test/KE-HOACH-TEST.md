# Kế hoạch test giao diện (Flutter web + Playwright)

Công cụ: `ui_test.py` (luồng chính, 32 ca) và `ui_test_extra.py` (mở rộng). Chạy đầy đủ: `bash docs/ui-test/run_all.sh`
(reset DB MySQL local -> chạy API :5299 -> `ui_test.py` -> `ui_test_extra.py`). App web phải đang chạy ở :50792.

Cách kiểm: đọc cây accessibility `flt-semantics` của Flutter (aria_snapshot); mọi ca ghi dữ liệu đều đối chiếu lại **server**
bằng API với token admin (có chờ đồng bộ tối đa 45-75s). Log: `logs/ui-test-<giờ>.log`, `logs/ui-test-extra-<giờ>.log`, `logs/api.log`;
ảnh lỗi: `logs/shots/`; kết quả máy đọc: `logs/results.json`, `logs/results-extra.json`. Lỗi tìm được: `logs/FINDINGS.md`.

Tài khoản: admin, bo, me (Seller) với mật khẩu seed trong .env (Seed__*Password). Tiền: đồng; "ba trăm tám" = 380.000; "chục" = 10.000.

## Nhóm A-M: luồng chính (ui_test.py)

| Mã | Mục tiêu | Bước | Mong đợi |
|---|---|---|---|
| A0 | Mở app | vào `/#/login` | thấy màn Đăng nhập |
| A1 | Form trống | bấm Đăng nhập khi trống | ở lại login |
| A2 | Sai mật khẩu | bo / sai | ở lại login (HTTP 401 là chủ đích) |
| A3 | Đăng nhập đúng | bo/<mật khẩu seed> | vào Quầy |
| B1 | Điều hướng | lần lượt 5 tab | đúng tiêu đề từng màn |
| C1-C5 | Khách | thêm 2 khách, SĐT sai, tìm theo biệt danh | lưu; SĐT sai không lưu; tìm đúng |
| D1-D3 | Món | thêm 3 món | giá hiển thị đúng |
| E1 | Lô | thêm lô 2 con, 8tr, chi phí 300k | hiện 8.000.000 |
| F1-F9 | Quầy | gõ 7 câu bán/thu nợ/mua lợn/chi/mang đi/lẻ; câu vô nghĩa; "Xóa câu vừa rồi" | thẻ đúng, lưu/không lưu đúng, hộp thoại xóa |
| G1-G2 | Sổ hôm nay | xem tổng | doanh thu 580k, thu nợ 100k, mua+chi 9.850.000, mang đi 15tr |
| H1 | Nợ | xem Chị Hoa | nợ 100.000 và chi tiết |
| I1 | Chốt sổ | đầu ngày 30tr, két 5tr | chênh lệch Thiếu 630.000, lưu |
| J1 | Tiền đi chợ | 2 con x 4tr + nợ mối 500k + 10% | 9.300.000 |
| K1 | Tài khoản | mở | hiện Bố bo / Seller / Đăng xuất |
| L1 | Đồng bộ | gọi API | khách 2, món 3, lô 1, giao dịch >=6, chốt sổ 1, báo cáo khớp |
| M1-M2 | Reload / đăng xuất | tải lại; Đăng xuất | còn đăng nhập + dữ liệu; về login |

## Nhóm mở rộng (ui_test_extra.py)

| Mã | Mục tiêu | Bước | Mong đợi (UI + server) |
|---|---|---|---|
| R0 | Mở app | vào login | thấy Đăng nhập |
| R1 | Đăng nhập sai nhiều lần | me + 5 mật khẩu sai | luôn ở login |
| R2 | Không khóa nhầm | sau R1 đăng nhập đúng me/<mật khẩu seed> | vào Quầy |
| R3 | Quyền Seller trên UI | mở Khác, Tài khoản | có Khách/Món/Lô/Tiền đi chợ/Tài khoản; không có mục quản lý user; vai Seller |
| R4 | Quyền Seller trên server | me gọi GET /Users, /Role/List, /Permission/Mine | 401/403; không có quyền Users |
| R5 | Đổi tài khoản | đăng xuất me, đăng nhập bo | vào Quầy |
| S1 | Sửa khách | mở Anh Tư, đổi tên + SĐT, lưu, mở lại | list + form có giá trị mới; server cập nhật |
| S2 | Sửa món | Nạc vai 130k -> 140k | hiện 140.000; server pricePerKg=140000 |
| S3 | Sửa lô | chi phí 300k -> 350k, mở lại | hiện 350.000; server otherCost=350000 |
| X1 | Xóa khách | tạo "Khách Xóa Thử"; Xóa -> Hủy; Xóa -> Xóa | Hủy: còn; Xóa: mất; server isDeleted |
| X2 | Xóa món | như X1 | như X1 |
| X3 | Xóa lô | tạo lô 1.234.567, xóa | chỉ lô đó bị xóa, lô 8tr còn |
| Q1 | Hoàn tác | ghi 1 câu, bấm Hoàn tác ở "Vừa ghi" | mục biến mất, mất khỏi Sổ, server isDeleted |
| Q2 | Thẻ chỉnh tay: nợ/trả | nhập Tổng tiền 300k; Ghi nợ hết; Trả hết; Ghi nợ hết; lưu | Đã trả 0/300k theo nút; server amount 300k paid 0 |
| Q3 | Thẻ chỉnh tay: đổi loại | đổi sang Chi khác, tiền 77k, ghi chú | server type Expense, 77k, note |
| Q4 | Thẻ thiếu tiền | để trống tiền, Lưu vào sổ | báo "Nhập số tiền", thẻ không đóng |
| Q5 | Tự ghi câu chắc chắn | bật công tắc; gõ câu xanh; gõ câu vô nghĩa | câu xanh tự lưu, không thẻ, hiện "Vừa ghi", server +1; câu vô nghĩa vẫn hiện thẻ |
| D1 | Thu nợ | Nợ > Chị Hoa > Thu nợ 50k | nợ giảm 50k trên UI + server |
| L1 | Điều hướng ngày | Ngày trước, Ngày sau | lùi: trống + ngày hôm qua; Ngày sau về Hôm nay và bị khóa |
| L2 | Sửa giao dịch ở Sổ | mở dòng 300k, đổi 320k, Lưu sửa | UI 320.000; server amount 320000 |
| L3 | Xóa giao dịch ở Sổ | mở dòng, Xóa -> Hủy; Xóa -> Xóa | Hủy: còn; Xóa: server isDeleted |
| C1-C3 | Chốt sổ khớp/thừa/thiếu | đặt két đếm = sổ, +12.000, -34.000, lưu | hiện Khớp/Thừa/Thiếu; server countedCash/expectedCash đúng |
| C4 | Chốt lại cùng ngày | sau C1-C3 | chỉ 1 bản ghi/ngày, nút "Chốt lại" |
| P1-P3 | Parser số lẻ | "hai cân rưỡi", "một củ", "ba cân hai" | 2,5 kg; 1.000.000; 3,2 kg |
| P4 | Khách không tồn tại | "Cô Lan hai cân nạc vai hai trăm" | gợi ý "Thêm Lan vào danh bạ" |
| P5 | Tên mờ | "Chị Hoà ..." | khớp Chị Hoa |
| P6 | "hai trăm tám lăm nghìn" | | 285.000 |
| P7 | Câu rỗng/dấu cách | gửi | không tạo thẻ |
| O1 | Offline -> tự đồng bộ | `set_offline(True)`; ghi 1 câu; bật mạng | lưu cục bộ, server chưa có; sau khi có mạng tự lên server |
| O2 | Duyệt offline | offline mở Sổ/Nợ | không lỗi |
| Z1 | Reload giữa chừng | mở thẻ, tải lại | còn đăng nhập, không ghi bừa |
| Z2 | Reload khi còn hàng đợi | offline ghi, reload, bật mạng | dữ liệu còn, tự lên server |
| Z3 | Reload nhiều lần | tải lại 3 lần | Sổ vẫn đủ |
| Y1 | Đối chiếu số liệu | so Sổ UI với Reports/Daily | doanh thu, thu nợ khớp |

## Phân loại kết quả
- **lỗi thật**: app/backend sai. **lỗi script**: sai kỳ vọng/thao tác của script (đã sửa và chạy lại). **chủ đích**: HTTP 401 (đăng nhập sai), 503 Voice/stt-token (chưa cấu hình token Blaze), `ERR_INTERNET_DISCONNECTED` khi giả lập offline.
- Giới hạn của kỹ thuật: Flutter dựng danh sách lười nên dòng ngoài màn hình không có trong cây accessibility (script chọn dòng đang hiển thị).
