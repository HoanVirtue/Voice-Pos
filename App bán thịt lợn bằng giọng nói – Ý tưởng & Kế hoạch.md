# App bán thịt lợn bằng giọng nói – Ý tưởng & Kế hoạch

Nov 8, 2026 · @LHT

Mục tiêu: bố mẹ chỉ cần **nói** trong lúc bán, app tự ghi sổ. Đến tối, app cho biết ngay doanh thu, công nợ, lãi và số tiền cần mang đi chợ, không phải cộng sổ tay nữa.

## Bối cảnh và vấn đề

| Vấn đề hiện tại | Hệ quả | App cần giải quyết |
| --- | --- | --- |
| Tay bẩn vì thái thịt | Không chạm được điện thoại | Ghi hoàn toàn bằng giọng nói, không cần chạm |
| Nhiều khách cùng lúc | Dễ quên, ghi sót, nhầm người | Mỗi câu nói là một giao dịch độc lập, ghi nhanh trong 3–5 giây |
| Tối phải cộng sổ thủ công | Mất 30–60 phút, dễ sai | Tự tổng kết cuối ngày |
| Khách nợ ghi rải rác | Khó nhớ ai nợ bao nhiêu, từ bao giờ | Sổ nợ theo từng khách, có lịch sử |
| Không rõ lãi thật | Chỉ biết tiền thu, không biết lãi | Ghi giá nhập lợn và chi phí để tính lãi |

Người dùng chính là bố mẹ: lớn tuổi, ít thao tác app, cần chữ to, ít nút, nói tiếng Việt tự nhiên (có thể giọng địa phương).

## Ý tưởng cốt lõi: "Nói là ghi"

Bố mẹ nói một câu ngắn, app tự hiểu và biến thành một dòng sổ, không cần chạm màn hình. Chỉ cần nói gần theo một thứ tự quen thuộc: tên – món – cân – tiền – nợ.

Ví dụ câu nói và cách app ghi:

| Bố mẹ nói | App hiểu là |
| --- | --- |
| "Cô Lan lấy hai cân ba chỉ, ba trăm tám, đưa tiền rồi" | Bán · khách: cô Lan · 2 kg ba chỉ · 380.000đ · đã trả |
| "Chị Hà góc chợ lấy cân rưỡi nạc vai, hai trăm, ghi nợ" | Bán · chị Hà (góc chợ) · 1,5 kg nạc vai · 200.000đ · nợ |
| "Khách lẻ năm chục" | Bán · khách lẻ · 50.000đ · đã trả |
| "Anh Tú trả nợ một triệu" | Thu nợ · anh Tú · 1.000.000đ |
| "Mang đi chợ mười lăm triệu mua hai con lợn" | Chi nhập hàng · 15.000.000đ · 2 con |
| "Sửa lại cô Lan ba trăm sáu" / "Xóa cái vừa rồi" | Sửa / xóa giao dịch gần nhất |

Ba nguyên tắc thiết kế:

1. **Rảnh tay hoàn toàn:** bắt đầu ghi bằng từ khóa hoặc nút vật lý, không chạm màn hình.
2. **Ghi trước, sửa sau:** lúc đông khách cứ nói, app ghi nháp; câu nào app không chắc thì đánh dấu vàng để tối xem lại. Luôn giữ file ghi âm gốc.
3. **Phản hồi bằng tiếng:** app đọc lại ngắn "Cô Lan, ba trăm tám, đã trả" để bố mẹ biết đã ghi đúng, không cần nhìn màn hình.

## Cách dùng tại quầy

Khuyến nghị: một điện thoại cũ hoặc iPad gắn cố định ở quầy, luôn cắm sạc, màn hình luôn sáng, kèm tai nghe bluetooth có nút bấm.

**Cách kích hoạt ghi âm (không chạm màn hình), xếp theo mức đề xuất:**

| Cách | Cách làm | Ưu | Nhược |
| --- | --- | --- | --- |
| Nút bấm bluetooth (khuyên dùng) | Nút remote chụp ảnh \~50–80k hoặc nút tai nghe; dùng khuỷu tay/mặt tay bấm 1 lần để bắt đầu, 1 lần để kết thúc | Chính xác, không ghi nhầm tiếng ồn | Vẫn phải bấm (nhưng không cần tay sạch) |
| Từ khóa đánh thức | Nói "Ghi sổ…" rồi nói nội dung | Rảnh tay 100% | Chợ ồn dễ nhận nhầm; tốn pin |
| Ghi âm liên tục cả buổi | Thu cả phiên chợ, AI tự tách câu ghi sổ | Không phải làm gì | Ghi cả hội thoại riêng tư của khách; AI dễ lẫn; tốn chi phí |
| Siri Shortcut | "Hey Siri, ghi sổ" mở app và bắt đầu ghi | Có sẵn trên iPhone | Siri tiếng Việt còn hạn chế, cần thử trước |

