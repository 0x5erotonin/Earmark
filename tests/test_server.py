"""Backend contract tests (run: python tests/test_server.py)."""
import json, os, sys, tempfile
from pathlib import Path

tmp = tempfile.mkdtemp()
os.environ["DATA_DIR"] = tmp
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
from server import main

c = TestClient(main.app)
fails = []
def ok(name, cond):
    print(("PASS" if cond else "FAIL"), " ", name)
    if not cond: fails.append(name)

r = c.get("/healthz")
ok("healthz", r.status_code == 200 and r.json()["ok"] is True)

r = c.get("/")
ok("serves UI", r.status_code == 200 and "EARMARK" in r.text and "detectMode" in r.text)
ok("UI not cached stale", r.headers["cache-control"] == "no-cache")

r = c.get("/api/workspace")
ok("404 before first save", r.status_code == 404)

snap = json.dumps({"v": 1, "calls": [], "flags": [], "phrases": [{"id": 1, "text": "wire the funds"}],
                   "team": [], "audit": [], "meta": {"signedIn": True, "theme": "noir"}})
r = c.put("/api/workspace", content=snap, headers={"content-type": "application/json"})
ok("PUT stores snapshot", r.status_code == 200 and r.json()["saved"] is True)

r = c.get("/api/workspace")
ok("GET round-trips exactly", r.status_code == 200 and r.text == snap)
ok("no-store on reads", r.headers["cache-control"] == "no-store")

snap2 = snap.replace('"noir"', '"nordic"')
c.put("/api/workspace", content=snap2, headers={"content-type": "application/json"})
r = c.get("/api/workspace")
ok("PUT overwrites (upsert)", '"nordic"' in r.text)

r = c.put("/api/workspace", content=b"")
ok("rejects empty body", r.status_code == 400)
r = c.put("/api/workspace", content=b"not json at all")
ok("rejects non-JSON", r.status_code == 400)
r = c.put("/api/workspace", content=b"{" + b"x" * (9 * 1024 * 1024))
ok("rejects oversized (413)", r.status_code == 413)

r = c.post("/api/workspace", content=snap2, headers={"content-type": "application/json"})
ok("POST alias works (sendBeacon flush)", r.status_code == 200 and r.json()["saved"] is True)

# "restart": new client against same DATA_DIR → data survives
c2 = TestClient(main.app)
r = c2.get("/api/workspace")
ok("survives restart (SQLite on volume)", r.status_code == 200 and '"nordic"' in r.text)

r = c.delete("/api/workspace")
ok("DELETE erases", r.json()["deleted"] is True and c.get("/api/workspace").status_code == 404)
r = c.delete("/api/workspace")
ok("DELETE idempotent", r.status_code == 200 and r.json()["deleted"] is False)

print()
print("FAILURES: " + ", ".join(fails) if fails else "ALL SERVER CHECKS PASS")
sys.exit(1 if fails else 0)
