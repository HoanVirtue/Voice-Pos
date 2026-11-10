"""Test giao diện thật (Flutter web) bằng Playwright + Chrome. Xem KE-HOACH-TEST.md.
Chạy: python ui_test.py   (cần API :5299 và app web :50792 đang chạy, DB đã reset bằng reset_db.sh)
Log: logs/ui-test-<giờ>.log ; ảnh lỗi: logs/shots/ ; kết quả: logs/results.json
"""
import sys, io, json, time, os, urllib.request
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
from playwright.sync_api import sync_playwright

def _load_env():
    """Đọc mật khẩu seed từ .env ở gốc repo (không commit mật khẩu vào script)."""
    env = {}
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".env")
    try:
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    except OSError:
        pass
    return env


_ENV = _load_env()
ADMIN_PW = os.environ.get("UI_TEST_ADMIN_PW") or _ENV.get("Seed__AdminPassword", "")
BO_PW = os.environ.get("UI_TEST_BO_PW") or _ENV.get("Seed__BoPassword", "")
ME_PW = os.environ.get("UI_TEST_ME_PW") or _ENV.get("Seed__MePassword", "")


APP = "http://localhost:50792"
API = "http://localhost:5299"
HERE = os.path.dirname(os.path.abspath(__file__))
STAMP = time.strftime("%Y%m%d-%H%M%S")
os.makedirs(f"{HERE}/logs/shots", exist_ok=True)
LOG = open(f"{HERE}/logs/ui-test-{STAMP}.log", "w", encoding="utf-8")
RESULTS, NET_ERRORS, JS_ERRORS = [], [], []


def log(msg):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line)
    LOG.write(line + "\n")
    LOG.flush()


def api(method, path, token=None, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None, headers=headers)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode() or "{}")


