"""Test giao diện MỞ RỘNG (Flutter web) bằng Playwright + Chrome. Xem KE-HOACH-TEST.md.
Chạy sau ui_test.py (dùng lại dữ liệu nó để lại: khách Anh Tư/Chị Hoa, 3 món, 1 lô, giao dịch hôm nay).
Chạy: python ui_test_extra.py   (cần API :5299 và app web :50792 đang chạy)
Log: logs/ui-test-extra-<giờ>.log ; ảnh lỗi: logs/shots/ ; kết quả: logs/results-extra.json
Mỗi ca kiểm cả giao diện lẫn dữ liệu trên server (gọi API bằng token admin).
"""
import sys, io, json, time, os, re, urllib.request, urllib.error
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
LOG = open(f"{HERE}/logs/ui-test-extra-{STAMP}.log", "w", encoding="utf-8")
RESULTS, NET_ERRORS, JS_ERRORS, REQ_FAILED = [], [], [], []


def log(msg):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line)
    LOG.write(line + "\n")
    LOG.flush()


def api(method, path, token=None, body=None, raw=False):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        if raw:
            return {"_status": e.code}
        raise


_TOK = {}


def admin_token():
    if "t" not in _TOK:
        _TOK["t"] = api("POST", "/api/v1/Auth/login", body={"username": "admin", "password": ADMIN_PW})["result"]["accessToken"]
    return _TOK["t"]


def srv(ent):
    items, page = [], 1
    while True:
        r = api("GET", f"/api/v1/{ent}?pageSize=100&pageIndex={page}&includeDeleted=true", token=admin_token())["result"]
        items += r.get("items") or []
        if page >= (r.get("totalPages") or 1):
            return items
        page += 1


def poll(fn, timeout=45, every=2):
    """Chờ đến khi fn() trả giá trị truthy (đồng bộ app -> server là bất đồng bộ)."""
    t0 = time.time()
    last = None
    while time.time() - t0 < timeout:
        try:
            last = fn()
            if last:
                return last
        except Exception as e:  # noqa
            last = e
        time.sleep(every)
    raise AssertionError(f"quá {timeout}s server chưa có dữ liệu mong đợi (cuối: {str(last)[:200]})")


def money_vn(n):
    return f"{n:,}".replace(",", ".")