Gợi ý: làm nút bấm bluetooth trước, thử từ khóa sau. Mic cài áo hoặc tai nghe giúp thu rõ hơn giữa chợ ồn.

**Khi nhiều khách cùng lúc:**

- Mỗi lần bấm = một khách. Bán xong ai nói người đó, không cần theo thứ tự.
- Khách lẻ không cần tên, chỉ cần số tiền: "Lẻ bảy mươi".
- Chỉ khách **nợ** mới bắt buộc có tên. App tự khớp với danh bạ khách quen ("cô Lan" → cô Lan bán rau).
- Câu nói xử lý ngầm, không bắt chờ. Whisper chạy ngay trên máy nên mất mạng vẫn ghi được.
- Có thể dùng 2 máy (bố và mẹ) cùng ghi vào một sổ.

**Cuối ngày (tay đã sạch):** mở app trên điện thoại, xem các dòng đánh dấu vàng, nghe lại file ghi âm nếu cần, bấm "Chốt sổ".

## Tính năng

| Nhóm | Tính năng | Giai đoạn |
| --- | --- | --- |
| Ghi sổ bằng giọng nói | Ghi âm → chuyển chữ (Whisper) → bộ phân tích tách: khách, món, kg, tiền, trả/nợ; đọc lại xác nhận | MVP |
| Ghi sổ bằng giọng nói | Sửa/xóa bằng lời nói, đánh dấu câu chưa chắc | MVP |
| Bán hàng | Danh sách giao dịch trong ngày, lọc theo khách / đã trả / nợ | MVP |
| Công nợ | Sổ nợ từng khách: tổng nợ, lịch sử mua/trả, nợ bao lâu | MVP |
| Công nợ | Hỏi bằng giọng: "Cô Lan nợ bao nhiêu?" → app đọc to | Giai đoạn 2 |
| Tiền mặt / đi chợ | Ghi tiền mang đi, tiền mua lợn, tiền trả mối/khách, tiền còn lại | MVP |
| Tiền mặt / đi chợ | Gợi ý số tiền nên mang đi chợ ngày mai | Giai đoạn 2 |
| Báo cáo | Chốt sổ cuối ngày: doanh thu, thu tiền mặt, nợ mới, thu nợ, chi, lãi | MVP |
| Báo cáo | Biểu đồ theo tuần/tháng, lãi theo con lợn | Giai đoạn 2 |
| Danh mục | Danh bạ khách quen (tên gọi + biệt danh), bảng giá món (ba chỉ, nạc vai, xương…) | MVP |
| Đồng bộ | Dùng trên iPhone và Android; nhiều máy một sổ; chạy khi mất mạng | MVP |
| Xuất file | Xuất Excel theo tháng, sao lưu | Giai đoạn 2 |
| Nâng cao | Nhắn Zalo nhắc nợ cho khách, cân điện tử kết nối bluetooth | Giai đoạn 3 |

**Màn hình chốt sổ cuối ngày (mẫu):**

```
CHỐT SỔ NGÀY 08/11
Doanh thu bán:          12.450.000đ   (64 lượt)
  - Khách trả ngay:      10.200.000đ
  - Ghi nợ mới:           2.250.000đ   (5 khách)
Thu nợ cũ:               1.000.000đ
Tiền mặt thu trong ngày: 11.200.000đ
Chi mua lợn:              9.800.000đ
Lãi gộp ước tính:         2.650.000đ
Tổng khách đang nợ:     8.700.000đ   (14 khách)
→ Gợi ý mang đi chợ mai: 10.000.000đ
```

(Số liệu chỉ là ví dụ minh họa.)

## Dữ liệu và cách tính

Mọi thứ quy về một bảng "giao dịch" duy nhất, mỗi câu nói tạo một dòng. Nhờ vậy tổng kết chỉ là cộng theo loại.

| Bảng | Trường chính |
| --- | --- |
| Giao dịch | thời gian, loại (bán / thu nợ / mua lợn / chi khác / mang tiền đi), khách, món, số kg, số tiền, đã trả hay nợ, file ghi âm, câu chữ gốc, độ tin cậy, người ghi |
| Khách hàng | tên, biệt danh/cách gọi, số điện thoại, ghi chú |
| Món hàng | tên (ba chỉ, nạc vai, sườn, xương…), giá/kg hiện tại |
| Lô hàng (con lợn) | ngày mua, số con, kg hơi/kg móc, tiền mua, chi phí mổ/chở |
| Chốt sổ ngày | ngày, tiền đầu ngày, tiền đếm thực tế, chênh lệch, ghi chú |