def run():
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome", headless=True)
        ctx = b.new_context(viewport={"width": 420, "height": 900})
        pg = ctx.new_page()
        pg.set_default_timeout(8000)

        def on_err(e):
            JS_ERRORS.append(str(e))
            log(f"  !! PAGEERROR {str(e)[:300]}")

        def on_console(m):
            if m.type == "error":
                JS_ERRORS.append(m.text)
                log(f"  !! CONSOLE.error {m.text[:1800]}")

        def on_resp(r):
            if r.status >= 400 and "5299" in r.url:
                NET_ERRORS.append(f"{r.status} {r.request.method} {r.url}")
                log(f"  !! HTTP {r.status} {r.request.method} {r.url}")

        pg.on("pageerror", on_err)
        pg.on("console", on_console)
        pg.on("response", on_resp)

        def tree():
            return pg.locator("flt-semantics-host").aria_snapshot()

        def txt():
            return " ".join(tree().split())

        def wait(ms=1200):
            pg.wait_for_timeout(ms)

        def home():
            for _ in range(4):
                if btn("Quay lại").count() == 0:
                    return
                btn("Quay lại").first.click()
                wait(800)

        def tab(n):
            home()
            pg.get_by_role("tab", name=n, exact=True).click()
            wait(1500)

        def btn(n, **k):
            return pg.get_by_role("button", name=n, **k)

        def tb(n):
            return pg.get_by_role("textbox", name=n)

        def expect(*parts):
            t = txt()
            miss = [x for x in parts if x not in t]
            assert not miss, f"thiếu {miss} trong màn hình: {t[:600]}"

        def step(tid, desc, fn):
            t0 = time.time()
            try:
                fn()
                RESULTS.append((tid, desc, "PASS", ""))
                log(f"PASS {tid} {desc} ({time.time()-t0:.1f}s)")
            except Exception as e:
                shot = f"logs/shots/{STAMP}-{tid}.png"
                try:
                    pg.screenshot(path=f"{HERE}/{shot}")
                except Exception:
                    pass
                try:
                    dump = tree()[:1500]
                except Exception:
                    dump = "?"
                RESULTS.append((tid, desc, "FAIL", str(e)[:500]))
                log(f"FAIL {tid} {desc}: {str(e).splitlines()[0][:300]}\n    ảnh: {shot}\n    cây UI:\n{dump}")
                try:
                    pg.keyboard.press("Escape")
                    wait(300)
                except Exception:
                    pass

        # ---------- A. Đăng nhập ----------
        def a0():
            pg.goto(f"{APP}/#/login", timeout=120000)
            wait(7000)
            pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            wait(1000)
            expect("Đăng nhập")
        step("A0", "Mở app, thấy màn đăng nhập", a0)

        def a1():
            btn("Đăng nhập").click()
            wait(800)
            expect("Đăng nhập")
            assert "#/login" in pg.url, "bỏ trống mà vẫn qua login"
        step("A1", "Bỏ trống -> báo lỗi, không đăng nhập", a1)

        def a2():
            tb("Tên đăng nhập").fill("bo")
            tb("Mật khẩu").fill("sai-mat-khau")
            btn("Đăng nhập").click()
            wait(2500)
            assert "#/login" in pg.url, "sai mật khẩu mà vẫn vào"
        step("A2", "Sai mật khẩu -> ở lại màn login", a2)

        def a3():
            tb("Mật khẩu").fill(BO_PW)
            btn("Đăng nhập").click()
            wait(4000)
            assert "#/counter" in pg.url, f"url={pg.url}"
            expect("Quầy", "Bắt đầu ghi")
        step("A3", "Đăng nhập bo -> màn Quầy", a3)

        # ---------- B. Điều hướng ----------
        def b1():
            for name, h in [("Sổ", "Sổ hôm nay"), ("Nợ", "Sổ nợ"), ("Chốt sổ", "Chốt sổ"), ("Khác", "Khác"), ("Quầy", "Quầy")]:
                tab(name)
                expect(h)
        step("B1", "5 tab điều hướng hiển thị đúng", b1)

        def open_more(item):
            tab("Khác")
            btn(item).first.click()
            wait(1500)

        def back():
            btn("Quay lại").click()
            wait(1000)

        # ---------- C. Khách hàng ----------
        def c1():
            open_more("Khách hàng")
            btn("Thêm khách").click()
            wait(1200)
            tb("Tên khách").fill("Anh Tư")
            tb("Biệt danh / chỗ ngồi (không bắt buộc)").fill("Tư xe")
            tb("Số điện thoại (không bắt buộc)").fill("0912345678")
            btn("Lưu").click()
            wait(2500)
            expect("Anh Tư")
        step("C1", "Thêm khách 'Anh Tư' (alias Tư xe)", c1)

        def c2():
            btn("Thêm khách").click()
            wait(1200)
            tb("Tên khách").fill("Chị Hoa")
            btn("Lưu").click()
            wait(2000)
            expect("Chị Hoa")
        step("C2", "Thêm khách 'Chị Hoa'", c2)

        def c3():
            btn("Thêm khách").click()
            wait(1200)
            tb("Tên khách").fill("Khách lỗi")
            tb("Số điện thoại (không bắt buộc)").fill("abc")
            btn("Lưu").click()
            wait(1200)
            assert "Thêm khách hàng" in txt(), "SĐT sai mà vẫn lưu"
            back()
        step("C3", "SĐT sai định dạng -> không lưu", c3)

        def c4():
            tb("Tìm kiếm").fill("Tư xe")
            wait(1500)
            t = txt()
            assert "Anh Tư" in t and "Chị Hoa" not in t, f"tìm theo biệt danh sai: {t[:300]}"
            tb("Tìm kiếm").fill("")
            wait(800)
        step("C4", "Tìm khách theo biệt danh", c4)
        step("C5", "Quay lại màn Khác", lambda: (back(), expect("Món hàng")))

        # ---------- D. Món hàng ----------
        def d1():
            btn("Món hàng").first.click()
            wait(1500)
            for name, alias, price in [("Ba chỉ", "ba rọi", "190000"), ("Nạc vai", "", "130000"), ("Sườn", "", "150000")]:
                btn("Thêm món").click()
                wait(800)
                tb("Tên món").fill(name)
                if alias:
                    tb("Tên gọi khác (vd: ba rọi)").fill(alias)
                tb("Giá một kg").fill(price)
                btn("Lưu").click()
                wait(1500)
                expect(name)
        step("D1", "Thêm 3 món (Ba chỉ/Nạc vai/Sườn)", d1)
        step("D2", "Giá hiển thị", lambda: expect("190.000"))
        step("D3", "Quay lại", lambda: (back(), expect("Lô hàng")))

        # ---------- E. Lô hàng ----------
        def e1():
            btn("Lô hàng").first.click()
            wait(1500)
            expect("Lô hàng")
            btn("Thêm lô").click()
            wait(1200)
            tb("Số con").fill("2")
            tb("Cân hơi").fill("140")
            tb("Cân móc hàm").fill("100")
            tb("Tiền mua lợn").fill("8000000")
            tb("Chi phí mổ, chở, đá...").fill("300000")
            btn("Lưu").click()
            wait(2000)
            expect("8.000.000")
        step("E1", "Thêm lô hàng (2 con, 8 triệu, chi phí 300k)", e1)

        # ---------- F. Quầy ----------
        def say(sentence, parts=(), save=True):
            tab("Quầy")
            if btn("Bỏ qua").count():
                btn("Bỏ qua").first.click()
                wait(500)
            tb("Hoặc gõ câu cần ghi").fill(sentence)
            btn("Ghi câu này").click()
            wait(1800)
            card = txt()
            log(f"  thẻ cho '{sentence}': {card[:420]}")
            if parts:
                expect(*parts)
            if save:
                btn("Lưu vào sổ").click()
                wait(1500)
                assert btn("Lưu vào sổ").count() == 0, "thẻ xác nhận vẫn còn sau khi lưu"
            else:
                if btn("Bỏ qua").count():
                    btn("Bỏ qua").first.click()
                    wait(500)

        cases = [
            ("F1", "Anh Tư, ba chỉ, hai cân, ba trăm tám", ("Bán hàng", "Anh Tư", "Ba chỉ", "380.000")),
            ("F2", "Chị Hoa, nạc vai, cân rưỡi, hai trăm, nợ", ("Chị Hoa", "Nạc vai", "200.000")),
            ("F3", "Chị Hoa trả nợ một trăm", ("Chị Hoa", "100.000")),
            ("F4", "Mua lợn chín triệu tám", ("9.800.000",)),
            ("F5", "chi mua đá năm chục", ("50.000",)),
            ("F6", "Mang đi mười lăm triệu", ("15.000.000",)),
            ("F7", "Lẻ năm chục", ("50.000",)),
        ]
        for tid, s, parts in cases:
            step(tid, f"Quầy lưu: '{s}'", lambda s=s, parts=parts: say(s, parts))
        step("F8", "Quầy: câu không hiểu -> không lưu bừa", lambda: say("blah blah không hiểu gì", save=False))

        def f9():
            tab("Quầy")
            tb("Hoặc gõ câu cần ghi").fill("Xóa câu vừa rồi")
            btn("Ghi câu này").click()
            wait(2000)
            log("  sau lệnh xóa: " + txt()[:400])
            expect("Xóa giao dịch vừa rồi?", "Khách lẻ")
            btn("Xóa", exact=True).click()
            wait(1500)
            assert "Xóa giao dịch vừa rồi?" not in txt(), "hộp thoại xóa còn đó"
        step("F9", "Quầy: lệnh 'Xóa câu vừa rồi'", f9)

        # ---------- G. Sổ hôm nay ----------
        def g1():
            tab("Sổ")
            expect("Sổ hôm nay", "Anh Tư", "Chị Hoa")
            t = txt()
            log("  Sổ: " + t[:900])
            expect("Thu nợ cũ 100.000 đ", "Mang đi chợ 15.000.000 đ", "Mua lợn + chi khác 9.850.000 đ")
        step("G1", "Sổ hôm nay: tổng khớp công thức", g1)

        def g2():
            expect("Doanh thu 580.000 đ")
            assert "Khách lẻ" not in txt(), "giao dịch Lẻ đã xóa mà vẫn hiện trong Sổ"
        step("G2", "Sau khi xóa 'Lẻ': doanh thu = 380k + 200k = 580k", g2)

        # ---------- H. Nợ ----------
        def h1():
            tab("Nợ")
            expect("Sổ nợ", "Chị Hoa", "100.000 đ")
            log("  Nợ: " + txt()[:400])
            btn("Chị Hoa").first.click()
            wait(1500)
            log("  Chi tiết nợ: " + txt()[:600])
            home()
        step("H1", "Sổ nợ: Chị Hoa còn nợ 100.000 (200k - 100k), xem chi tiết", h1)

        # ---------- I. Chốt sổ ----------
        def i1():
            tab("Chốt sổ")
            tb("Tiền đầu ngày").fill("30000000")
            tb("Két đếm thực tế").fill("5000000")
            wait(1200)
            log("  Chốt sổ: " + txt()[:700])
            expect("Chênh lệch")
            btn("Chốt sổ", exact=True).last.click()
            wait(2500)
            log("  sau khi chốt: " + txt()[:500])
        step("I1", "Chốt sổ: nhập đầu ngày/két thực -> chênh lệch -> lưu", i1)

        # ---------- J. Tiền đi chợ ----------
        def j1():
            open_more("Tiền đi chợ")
            tb("Số con cần mua").fill("2")
            tb("Giá dự kiến một con").fill("4000000")
            tb("Nợ mối cần trả").fill("500000")
            tb("Dự phòng").fill("10")
            wait(1200)
            log("  Tiền đi chợ: " + txt()[:500])
            expect("9.300.000")
        step("J1", "Tiền đi chợ: 2 con x 4tr + nợ mối 500k + 10% = 9.300.000", j1)

        # ---------- K. Tài khoản ----------
        def k1():
            home()
            tab("Khác")
            btn("Tài khoản").first.click()
            wait(1500)
            expect("Bố bo", "Seller", "Đăng xuất")
        step("K1", "Tài khoản: hiển thị người dùng, đồng bộ", k1)

        # ---------- L. Đồng bộ lên server ----------
        def l1():
            wait(6000)
            tok = api("POST", "/api/v1/Auth/login", body={"username": "admin", "password": ADMIN_PW})["result"]["accessToken"]
            counts = {}
            for ent in ["Customers", "Products", "Batches", "Transactions", "DaySettlements"]:
                r = api("GET", f"/api/v1/{ent}?pageSize=100&includeDeleted=true", token=tok)["result"]
                items = r.get("items") or []
                counts[ent] = items
                log(f"  server {ent}: {len(items)}")
            assert len(counts["Customers"]) == 2 and len(counts["Products"]) == 3, "khách/món chưa đủ trên server"
            assert len(counts["Batches"]) == 1, "chưa có lô hàng trên server"
            assert len(counts["Transactions"]) >= 6, f"giao dịch trên server: {len(counts['Transactions'])}"
            assert len(counts["DaySettlements"]) == 1, "chưa có chốt sổ trên server"
            rep = api("GET", "/api/v1/Reports/Daily?date=" + time.strftime("%Y-%m-%d") + "&openingCash=0", token=tok)["result"]
            log(f"  server Reports/Daily: {rep}")
            debts = api("GET", "/api/v1/Reports/Debts", token=tok)["result"]
            log(f"  server Reports/Debts: {debts}")
        step("L1", "Dữ liệu 5 loại đã đồng bộ lên server + báo cáo", l1)

        # ---------- M. Tải lại trang, đăng xuất ----------
        def m1():
            pg.reload()
            wait(7000)
            pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            wait(1000)
            log("  sau reload: " + pg.url + " | " + txt()[:200])
            assert "#/login" not in pg.url, "reload là mất đăng nhập dù đã chọn 'Ghi nhớ'"
            tab("Sổ")
            expect("Anh Tư", "Chị Hoa")
        step("M1", "Tải lại trang: vẫn đăng nhập, dữ liệu còn", m1)

        def m2():
            tab("Khác")
            btn("Tài khoản").first.click()
            wait(1200)
            btn("Đăng xuất").click()
            wait(2500)
            if btn("Đăng xuất").count():
                btn("Đăng xuất").last.click()
                wait(2500)
            assert "#/login" in pg.url, f"chưa về màn login: {pg.url}"
        step("M2", "Đăng xuất -> về màn đăng nhập", m2)
        b.close()

    npass = sum(1 for r in RESULTS if r[2] == "PASS")
    nfail = len(RESULTS) - npass
    log(f"\n===== TỔNG KẾT: {npass} PASS / {nfail} FAIL ; HTTP lỗi: {len(NET_ERRORS)} ; JS lỗi: {len(JS_ERRORS)}")
    for r in RESULTS:
        if r[2] == "FAIL":
            log(f"  FAIL {r[0]} {r[1]} -> {r[3][:200]}")
    json.dump({"results": RESULTS, "net_errors": NET_ERRORS, "js_errors": JS_ERRORS},
              open(f"{HERE}/logs/results.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    run()
