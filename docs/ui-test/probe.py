import sys
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome", headless=True)
    pg = b.new_page(viewport={"width":420,"height":900})
    pg.on("console", lambda m: print("CONSOLE", m.type, m.text[:200]))
    pg.on("pageerror", lambda e: print("PAGEERR", str(e)[:300]))
    pg.goto("http://localhost:50792/#/counter", wait_until="load")
    pg.wait_for_timeout(8000)
    pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
    pg.wait_for_timeout(1500)
    print(pg.url)
    print(pg.locator("flt-semantics-host").aria_snapshot()[:3000] if pg.locator("flt-semantics-host").count() else "no semantics host")
    pg.screenshot(path="logs/probe.png")
    b.close()