**Công thức chính:**

- Doanh thu ngày = tổng tiền các giao dịch bán (cả trả ngay và nợ).
- Tiền mặt thu = bán trả ngay + thu nợ cũ.
- Nợ của một khách = tổng bán nợ − tổng đã trả.
- Lãi theo lô = doanh thu bán hết lô − tiền mua lợn − chi phí (mổ, chở, đá, túi…).
- Tiền còn trong tay = tiền đầu ngày + tiền mặt thu − tiền chi.
- Gợi ý mang đi chợ = giá lợn dự kiến × số con cần mua + nợ cần trả mối + dự phòng (ví dụ 10%). Ban đầu bố mẹ tự nói số, sau vài tuần app học theo trung bình.

**Về lãi:** lợn mua hôm nay có thể bán 1–2 ngày, nên lãi chính xác nên tính **theo lô** (theo con lợn), còn lãi theo ngày chỉ là ước tính. Cần hỏi bố mẹ cách họ đang tính để app khớp với thói quen.

**Đối chiếu tiền mặt:** tối bố mẹ đếm két và nói "Két có mười một triệu hai". App so với số trên sổ và báo chênh lệch — cách nhanh nhất để phát hiện câu ghi sót.

## Kiến trúc kỹ thuật

**Phạm vi:** chỉ làm app điện thoại (iPhone + Android), không làm web. Xem sổ, sửa và chốt sổ đều trên app. Nhận giọng nói bằng **Whisper** (mã nguồn mở, tự chạy, không trả phí theo lượt) và hiểu câu bằng bộ quy tắc, đều chạy ngay trên điện thoại.

**Công nghệ:** React Native (Expo, TypeScript) cho app · ASP.NET Core Web API (.NET 10) cho máy chủ · PostgreSQL · Whisper (whisper.rn trên điện thoại, Whisper.net trên máy chủ).

```
App React Native (iPhone / Android)
  Nút BT ─► Ghi âm WAV 16 kHz (VAD cắt khoảng lặng)
              │
              ▼
          Whisper trên máy (whisper.rn, model small)
              │ câu chữ
              ▼
          Bộ phân tích câu (TypeScript, theo quy tắc)
              │ giao dịch + độ tin cậy
              ▼
  SQLite trên máy ─► Đọc lại (giọng có sẵn) ─► Màn hình sổ
              │ hàng đợi đồng bộ (dữ liệu + file ghi âm câu vàng/đỏ)
              ▼ HTTPS khi có mạng
ASP.NET Core Web API ─► PostgreSQL
  - đồng bộ 2 máy · sao lưu · báo cáo · xuất Excel
  - Whisper.net model lớn (large-v3-turbo): nghe lại câu vàng/đỏ cho chính xác hơn
```

**Vì sao xử lý trên máy:** đọc lại gần như ngay lập tức, vẫn chạy khi mất mạng ở chợ, không tốn phí. API chỉ lo lưu trữ, đồng bộ giữa 2 máy và sao lưu. App chạy độc lập được ngay cả khi chưa có API.

### App (React Native)

| Phần | Công nghệ đề xuất | Ghi chú |
| --- | --- | --- |
| Khung app | React Native + Expo (development build, không dùng Expo Go), TypeScript, expo-router | Cần module native cho nút BT và STT |
| Nhận giọng nói | whisper.rn (whisper.cpp cho React Native), model small lượng tử hóa (~200 MB) hoặc PhoWhisper-small; dùng Core ML/Metal trên iPhone | Đưa tên khách + món vào *prompt* để Whisper nghe đúng tên riêng hơn; tải model về ở lần mở app đầu tiên, không nhúng vào file cài |
| Nút bluetooth | Expo Module tự viết: iOS dùng MPRemoteCommandCenter, Android bắt KeyEvent | Phần rủi ro nhất, làm thử đầu tiên |
| Đọc lại | expo-speech (giọng tiếng Việt có sẵn) | Phát qua tai nghe để khách không nghe chuyện nợ |
| Lưu dữ liệu | expo-sqlite + Drizzle ORM | Dữ liệu chính nằm trên máy (offline-first) |
| Ghi âm | expo-audio, ghi WAV 16 kHz mono; luôn lưu file, tự xóa sau 30 ngày | Để Whisper xử lý, để tối nghe lại và gửi lên máy chủ nghe lại |
| Trạng thái, gọi API | Zustand + fetch/TanStack Query | |
| Giữ màn hình sáng | expo-keep-awake | Máy ở quầy luôn cắm sạc |

