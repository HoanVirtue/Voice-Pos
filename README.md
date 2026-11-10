# BanHang_mother — App bán thịt lợn bằng giọng nói

Nói là ghi sổ: bố mẹ chỉ cần nói, app tự ghi bán hàng, công nợ, tiền đi chợ; cuối ngày tự chốt sổ.

- `backend/` — .NET 8, MySQL 8, JWT, CQRS (MediatR), theo base timesheets-phuongxa
- `app/` — Flutter (iPhone, Android, web, Windows, macOS), offline-first (drift), Blaze STT
- `docs/` — api.http và tài liệu

## Chạy local

```bash
cp .env.example .env            # sửa mật khẩu, khóa JWT, Blaze__Token
docker compose up -d db         # chỉ MySQL; hoặc dùng MySQL cài sẵn
dotnet run --project backend/BanHang.WebAPI     # http://localhost:5299 , /swagger , /health
```

Lần đầu, tạo migration (cần `dotnet tool install --global dotnet-ef`):

```bash
cd backend
dotnet ef migrations add InitialCreate --project BanHang.Infrastructure --startup-project BanHang.WebAPI --output-dir Persistence/Migrations
```

App:

```bash
cd app
flutter create --org vn.lachongtech --platforms ios,android,web,windows,macos .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter run --dart-define=ENV=local      # Android emulator: tự dùng 10.0.2.2
```

Quyền sau `flutter create`: Android `RECORD_AUDIO` + `INTERNET`; iOS `NSMicrophoneUsageDescription`; macOS entitlements mic + network.

## Deploy sau này

`docker compose up -d --build` (api + mysql). CI: GitHub Actions trong `.github/workflows/`.

## Trạng thái

- Backend: build + test xanh; đã chạy thật với MySQL 8 local (migration tự áp khi khởi động, seed tài khoản, CRUD khách, xóa mềm).
- App: `flutter analyze` sạch, `flutter test` xanh; đã `flutter create` đủ nền tảng và thêm quyền mic/mạng.
- Hợp đồng API Món hàng / Lô hàng / Giao dịch / Chốt sổ / Báo cáo: `docs/hop-dong-api-so-ban-hang.md`.
- Windows desktop: bật Developer Mode (Settings → For developers) để build plugin (cần symlink).