def run():
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome", headless=True)
        ctx = b.new_context(viewport={"width": 420, "height": 900})
        pg = ctx.new_page()
        pg.set_default_timeout(8000)

        pg.on("pageerror", lambda e: (JS_ERRORS.append(str(e)), log(f"  !! PAGEERROR {str(e)[:300]}")))
        pg.on("console", lambda m: (JS_ERRORS.append(m.text), log(f"  !! CONSOLE.error {m.text[:1500]}")) if m.type == "error" else None)

        def on_resp(r):
            if r.status >= 400 and "5299" in r.url:
                NET_ERRORS.append(f"{r.status} {r.request.method} {r.url}")
                log(f"  !! HTTP {r.status} {r.request.method} {r.url}")
        pg.on("response", on_resp)
        pg.on("requestfailed", lambda r: (REQ_FAILED.append(r.url), log(f"  !! REQFAILED {r.method} {r.url} {r.failure}")) if "5299" in r.url else None)

        def tree():
            return pg.locator("flt-semantics-host").aria_snapshot()

        def txt():
            return " ".join(tree().split())

        def wait(ms=1200):
            pg.wait_for_timeout(ms)

        def btn(n, **k):
            return pg.get_by_role("button", name=n, **k)

        def tb(n):
            return pg.get_by_role("textbox", name=n)

        def fval(name):
            """Đọc giá trị ô nhập. Cây accessibility của Flutter web chỉ đồng bộ giá trị vào DOM khi ô được focus,
            nên phải focus trước rồi mới đọc input_value()."""
            loc = pg.get_by_role("textbox", name=name)
            loc.focus()
            wait(400)
            try:
                return loc.input_value()
            except Exception:
                m = re.search(r'textbox "' + re.escape(name) + r'": "([^"]*)"', tree())
                return m.group(1) if m else None

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

        def open_more(item):
            tab("Khác")
            btn(item).first.click()
            wait(1500)

        def expect(*parts):
            t = txt()
            miss = [x for x in parts if x not in t]
            assert not miss, f"thiếu {miss} trong màn hình: {t[:700]}"

        def expect_not(*parts):
            t = txt()
            bad = [x for x in parts if x in t]
            assert not bad, f"không được có {bad} trong màn hình: {t[:700]}"

        def step(tid, desc, fn):
            t0 = time.time()
            try:
                fn()
                RESULTS.append((tid, desc, "PASS", ""))
                log(f"PASS {tid} {desc} ({time.time()-t0:.1f}s)")
            except Exception as e:
                shot = f"logs/shots/{STAMP}-extra-{tid}.png"
                try:
                    pg.screenshot(path=f"{HERE}/{shot}")
                except Exception:
                    pass
                try:
                    dump = tree()[:1800]
                except Exception:
                    dump = "?"
                RESULTS.append((tid, desc, "FAIL", str(e)[:600]))
                log(f"FAIL {tid} {desc}: {str(e).splitlines()[0][:400]}\n    ảnh: {shot}\n    cây UI:\n{dump}")
                try:
                    pg.keyboard.press("Escape")
                    wait(300)
                except Exception:
                    pass
                try:
                    ctx.set_offline(False)
                except Exception:
                    pass

        # ---------- tiện ích dùng chung ----------
        def boot():
            pg.goto(f"{APP}/#/login", timeout=120000)
            wait(7000)
            pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            wait(1000)

        def login(u, pw, expect_ok=True):
            tb("Tên đăng nhập").fill(u)
            tb("Mật khẩu").fill(pw)
            btn("Đăng nhập").click()
            wait(4000 if expect_ok else 2500)

        def logout():
            tab("Khác")
            btn("Tài khoản").first.click()
            wait(1200)
            btn("Đăng xuất").click()
            wait(2500)
            if btn("Đăng xuất").count():
                btn("Đăng xuất").last.click()
                wait(2500)

        def back():
            btn("Quay lại").click()
            wait(1000)

        def row_y(text_part):
            bb = btn(text_part).first.bounding_box()
            return bb["y"] + bb["height"] / 2

        def click_delete_near(text_part):
            """Bấm nút 'Xóa' cùng hàng với dòng chứa text_part (danh sách phẳng, so theo toạ độ y)."""
            y = row_y(text_part)
            best, bd = None, 1e9
            for i in range(btn("Xóa", exact=True).count()):
                bb = btn("Xóa", exact=True).nth(i).bounding_box()
                if not bb:
                    continue
                d = abs(bb["y"] + bb["height"] / 2 - y)
                if d < bd:
                    best, bd = i, d
            assert best is not None and bd < 40, f"không thấy nút Xóa cạnh '{text_part}' (lệch {bd})"
            btn("Xóa", exact=True).nth(best).click()
            wait(900)

        def dlg():
            return pg.get_by_role("alertdialog")

        def say(sentence, save=True, hold=False):
            """Gõ câu vào Quầy; trả về text thẻ. save=True: bấm Lưu vào sổ; hold=True: để nguyên thẻ mở."""
            tab("Quầy")
            if btn("Bỏ qua").count():
                btn("Bỏ qua").first.click()
                wait(500)
            tb("Hoặc gõ câu cần ghi").fill(sentence)
            btn("Ghi câu này").click()
            wait(1800)
            card = txt()
            log(f"  thẻ cho '{sentence}': {card[:700]}")
            if hold:
                return card
            if save:
                btn("Lưu vào sổ").click()
                wait(1500)
            elif btn("Bỏ qua").count():
                btn("Bỏ qua").first.click()
                wait(500)
            return card

        def find_txn(raw_part):
            return [t for t in srv("Transactions") if raw_part in (t.get("rawText") or "")]

        def sync_now():
            tab("Khác")
            btn("Tài khoản").first.click()
            wait(800)
            # nút làm mới đồng bộ (IconButton không có tên) — thử bấm nút ngay sau 'Đồng bộ'
            pg.evaluate("1")
            home()

        # =====================================================================
        # R. Phân quyền + đăng nhập (làm đầu tiên: máy đang ở trạng thái đăng xuất)
        # =====================================================================
        def r0():
            boot()
            expect("Đăng nhập")
        step("R0", "Mở app, thấy màn đăng nhập", r0)

        def r1():
            for i in range(5):
                login("me", f"sai-{i}", expect_ok=False)
                assert "#/login" in pg.url, f"lần sai thứ {i+1} mà vẫn vào"
            log(f"  sau 5 lần sai: {txt()[:300]}")
            expect("Đăng nhập")
        step("R1", "Đăng nhập sai 5 lần liên tiếp -> luôn ở màn login", r1)

        def r2():
            tb("Mật khẩu").fill(ME_PW)
            btn("Đăng nhập").click()
            wait(4000)
            assert "#/counter" in pg.url, f"sau 5 lần sai, đúng mật khẩu mà không vào được (khóa tài khoản?) url={pg.url} | {txt()[:300]}"
        step("R2", "Sau 5 lần sai, đăng nhập đúng me/<mật khẩu seed> -> vào Quầy (không khóa nhầm)", r2)

        def r3():
            tab("Khác")
            t = txt()
            log("  Khác (me): " + t[:600])
            for need in ["Khách hàng", "Món hàng", "Lô hàng", "Tiền đi chợ", "Tài khoản"]:
                assert need in t, f"Seller thiếu mục {need}"
            for bad in ["người dùng", "Người dùng", "Quản lý user", "Vai trò", "Phân quyền", "Users"]:
                assert bad not in t, f"Seller thấy mục quản lý '{bad}'"
            btn("Tài khoản").first.click()
            wait(1200)
            expect("Seller", "me")
            home()
        step("R3", "Seller: có mục nghiệp vụ, KHÔNG có mục quản lý user; tài khoản hiện vai Seller", r3)

        def r4():
            r = api("POST", "/api/v1/Auth/login", body={"username": "me", "password": ME_PW})["result"]
            tok = r["accessToken"]
            for path in ["/api/v1/Users", "/api/v1/Role/List"]:
                try:
                    res = api("GET", path, token=tok, raw=True)
                    code = res.get("_status", 200)
                except Exception as e:
                    code = str(e)
                log(f"  Seller gọi {path} -> {code}")
                assert code in (401, 403), f"Seller gọi {path} được (mã {code}), phải bị chặn"
            mine = api("GET", "/api/v1/Permission/Mine", token=tok)["result"]
            log(f"  Permission/Mine của me: {mine.get('roleKey')} {mine.get('permissions')}")
            assert not any("Users" in x for x in (mine.get("permissions") or [])), "Seller có quyền Users"
        step("R4", "Server: Seller bị chặn 401/403 ở API quản lý user/role, không có quyền Users", r4)

        def r5():
            logout()
            assert "#/login" in pg.url, pg.url
            login("bo", BO_PW)
            assert "#/counter" in pg.url, pg.url
        step("R5", "Đăng xuất me -> đăng nhập lại bo", r5)

        # =====================================================================
        # S. Sửa khách / món / lô
        # =====================================================================
        def s1():
            open_more("Khách hàng")
            btn("Anh Tư").first.click()
            wait(1500)
            expect("Sửa khách hàng")
            tb("Tên khách").fill("Anh Tư Sửa")
            tb("Số điện thoại (không bắt buộc)").fill("0987654321")
            btn("Lưu").click()
            wait(2500)
            expect("Anh Tư Sửa")
            # mở lại, giá trị phải còn
            btn("Anh Tư Sửa").first.click()
            wait(1500)
            expect("Sửa khách hàng")
            phone = fval("Số điện thoại (không bắt buộc)")
            log(f"  SĐT trong form sửa: {phone!r}; tên: {fval('Tên khách')!r}")
            assert phone == "0987654321", f"mở lại form sửa, SĐT = {phone!r}"
            pg.screenshot(path=f"{HERE}/logs/shots/{STAMP}-extra-S1-form.png")
            back()
            c = poll(lambda: [x for x in srv("Customers") if x["name"] == "Anh Tư Sửa" and x["phone"] == "0987654321"])
            assert c, "server chưa nhận sửa khách"
            assert not [x for x in srv("Customers") if x["name"] == "Anh Tư" and not x["isDeleted"]], "server còn khách tên cũ"
        step("S1", "Sửa khách: đổi tên + SĐT, lưu, mở lại thấy giá trị mới, server cập nhật", s1)

        def s2():
            back()  # về Khác
            btn("Món hàng").first.click()
            wait(1500)
            btn("Nạc vai").first.click()
            wait(1200)
            expect("Sửa món")
            tb("Giá một kg").fill("140000")
            btn("Lưu").click()
            wait(1800)
            expect("140.000")
            p = poll(lambda: [x for x in srv("Products") if x["name"] == "Nạc vai" and x["pricePerKg"] == 140000])
            assert p
        step("S2", "Sửa món: Nạc vai 130k -> 140k, UI + server", s2)

        def s3():
            back()
            btn("Lô hàng").first.click()
            wait(1500)
            btn("8.000.000").first.click()
            wait(1200)
            expect("Sửa lô hàng")
            tb("Chi phí mổ, chở, đá...").fill("350000")
            btn("Lưu").click()
            wait(1800)
            expect("8.000.000")
            b_ = poll(lambda: [x for x in srv("Batches") if x["otherCost"] == 350000 and not x["isDeleted"]])
            assert b_
            btn("8.000.000").first.click()
            wait(1200)
            expect("350.000")
            btn("Hủy").click()
            wait(800)
        step("S3", "Sửa lô: chi phí 300k -> 350k, mở lại thấy 350.000, server cập nhật", s3)

        # =====================================================================
        # X. Xóa khách / món / lô có hộp thoại xác nhận
        # =====================================================================
        def x1():
            home()
            btn("Khách hàng").first.click() if btn("Khách hàng").count() else open_more("Khách hàng")
            wait(1200)
            btn("Thêm khách").click()
            wait(1000)
            tb("Tên khách").fill("Khách Xóa Thử")
            btn("Lưu").click()
            wait(2200)
            expect("Khách Xóa Thử")
            click_delete_near("Khách Xóa Thử")
            assert dlg().count() == 1, "không thấy hộp thoại xác nhận"
            expect("Xóa Khách Xóa Thử?")
            dlg().get_by_role("button", name="Hủy").click()
            wait(800)
            expect("Khách Xóa Thử")  # Hủy -> còn
            click_delete_near("Khách Xóa Thử")
            dlg().get_by_role("button", name="Xóa").click()
            wait(1500)
            expect_not("Khách Xóa Thử")
            poll(lambda: [x for x in srv("Customers") if x["name"] == "Khách Xóa Thử" and x["isDeleted"]])
        step("X1", "Xóa khách: Hủy -> còn; Xóa -> biến mất; server isDeleted=true", x1)

        def x2():
            back()
            btn("Món hàng").first.click()
            wait(1500)
            btn("Thêm món").click()
            wait(1500)
            tb("Tên món").fill("Món Xóa Thử")
            wait(400)
            assert fval("Tên món") == "Món Xóa Thử", "ô Tên món chưa nhận chữ sau fill"
            tb("Giá một kg").fill("99000")
            btn("Lưu").click()
            wait(1800)
            expect("Món Xóa Thử")
            click_delete_near("Món Xóa Thử")
            expect("Xóa Món Xóa Thử?")
            dlg().get_by_role("button", name="Hủy").click()
            wait(800)
            expect("Món Xóa Thử")
            click_delete_near("Món Xóa Thử")
            dlg().get_by_role("button", name="Xóa").click()
            wait(1500)
            expect_not("Món Xóa Thử")
            poll(lambda: [x for x in srv("Products") if x["name"] == "Món Xóa Thử" and x["isDeleted"]])
        step("X2", "Xóa món có hộp thoại xác nhận, server isDeleted", x2)

        def x3():
            back()
            btn("Lô hàng").first.click()
            wait(1500)
            btn("Thêm lô").click()
            wait(1200)
            tb("Số con").fill("1")
            tb("Tiền mua lợn").fill("1234567")
            btn("Lưu").click()
            wait(2000)
            expect("1.234.567")
            click_delete_near("1.234.567")
            assert dlg().count() == 1
            dlg().get_by_role("button", name="Hủy").click()
            wait(800)
            expect("1.234.567")
            click_delete_near("1.234.567")
            dlg().get_by_role("button", name="Xóa").click()
            wait(1500)
            expect_not("1.234.567")
            expect("8.000.000")  # lô kia còn
            poll(lambda: [x for x in srv("Batches") if x["buyCost"] == 1234567 and x["isDeleted"]])
            live = [x for x in srv("Batches") if not x["isDeleted"]]
            assert len(live) == 1, f"server còn {len(live)} lô chưa xóa, mong đợi 1"
        step("X3", "Xóa lô có hộp thoại xác nhận (chỉ xóa đúng lô), server isDeleted", x3)

        # =====================================================================
        # Q. Quầy: hoàn tác, thẻ chỉnh tay, tự ghi
        # =====================================================================
        def q1():
            before = len(find_txn("Hoàn tác thử"))
            say("Hoàn tác thử, Chị Hoa, nạc vai, một cân, một trăm bốn")
            poll(lambda: len(find_txn("Hoàn tác thử")) == before + 1)
            tab("Quầy")
            expect("Vừa ghi", "Hoàn tác")
            btn("Hoàn tác").first.click()
            wait(1500)
            expect("Đã hoàn tác")
            t = poll(lambda: [x for x in find_txn("Hoàn tác thử") if x["isDeleted"]])
            assert t
            tab("Sổ")
            expect_not("Hoàn tác thử")
        step("Q1", "Quầy: ghi rồi bấm Hoàn tác -> mục 'Vừa ghi' mất, server isDeleted", q1)

        def q2():
            say("Chị Hoa nạc vai chỉnh tay", save=False, hold=True)
            tb("Tổng tiền").fill("300000")
            wait(500)
            btn("Ghi nợ hết").click()
            wait(500)
            expect("Đã trả", "= 0 đ")
            btn("Trả hết").click()
            wait(500)
            t = txt()
            assert t.count("= 300.000 đ") >= 2, f"Trả hết không đặt Đã trả = Tổng tiền: {t[:500]}"
            btn("Ghi nợ hết").click()
            wait(500)
            btn("Lưu vào sổ").click()
            wait(1800)
            rec = poll(lambda: [x for x in srv("Transactions") if x["amount"] == 300000 and x["paidAmount"] == 0 and x["type"] == "Sale" and not x["isDeleted"]])
            assert rec, "không thấy giao dịch 300k nợ hết"
        step("Q2", "Thẻ chỉnh tay: nhập tiền, Ghi nợ hết/Trả hết, lưu -> server amount=300k paid=0", q2)

        def q3():
            say("khoản lạ chỉnh loại", save=False, hold=True)
            btn("Chi khác").click() if btn("Chi khác").count() else pg.get_by_role("checkbox", name="Chi khác").click()
            wait(500)
            tb("Số tiền").fill("77000")
            tb("Ghi chú").fill("test đổi loại")
            btn("Lưu vào sổ").click()
            wait(1800)
            rec = poll(lambda: [x for x in srv("Transactions") if x["amount"] == 77000 and x["type"] == "Expense" and x["note"] == "test đổi loại"])
            assert rec
        step("Q3", "Thẻ chỉnh tay: đổi loại sang Chi khác + sửa tiền + ghi chú, lưu -> server Expense 77k", q3)

        def q4():
            # thẻ chỉnh tay: Tổng tiền trống -> báo lỗi, không lưu
            say("Chị Hoa nạc vai để trống tiền", save=False, hold=True)
            btn("Lưu vào sổ").click()
            wait(800)
            expect("Nhập số tiền")
            assert btn("Lưu vào sổ").count() == 1, "thẻ đóng dù chưa nhập tiền"
            btn("Bỏ qua").first.click()
            wait(500)
        step("Q4", "Thẻ chỉnh tay: để trống tiền -> báo 'Nhập số tiền', không lưu", q4)

        def q5():
            tab("Quầy")
            sw = pg.get_by_role("switch", name="Tự ghi câu chắc chắn")
            if sw.count() == 0:
                sw = pg.get_by_role("checkbox", name="Tự ghi câu chắc chắn")
            assert sw.count(), "không thấy công tắc 'Tự ghi câu chắc chắn': " + txt()[:500]
            sw.first.click()
            wait(500)
            SENT = "Chị Hoa, nạc vai, hai cân, hai trăm tám"
            cnt = lambda: len([x for x in srv("Transactions") if (x.get("rawText") or "") == SENT])
            n0 = cnt()
            tb("Hoặc gõ câu cần ghi").fill(SENT)
            btn("Ghi câu này").click()
            wait(2200)
            t = txt()
            log("  sau khi gõ câu xanh (bật tự ghi): " + t[:500])
            assert btn("Lưu vào sổ").count() == 0, "bật tự ghi mà vẫn hiện thẻ xác nhận"
            expect("Vừa ghi")
            poll(lambda: cnt() == n0 + 1)
            # câu mơ hồ (đỏ/vàng) vẫn phải hiện thẻ
            tb("Hoặc gõ câu cần ghi").fill("blah blah không hiểu gì")
            btn("Ghi câu này").click()
            wait(1800)
            assert btn("Lưu vào sổ").count() == 1, "câu không hiểu mà tự ghi hoặc không hiện thẻ"
            btn("Bỏ qua").first.click()
            wait(500)
            sw.first.click()  # tắt lại
            wait(300)
        step("Q5", "Công tắc 'Tự ghi câu chắc chắn': câu xanh tự lưu không hiện thẻ; câu đỏ vẫn hiện thẻ", q5)

        # =====================================================================
        # D. Thu nợ
        # =====================================================================
        def d1():
            debts0 = api("GET", "/api/v1/Reports/Debts", token=admin_token())["result"]
            hoa0 = [d for d in debts0 if d["customerName"] == "Chị Hoa"][0]["debt"]
            log(f"  nợ Chị Hoa trên server trước: {hoa0}")
            tab("Nợ")
            btn("Chị Hoa").first.click()
            wait(1500)
            btn("Thu nợ").first.click()
            wait(1000)
            assert dlg().count() == 1, "không có hộp thoại thu nợ"
            expect("Chị Hoa trả nợ", "Số tiền trả")
            tb("Số tiền trả").fill("50000")
            dlg().get_by_role("button", name="Thu nợ").click()
            wait(2000)
            expect("Đã thu nợ")
            expect("Trả nợ 50.000 đ")
            ok = poll(lambda: [d for d in api("GET", "/api/v1/Reports/Debts", token=admin_token())["result"] if d["customerName"] == "Chị Hoa" and d["debt"] == hoa0 - 50000])
            assert ok, "server không giảm nợ 50k"
        step("D1", "Chi tiết nợ: nút Thu nợ -> nhập 50k -> nợ giảm 50k (UI + server)", d1)

        # =====================================================================
        # L. Sổ: điều hướng ngày, sửa/xóa giao dịch
        # =====================================================================
        def l1():
            tab("Sổ")
            expect("Hôm nay")
            assert btn("Ngày sau").is_disabled(), "Ngày sau phải bị khóa khi đang ở hôm nay"
            btn("Ngày trước").click()
            wait(1500)
            t = txt()
            log("  Sổ ngày trước: " + t[:400])
            assert "Hôm nay" not in t, "vẫn hiện 'Hôm nay' sau khi lùi ngày"
            exp = (time.time() - 86400)
            d = time.strftime("%d/%m/%Y", time.localtime(exp))
            expect(d, "Chưa có giao dịch nào trong ngày")
            assert not btn("Ngày sau").is_disabled()
            btn("Ngày sau").click()
            wait(1500)
            expect("Hôm nay", "Chị Hoa")
        step("L1", "Sổ: Ngày trước (trống) -> Ngày sau (về Hôm nay, bị khóa)", l1)

        def l2():
            tab("Sổ")
            btn("300.000 đ nợ 300.000 đ").first.click()
            wait(1500)
            expect("Lưu sửa")
            tb("Tổng tiền").fill("320000")
            wait(500)
            btn("Lưu sửa").click()
            wait(2000)
            expect("320.000 đ")
            poll(lambda: [x for x in srv("Transactions") if x["amount"] == 320000 and x["type"] == "Sale" and not x["isDeleted"]])
            assert not [x for x in srv("Transactions") if x["amount"] == 300000 and x["type"] == "Sale" and not x["isDeleted"]], "còn bản 300k"
        step("L2", "Sửa giao dịch từ Sổ: 300k -> 320k, UI + server", l2)

        def l3():
            tab("Sổ")
            btn("Chi khác").first.click()
            wait(1500)
            btn("Xóa", exact=True).first.click()
            wait(1000)
            expect("Xóa giao dịch này?")
            dlg().get_by_role("button", name="Hủy").click()
            wait(800)
            assert [x for x in srv("Transactions") if x["amount"] == 77000 and not x["isDeleted"]], "Hủy mà vẫn xóa"
            btn("Chi khác").first.click()
            wait(1500)
            btn("Xóa", exact=True).first.click()
            wait(1000)
            dlg().get_by_role("button", name="Xóa").click()
            wait(1800)
            poll(lambda: [x for x in srv("Transactions") if x["amount"] == 77000 and x["isDeleted"]])
        step("L3", "Xóa giao dịch từ thẻ sửa ở Sổ (có xác nhận), server isDeleted", l3)

        # =====================================================================
        # C. Chốt sổ: lệch / khớp / thừa / thiếu, chốt lại
        # =====================================================================
        def c_expected():
            t = txt()
            m = re.search(r"Két theo sổ (-?[\d.]+) đ", t)
            assert m, "không đọc được 'Két theo sổ': " + t[:400]
            return int(m.group(1).replace(".", ""))

        def settle_case(label, delta, word):
            tab("Chốt sổ")
            tb("Tiền đầu ngày").fill("1000000")
            wait(800)
            exp = c_expected()
            counted = exp + delta
            if counted < 0:
                tb("Tiền đầu ngày").fill(str(1000000 + (-counted) + 100000))
                wait(800)
                exp = c_expected()
                counted = exp + delta
            tb("Két đếm thực tế").fill(str(counted))
            wait(1000)
            t = txt()
            log(f"  {label}: két sổ={exp} đếm={counted} -> {t[t.find('Chênh'):][:60]}")
            expect("Chênh lệch " + word)
            btn("Chốt lại" if btn("Chốt lại").count() else "Chốt sổ", exact=True).last.click()
            wait(2500)
            today = time.strftime("%Y-%m-%d")
            rec = poll(lambda: [s for s in srv("DaySettlements") if s["date"][:10] == today and not s["isDeleted"]
                                and s["countedCash"] == counted and s["expectedCash"] == exp])
            assert rec, "server chưa có chốt sổ đúng"
            log(f"  server DaySettlement: {rec[0]}")

        def c0():
            tab("Chốt sổ")
            assert btn("Ngày trước").count() == 1 and btn("Ngày sau").count() == 1, "tab Chốt sổ không tìm được nút theo tên 'Ngày trước'/'Ngày sau': " + txt()[:400]
            assert btn("Ngày sau").is_disabled(), "Ngày sau phải khóa khi ở hôm nay"
            btn("Ngày trước").click()
            wait(1200)
            assert "Hôm nay" not in txt(), "Ngày trước không lùi ngày: " + txt()[:300]
            btn("Ngày sau").click()
            wait(1200)
            expect("Hôm nay")
        step("C0", "Chốt sổ: nút 'Ngày trước'/'Ngày sau' có tên (BUG-002) và hoạt động", c0)

        step("C1", "Chốt sổ KHỚP (đếm = sổ) -> 'Khớp', lưu, server", lambda: settle_case("khớp", 0, "Khớp"))
        step("C2", "Chốt sổ THỪA (+12.000) -> 'Thừa', chốt lại cùng ngày, server", lambda: settle_case("thừa", 12000, "Thừa"))
        step("C3", "Chốt sổ THIẾU (-34.000) -> 'Thiếu', chốt lại cùng ngày, server", lambda: settle_case("thiếu", -34000, "Thiếu"))

        def c4():
            today = time.strftime("%Y-%m-%d")
            live = [s for s in srv("DaySettlements") if s["date"][:10] == today and not s["isDeleted"]]
            allrows = [s for s in srv("DaySettlements") if s["date"][:10] == today]
            log(f"  số bản chốt sổ hôm nay trên server: sống={len(live)} tổng={len(allrows)}")
            assert len(live) == 1, f"chốt lại cùng ngày tạo {len(live)} bản ghi (phải 1)"
            tab("Chốt sổ")
            expect("Chốt lại", "Các lần chốt gần đây")
            t = txt()
            assert t.count(time.strftime("%d/%m/%Y")) >= 1
        step("C4", "Chốt lại cùng ngày: chỉ còn 1 bản ghi/ngày, nút đổi thành 'Chốt lại'", c4)

        # =====================================================================
        # P. Bộ phân tích câu khó
        # =====================================================================
        def parse(sentence, keep=False):
            return say(sentence, save=False, hold=keep)

        def p1():
            t = parse("Chị Hoa, nạc vai, hai cân rưỡi, ba trăm hai lăm", keep=True)
            w = fval("Số cân")
            log(f"  Số cân trong thẻ: {w!r}")
            assert w in ("2,5", "2.5"), f"'hai cân rưỡi' phải = 2,5 kg, thẻ ghi {w!r}"
        step("P1", "Parser: 'hai cân rưỡi' = 2,5 kg", p1)

        def p2():
            t = parse("Mang đi một củ")
            assert "1.000.000" in t, "'một củ' phải = 1.000.000: " + t[:500]
        step("P2", "Parser: 'một củ' = 1.000.000", p2)

        def p3():
            t = parse("Chị Hoa, nạc vai, ba cân hai, bốn trăm", keep=True)
            w = fval("Số cân")
            log(f"  Số cân trong thẻ: {w!r}")
            assert w in ("3,2", "3.2"), f"'ba cân hai' phải = 3,2 kg, thẻ ghi {w!r}"
        step("P3", "Parser: 'ba cân hai' = 3,2 kg", p3)

        def p4():
            t = parse("Cô Lan hai cân nạc vai hai trăm")
            assert "Thêm" in t and "Lan" in t and "danh bạ" in t, "khách không tồn tại phải gợi ý thêm vào danh bạ: " + t[:600]
        step("P4", "Parser: khách không tồn tại -> gợi ý 'Thêm Lan vào danh bạ'", p4)

        def p5():
            t = parse("Chị Hoà nạc vai một cân một trăm bốn")
            assert "Chị Hoa" in t, "tên mờ (Hoà/Hoa) không khớp được khách Chị Hoa: " + t[:600]
        step("P5", "Parser: tên khách mờ 'Hoà' khớp Chị Hoa", p5)

        def p6():
            t = parse("Anh Tư Sửa ba chỉ một cân rưỡi hai trăm tám lăm nghìn")
            assert "285.000" in t, "'hai trăm tám lăm nghìn' phải = 285.000: " + t[:600]
        step("P6", "Parser: 'hai trăm tám lăm nghìn' = 285.000", p6)

        def p7():
            t = parse("")  # câu rỗng: nút gửi không được tạo thẻ
            assert btn("Lưu vào sổ").count() == 0, "câu rỗng mà hiện thẻ"
            t = parse("   ")
            assert btn("Lưu vào sổ").count() == 0, "câu toàn dấu cách mà hiện thẻ"
        step("P7", "Quầy: câu rỗng/toàn dấu cách -> không tạo thẻ", p7)

        # =====================================================================
        # O. Offline -> tự đồng bộ
        # =====================================================================
        def o1():
            tab("Quầy")
            n0 = len([x for x in srv("Transactions") if "Offline thử" in (x.get("rawText") or "")])
            ctx.set_offline(True)
            wait(1500)
            say("Offline thử chi mua đá tám chục")
            wait(2000)
            tab("Sổ")
            expect("80.000 đ")  # vẫn thấy trong app dù offline
            n1 = len([x for x in srv("Transactions") if "Offline thử" in (x.get("rawText") or "")])
            assert n1 == n0, "đang offline mà server đã có giao dịch (bất thường)"
            log("  offline: giao dịch đã ghi cục bộ, server chưa có. Bật lại mạng...")
            ctx.set_offline(False)
            t0 = time.time()
            ok = None
            try:
                ok = poll(lambda: len([x for x in srv("Transactions") if "Offline thử" in (x.get("rawText") or "")]) == n0 + 1, timeout=75, every=3)
            except AssertionError:
                pass
            log(f"  tự đồng bộ sau bật mạng: {'có sau %.0fs' % (time.time()-t0) if ok else 'KHÔNG trong 75s'}")
            if not ok:
                # thử đồng bộ thủ công để xem dữ liệu có bị mất không
                tab("Khác")
                btn("Tài khoản").first.click()
                wait(800)
                log("  tài khoản: " + txt()[:300])
                pg.get_by_role("button").filter(has_not_text="Đăng xuất").nth(1).click()
                wait(6000)
                ok2 = len([x for x in srv("Transactions") if "Offline thử" in (x.get("rawText") or "")]) == n0 + 1
                log(f"  sau đồng bộ thủ công: {'có' if ok2 else 'vẫn không'}")
                raise AssertionError("không tự đồng bộ trong 75s sau khi có mạng lại" + (" (đồng bộ thủ công OK)" if ok2 else " (cả thủ công cũng không)"))
        step("O1", "Offline: ghi giao dịch (vẫn lưu cục bộ), bật mạng -> tự đồng bộ lên server", o1)

        def o2():
            ctx.set_offline(True)
            wait(1000)
            tab("Sổ")
            expect("Sổ hôm nay")
            tab("Nợ")
            expect("Sổ nợ")
            ctx.set_offline(False)
            wait(1000)
        step("O2", "Offline: duyệt Sổ/Nợ từ dữ liệu cục bộ không lỗi", o2)

        # =====================================================================
        # Z. Độ bền khi tải lại trang
        # =====================================================================
        def reboot():
            pg.reload(timeout=90000)
            wait(7000)
            pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
            wait(1500)

        def z1():
            tab("Quầy")
            tb("Hoặc gõ câu cần ghi").fill("Chị Hoa nạc vai")
            btn("Ghi câu này").click()
            wait(1800)
            assert btn("Lưu vào sổ").count() == 1
            n0 = len([x for x in srv("Transactions") if not x["isDeleted"]])
            reboot()  # tải lại khi thẻ đang mở
            assert "#/login" not in pg.url, "reload khi đang mở thẻ -> mất đăng nhập"
            n1 = len([x for x in srv("Transactions") if not x["isDeleted"]])
            assert n1 == n0, "reload khi thẻ mở mà server có thêm giao dịch"
            expect("Quầy")
        step("Z1", "Tải lại trang khi thẻ xác nhận đang mở: không mất đăng nhập, không ghi bừa", z1)

        def z2():
            # ghi offline rồi reload TRƯỚC khi đồng bộ: dữ liệu chưa gửi phải còn và sau đó lên server
            n0 = len([x for x in srv("Transactions") if "Reload thử" in (x.get("rawText") or "")])
            blocker = lambda route: route.abort()
            ctx.route("**://localhost:5299/**", blocker)  # giả lập mất mạng tới server (set_offline chặn luôn việc tải lại app)
            wait(1000)
            say("Reload thử chi mua đá chín chục")
            wait(1500)
            n_mid = len([x for x in srv("Transactions") if "Reload thử" in (x.get("rawText") or "")])
            assert n_mid == n0, "API bị chặn mà server đã có giao dịch"
            reboot()
            ctx.unroute("**://localhost:5299/**", blocker)
            wait(1500)
            tab("Sổ")
            expect("90.000 đ")
            ok = None
            try:
                ok = poll(lambda: len([x for x in srv("Transactions") if "Reload thử" in (x.get("rawText") or "")]) == n0 + 1, timeout=200, every=5)
            except AssertionError:
                pass
            assert ok, "giao dịch ghi lúc API không với tới được, trước khi reload, không lên server (mất dữ liệu hoặc không tự đồng bộ)"
        step("Z2", "Ghi offline -> tải lại trang (chưa đồng bộ) -> dữ liệu còn, bật mạng lại lên server", z2)

        def z3():
            reboot()
            tab("Sổ")
            n = len([x for x in srv("Transactions") if not x["isDeleted"] and x["occurredAt"][:10] == time.strftime("%Y-%m-%d")])
            t = txt()
            ui_rows = len(re.findall(r"button \"[^\"]* \d\d:\d\d", t))
            log(f"  server giao dịch sống hôm nay (UTC): {n}; dòng giao dịch trên UI: {ui_rows}")
            assert ui_rows >= 1
            for _ in range(2):
                reboot()
            expect("Sổ hôm nay")
        step("Z3", "Tải lại nhiều lần liên tiếp: Sổ vẫn hiển thị đủ", z3)

        # kiểm tra số liệu cuối: báo cáo server khớp UI
        def y1():
            rep = api("GET", "/api/v1/Reports/Daily?date=" + time.strftime("%Y-%m-%d") + "&openingCash=0", token=admin_token())["result"]
            log(f"  server Reports/Daily: {rep}")
            tab("Sổ")
            expect("Doanh thu " + money_vn(rep["revenue"]) + " đ", "Thu nợ cũ " + money_vn(rep["debtCollected"]) + " đ")
        step("Y1", "Số liệu Sổ hôm nay trên UI khớp báo cáo server (Reports/Daily)", y1)

        b.close()

    npass = sum(1 for r in RESULTS if r[2] == "PASS")
    nfail = len(RESULTS) - npass
    log(f"\n===== TỔNG KẾT (extra): {npass} PASS / {nfail} FAIL ; HTTP lỗi: {len(NET_ERRORS)} ; JS lỗi: {len(JS_ERRORS)} ; request fail: {len(REQ_FAILED)}")
    for r in RESULTS:
        if r[2] == "FAIL":
            log(f"  FAIL {r[0]} {r[1]} -> {r[3][:300]}")
    json.dump({"results": RESULTS, "net_errors": NET_ERRORS, "js_errors": JS_ERRORS, "req_failed": REQ_FAILED},
              open(f"{HERE}/logs/results-extra.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    run()