**Các màn hình:**

1. **Quầy:** màn chờ ghi, chữ thật to: trạng thái (đang nghe / đã ghi), 5 giao dịch gần nhất, tổng tạm trong ngày.
2. **Sổ hôm nay:** danh sách giao dịch, lọc trả/nợ/vàng/đỏ, chạm để sửa, nghe lại ghi âm.
3. **Sổ nợ:** danh sách khách đang nợ, chi tiết từng khách (mua, trả, nợ bao lâu).
4. **Tiền & chốt sổ:** tiền đầu ngày, mang đi chợ, mua lợn, đếm két, chênh lệch, nút "Chốt sổ".
5. **Danh mục:** khách quen + biệt danh, món + giá, từ điển tiếng chợ.
6. **Báo cáo:** tuần/tháng, lãi theo lô.

### API (ASP.NET Core)

| Phần | Công nghệ |
| --- | --- |
| Nền tảng | .NET 10 (LTS), ASP.NET Core Web API (Minimal API hoặc Controller) |
| CSDL | PostgreSQL + EF Core (dùng SQL Server nếu bạn quen hơn) |
| Đăng nhập | JWT; mỗi gia đình là một "sổ" (Book), mỗi máy một tài khoản/thiết bị |
| Xuất Excel | ClosedXML |
| Nhận giọng nói | Whisper.net (whisper.cpp cho .NET), model large-v3-turbo hoặc PhoWhisper-medium; chạy được trên CPU, có GPU thì nhanh hơn |
| Log | Serilog |
| Triển khai | Docker trên VPS nhỏ, hoặc máy chủ/Azure sẵn có |

**Các endpoint chính:**

| Method | Đường dẫn | Việc |
| --- | --- | --- |
| POST | /api/auth/login | Đăng nhập, cấp JWT |
| POST | /api/sync/push | Máy gửi các thay đổi (giao dịch, khách, món, từ điển…) |
| GET | /api/sync/pull?since= | Máy lấy các thay đổi từ máy khác kể từ lần trước |
| GET | /api/reports/daily?date= | Chốt sổ ngày (server tính lại để đối chiếu với máy) |
| GET | /api/reports/range?from=&to= | Báo cáo tuần/tháng |
| GET | /api/export/excel?month= | Xuất Excel theo tháng |
| POST | /api/transcribe | Nhận file ghi âm, chạy Whisper model lớn, trả câu chữ (dùng cho câu vàng/đỏ) |
| POST | /api/parse-failures | Gửi các câu không hiểu để bạn xem và bổ sung quy tắc |

**Đồng bộ (offline-first):**

- Mọi bản ghi có `Id` (GUID tạo trên máy), `BookId`, `UpdatedAt`, `DeletedAt` (xóa mềm), `DeviceId`.
- Ghi vào SQLite trước rồi đưa vào hàng đợi; có mạng thì push, sau đó pull những gì máy khác đã thay đổi.
- Xung đột: bản cập nhật sau thắng (last-write-wins). Cách này đủ vì 2 máy hiếm khi sửa cùng một dòng.
- Danh mục và từ điển cũng đồng bộ: sửa trên máy mẹ thì máy bố nhận được.

**Bảng dữ liệu** (API và SQLite cùng cấu trúc): Books, Devices, Customers (tên, biệt danh), Products (tên, tên gọi khác, giá/kg), DictionaryEntries, Transactions, PigBatches, DailyClosings. Bảng Transactions có thêm: `RawText`, `TranscriptSource` (Whisper trên máy / trên máy chủ), `Confidence`, `Status` (xanh/vàng/đỏ), `AudioPath`.

Công thức báo cáo nằm ở cả app (để xem khi mất mạng) và API (để đối chiếu). Dùng chung một bộ số liệu mẫu để test cả hai bên, tránh hai nơi tính ra hai kết quả khác nhau.

## Nhận diện giọng nói bằng Whisper

Whisper là model nhận giọng nói mã nguồn mở của OpenAI, có hỗ trợ tiếng Việt. Model tự chạy được trên điện thoại hoặc trên máy chủ, không trả phí theo lượt.

### Chạy ở đâu

