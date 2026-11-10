#!/bin/bash
# Chạy 1 lượt test UI sạch: reset DB -> chạy API -> (app web phải đang chạy ở :50792) -> ui_test.py
# App web: cd app && flutter run -d web-server --web-port=50792 --web-hostname=localhost --dart-define=ENV=local
cd "$(dirname "$0")/../.."
taskkill //F //IM BanHang.WebAPI.exe >/dev/null 2>&1
sleep 2
bash docs/ui-test/reset_db.sh
(dotnet run --project backend/BanHang.WebAPI --launch-profile http > docs/ui-test/logs/api.log 2>&1 &)
for i in $(seq 1 40); do curl -s localhost:5299/health | grep -q ok && break; sleep 2; done
curl -s localhost:5299/health || { echo "API không lên"; exit 1; }
echo
cd docs/ui-test && PYTHONIOENCODING=utf-8 python ui_test.py
echo "===== EXTRA ====="
PYTHONIOENCODING=utf-8 python ui_test_extra.py