| Phương án | Ưu | Nhược |
| --- | --- | --- |
| Trên điện thoại (whisper.rn) | Chạy offline, đọc lại ngay, không tốn máy chủ | Chỉ chạy được model nhỏ (small) nên kém chính xác hơn; app nặng thêm ~200 MB; máy cũ chạy chậm, nóng |
| Trên máy chủ (Whisper.net trong ASP.NET Core) | Dùng được model lớn, chính xác hơn | Cần mạng; máy chủ phải mạnh hơn nên tốn tiền hơn; đọc lại chậm hơn |
| **Kết hợp (đề xuất)** | Điện thoại xử lý ngay bằng model small; câu vàng/đỏ gửi lên máy chủ nghe lại bằng model lớn | Phải làm cả hai phía |

Nếu Giai đoạn 0 cho thấy model small trên điện thoại đã đủ chính xác (≥ 90% đúng số tiền) thì bỏ phần Whisper trên máy chủ, chỉ dùng điện thoại.

### Chọn model

| Model | Kích thước gần đúng (bản lượng tử hóa) | Dùng ở | Ghi chú |
| --- | --- | --- | --- |
| tiny / base | 30–60 MB | Không dùng | Tiếng Việt kém |
| small | ~200 MB | Điện thoại | Cân bằng giữa tốc độ và độ chính xác |
| large-v3-turbo | ~550 MB (q5) – 1,6 GB | Máy chủ | Gần bằng large-v3 nhưng nhanh hơn nhiều |
| PhoWhisper (VinAI) small / medium | Như small / medium | Điện thoại / máy chủ | Whisper được huấn luyện thêm cho tiếng Việt, nhiều giọng địa phương; phải chuyển sang định dạng ggml để chạy với whisper.cpp |

Chọn model bằng số đo thật với 100 câu mẫu của bố mẹ ở Giai đoạn 0, không chọn theo cảm tính.

### Cấu hình quan trọng

- Cố định ngôn ngữ `vi`, không để Whisper tự đoán.
- Ghi âm WAV 16 kHz, mono (định dạng Whisper cần).
- **Prompt ban đầu:** tên ~30–50 khách hay mua nhất, tên các món và vài câu mẫu ("Cô Lan, ba chỉ, hai cân, ba trăm tám") để Whisper quen cách nói và cách viết tên. Không đưa quá dài vì sẽ chậm.
- **VAD** (Silero VAD, có trong whisper.cpp/whisper.rn): cắt bỏ khoảng lặng, không đưa đoạn chỉ có tiếng ồn cho Whisper.
- **Lọc "ảo giác":** Whisper hay tự sinh câu khi gặp im lặng/tiếng ồn ("Hãy subscribe cho kênh…", "Cảm ơn các bạn đã theo dõi…"). Bỏ các câu này; câu lặp từ bất thường hoặc không có số tiền → đỏ.
- Nhiệt độ 0, beam search nhỏ (2–5) để kết quả ổn định.
- Mỗi câu chỉ 3–8 giây nên xử lý từng file sau khi bấm dừng, không cần chế độ realtime.
- Mục tiêu tốc độ: câu 5 giây xử lý xong trong khoảng 2 giây trên máy ở quầy. Đo trên máy thật ở Giai đoạn 0.

## Kế hoạch hiểu câu nói (bộ quy tắc, không dùng AI trả phí)

### Luồng xử lý một câu

1. Bấm nút → bíp → ghi âm WAV 16 kHz.
2. Bấm nút lần nữa, hoặc im lặng khoảng 1,5 giây → bíp → dừng ghi; VAD cắt bỏ khoảng lặng đầu và cuối.
3. Whisper trên máy chuyển thành chữ (kèm prompt tên khách, món), lọc câu "ảo giác", rồi đưa vào bộ phân tích.
4. Lưu giao dịch vào SQLite với trạng thái **xanh** (đã hiểu), **vàng** (chưa chắc) hoặc **đỏ** (không hiểu, chỉ lưu câu chữ).
5. Đọc lại: "Cô Lan, ba trăm tám", hoặc "Chưa rõ, tối xem lại".
6. Khi có mạng: file ghi âm của câu vàng/đỏ được gửi lên API để Whisper model lớn nghe lại. Nếu kết quả mới đủ chắc chắn thì tự cập nhật, nhưng vẫn ghi chú để bố mẹ biết.
7. Buổi tối: xem các dòng vàng/đỏ và sửa tay. Mỗi lần sửa được ghi lại để bổ sung từ điển.

### Cách nói quy ước (tập cho bố mẹ)

Không bắt buộc cứng, nhưng nói theo thứ tự này thì máy hiểu tốt nhất:

**[Tên khách] – [món] – [số cân] – [số tiền] – [nợ]**

| Bố mẹ nói | Kết quả |
| --- | --- |
| "Cô Lan, ba chỉ, hai cân, ba trăm tám" | Bán · cô Lan · 2 kg ba chỉ · 380.000đ · đã trả (không nói gì = đã trả) |
| "Chị Hà, nạc vai, cân rưỡi, hai trăm, nợ" | Bán · chị Hà · 1,5 kg · 200.000đ · nợ |
| "Lẻ năm chục" | Bán · khách lẻ · 50.000đ |
| "Anh Tú trả nợ một triệu" | Thu nợ · anh Tú · 1.000.000đ |
| "Mang đi mười lăm triệu" / "Mua lợn chín triệu tám" | Mang tiền đi / Chi nhập hàng |
| "Xóa câu vừa rồi" / "Sửa ba trăm sáu" | Xóa / sửa giao dịch gần nhất |

### Các bước của bộ phân tích (TypeScript, chạy trên máy)

| Bước | Việc | Ví dụ |
| --- | --- | --- |
| 1. Chuẩn hóa | Chữ thường, bỏ dấu câu; giữ thêm một bản không dấu để so khớp; đọc được cả số dạng chữ số mà Whisper hay trả về ("380", "2,5") | "Cô Lan, ba chỉ 2 cân 380" |
| 2. Nhận lệnh | Kiểm tra lệnh xóa/sửa trước tiên | "xóa", "sửa", "nhầm" |
| 3. Loại giao dịch | Theo từ khóa, ưu tiên cụm cụ thể hơn | "trả nợ" → thu nợ; "mang đi", "đi chợ" → mang tiền; "mua lợn", "trả lái" → chi nhập; "mua túi", "mua đá", "chi" → chi khác; còn lại → bán |
| 4. Tách số | Bộ đọc số tiếng Việt, kể cả tiếng lóng | "ba trăm tám" = 380; "hai trăm rưỡi" = 250; "một triệu hai" = 1.200; "một củ" = 1.000; "một lít" = 100; "năm chục" = 50; "cân rưỡi" = 1,5; "năm lạng" = 0,5 |
| 5. Số là cân hay tiền | Đi kèm "cân/ký/kg/lạng" → cân; đi kèm "nghìn/trăm/triệu/củ/lít/chục" → tiền; số trơn: dưới 10 → cân, từ 10 trở lên → tiền (nghìn đồng); kiểm tra lại với bảng giá | |
| 6. Nhận món | So với danh sách món và tên gọi khác | "ba rọi" = ba chỉ |
| 7. Nhận khách | Lấy phần chữ còn lại ở đầu câu, so gần đúng (Levenshtein trên bản không dấu) với tên + biệt danh trong danh bạ; "lẻ", "khách lẻ" → khách lẻ | "cô lan" → Cô Lan (bán rau) |
| 8. Trả hay nợ | "nợ", "ghi sổ", "ghi nợ", "để đấy", "mai trả" → nợ; mặc định là đã trả | |
| 9. Độ tin cậy | Cộng/trừ điểm theo quy tắc đánh dấu bên dưới | |

Trường hợp thiếu: chỉ có cân mà không có tiền → tự tính tiền = cân × giá, đánh vàng. Chỉ có tiền → vẫn xanh (khách mua theo tiền).

### Quy tắc đánh dấu

- **Đỏ (không hiểu):** không tìm được số tiền và cũng không tính được từ cân × giá.
- **Vàng (chưa chắc):**
  - Ghi nợ nhưng không khớp khách nào, hoặc khớp từ 2 khách trở lên.
  - Tiền lệch quá ~20% so với cân × giá.
  - Tên khớp với độ giống thấp.
  - Số tiền bất thường (ví dụ trên 3 triệu cho một lượt bán).
  - Còn nhiều từ không hiểu trong câu.
- **Xanh:** các trường hợp còn lại.

### Từ điển tiếng chợ

Lưu trong bảng DictionaryEntries, sửa được ngay trong app, đồng bộ qua API. Thêm từ mới không cần cập nhật app.

| Cách nói | Loại | Giá trị |
| --- | --- | --- |
| "trăm", "nghìn", "chục" | Đơn vị tiền | × 100 / × 1 / × 10 (nghìn đồng) |
| "triệu", "củ" | Đơn vị tiền | × 1.000 (nghìn đồng) |
| "lít" | Đơn vị tiền (tiếng lóng) | × 100 (nghìn đồng) |
| "rưỡi" | Hậu tố số | + nửa đơn vị trước nó |
| "cân", "ký", "kg" | Đơn vị cân | × 1 kg |
| "lạng" | Đơn vị cân | × 0,1 kg |
| "nợ", "ghi sổ", "để đấy", "mai trả" | Trạng thái | Nợ |
| "đưa rồi", "trả rồi" | Trạng thái | Đã trả |
| "ba rọi", "thịt ba chỉ" | Món | Ba chỉ |

### Kiểm thử bộ phân tích

- File test gồm 100+ câu thật (câu chữ Whisper trả về → kết quả mong đợi), chạy bằng Jest mỗi lần sửa quy tắc.
- Mục tiêu MVP: ≥ 95% đúng số tiền; ≥ 90% đúng khách ở các câu nợ; không có câu nào sai số tiền mà vẫn được đánh xanh.
- Câu vàng/đỏ được gửi lên API (/api/parse-failures). Mỗi tuần bạn xem lại, bổ sung quy tắc hoặc từ điển, rồi thêm câu đó vào bộ test.

### Nếu sau này cần AI

Chỉ cần thêm một endpoint trên API (POST /api/parse-ai) để xử lý riêng các câu đỏ khi có mạng; app gần như không phải sửa. Khi đó chỉ tốn tiền cho vài câu mỗi ngày.

## Cấu trúc dự án

```
banhang/
├─ mobile/                    React Native + Expo
│  ├─ app/                    màn hình (expo-router)
│  ├─ modules/bt-button/      module native nút bluetooth (iOS + Android)
│  └─ src/
│     ├─ voice/               ghi âm, VAD, Whisper (whisper.rn), TTS, luồng bấm nút → ghi → đọc lại
│     ├─ parser/              bộ phân tích câu + bộ test Jest
│     ├─ db/                  schema SQLite (Drizzle), truy vấn
│     ├─ sync/                hàng đợi, push/pull
│     └─ reports/             công thức chốt sổ, công nợ
└─ api/                       ASP.NET Core (.NET 10)
   ├─ BanHang.Api/            endpoints, JWT
   ├─ BanHang.Domain/         entities, công thức báo cáo
   ├─ BanHang.Infrastructure/ EF Core + PostgreSQL, migrations, ClosedXML, Whisper.net
   └─ BanHang.Tests/          xUnit
```

## Lộ trình

Giả định: một người làm buổi tối/cuối tuần, khoảng 10–15 giờ/tuần.

| Giai đoạn | Thời gian | Việc chính | Kết quả cần đạt |
| --- | --- | --- | --- |
| 0. Khảo sát & thử nghiệm | Tuần 1–2 | Hỏi bố mẹ (danh sách bên dưới); ghi âm 1 buổi chợ; thu 100 câu mẫu; chạy chúng qua các model Whisper trên máy tính (small, medium, large-v3-turbo, PhoWhisper); làm app thử nhỏ: nút BT + whisper.rn trên iPhone và Android, chỉ hiện câu chữ | Chọn được model Whisper cho điện thoại và cho máy chủ, biết tốc độ trên máy thật, biết nút nào dùng được, chốt dùng iPhone hay thêm máy Android ở quầy |
| 1. App ghi sổ (chưa có API) | Tuần 3–4 | Bộ phân tích + bộ test Jest; SQLite; màn Quầy + Sổ hôm nay; đọc lại; sửa/xóa bằng lời | Bố mẹ dùng thử 2–3 buổi, vẫn ghi sổ tay song song |
| 2. API & đồng bộ | Tuần 5–6 | ASP.NET Core: JWT, sync push/pull, danh mục, /api/transcribe với Whisper.net, triển khai Docker; app đồng bộ khi có mạng | 2 máy chung một sổ, có sao lưu trên máy chủ |
| 3. MVP đầy đủ | Tuần 7–8 | Sổ nợ, tiền đi chợ, chốt sổ, đối chiếu két, sửa danh mục/từ điển trong app | Dùng thật hằng ngày, song song sổ tay 2 tuần |
| 4. Bỏ sổ tay | Tuần 9–10 | Sửa quy tắc theo các câu lỗi; báo cáo tuần/tháng; xuất Excel | Chênh lệch két gần như bằng 0 trong 1 tuần → bỏ sổ tay |
| 5. Mở rộng | Sau tuần 10 | Các tính năng Giai đoạn 2, 3 trong bảng tính năng | |

## Chi phí ước tính

| Khoản | Ước tính | Ghi chú |
| --- | --- | --- |
| Nhận giọng nói + hiểu câu | 0đ phí theo lượt | Whisper mã nguồn mở tự chạy + bộ quy tắc tự viết |
| Apple Developer | 99 USD/năm | Cần để cài app lâu dài trên iPhone qua TestFlight (tài khoản miễn phí: app hết hạn sau 7 ngày) |
| Android | 0đ | Cài file APK trực tiếp, không cần lên Google Play |
| Máy chủ API + PostgreSQL + Whisper | Vài trăm nghìn/tháng | Whisper model lớn cần VPS khoảng 4 vCPU, 8 GB RAM (chạy CPU; chỉ xử lý câu vàng/đỏ nên tải nhẹ), hoặc tận dụng máy tính/máy chủ sẵn có. Nếu chỉ dùng Whisper trên điện thoại thì VPS nhỏ là đủ |
| Phần cứng | ~0,5–1,5 triệu | 2–3 loại nút BT, tai nghe/mic cài áo, giá đỡ + túi chống nước; tận dụng điện thoại cũ |

## Rủi ro và cách giảm

| Rủi ro | Cách giảm |
| --- | --- |
| Nhầm số tiền (rủi ro lớn nhất) | Đọc lại số tiền sau mỗi câu; so với bảng giá; đối chiếu két cuối ngày |
| Whisper nghe sai tên riêng, giọng địa phương | Đưa tên khách vào prompt; thử PhoWhisper (huấn luyện thêm cho tiếng Việt); dùng biệt danh dễ nghe; so khớp gần đúng; máy chủ nghe lại bằng model lớn |
| Bố mẹ nói không theo thứ tự | Đánh vàng thay vì đoán bừa; tập nói theo mẫu vài buổi đầu; bổ sung quy tắc từ câu lỗi |
| Không bắt được nút BT trên iPhone | Thử ngay ở Giai đoạn 0; dự phòng máy Android ở quầy |
| Whisper "ảo giác" khi gặp tiếng ồn hoặc im lặng (tự sinh câu như "Hãy subscribe cho kênh…") | Dùng VAD bỏ đoạn không có tiếng nói; lọc các câu ảo giác hay gặp; câu không có số tiền → đỏ, không bao giờ tự đánh xanh |
| Máy cũ chạy Whisper chậm, nóng, tốn pin | Đo ở Giai đoạn 0; dùng model nhỏ hơn hoặc lượng tử hóa mạnh hơn; máy ở quầy luôn cắm sạc; nếu vẫn quá chậm thì gửi mọi câu lên máy chủ xử lý |
| Bộ quy tắc ngày càng rối | Bộ test Jest bắt buộc chạy trước mỗi lần sửa; từ điển để trong DB thay vì viết cứng trong code |
| Khách nghe thấy app đọc to chuyện nợ | Đọc lại qua tai nghe, hoặc không đọc chữ "nợ" |
| Mất mạng ở chợ | App offline-first, đồng bộ khi có mạng |
| Mất dữ liệu, hỏng máy | Đồng bộ lên API; xuất Excel hằng tháng; túi chống nước, giá treo cao |
| Riêng tư của khách | Chỉ ghi khi bấm nút; tự xóa file ghi âm sau 30 ngày |

## Câu hỏi cần hỏi bố mẹ trước khi làm

- Hiện đang ghi sổ thế nào? (chụp 3–5 trang sổ làm mẫu)
- Một ngày khoảng bao nhiêu khách, giờ nào đông nhất, bao nhiêu khách hay nợ?
- Bán những món gì? Giá có đổi theo ngày không? Có cân rồi tính tiền, hay khách nói "lấy 100 nghìn" là cắt luôn?
- Mua lợn thế nào: theo kg hơi hay theo con, trả ngay hay nợ lái lợn? Có đang nợ người bán lợn không?
- Lãi đang tính theo ngày hay theo con? Chi phí khác: mổ, chở, thuế chợ, túi, đá…
- Ai cầm máy: bố, mẹ hay cả hai? Có ngại máy đọc to giữa chợ không?
- Đầu ngày có để sẵn tiền lẻ trong két không, bao nhiêu?

## Việc làm ngay tuần này

1. Hỏi bố mẹ các câu trên, chụp vài trang sổ.
2. Xin phép ghi âm 1 buổi chợ; nhờ bố mẹ nói thử khoảng 100 câu theo cách nói quy ước.
3. Chạy 100 câu mẫu qua whisper.cpp trên máy tính với các model small, medium, large-v3-turbo và PhoWhisper; đo tỉ lệ đúng tên khách, đúng số tiền và thời gian xử lý.
4. Tạo dự án Expo (development build), cài whisper.rn, làm màn hình chỉ có: bấm nút → ghi → hiện câu chữ. Đo tốc độ trên iPhone và một máy Android.
5. Mua 2 loại nút bluetooth + 1 tai nghe, thử bắt nút trong app thử.
6. Chốt model Whisper cho điện thoại và cho máy chủ, chốt thiết bị ở quầy, rồi bắt đầu viết bộ phân tích + bộ test.
