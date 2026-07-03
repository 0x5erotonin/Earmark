"""Earmark server — serves the UI and persists the workspace snapshot.

The front-end saves its entire workspace as one atomic JSON snapshot
(calls, flags, phrases, team, audit, settings). This server stores that
snapshot in SQLite on a persistent volume, giving the app the same
persistence contract it has inside a hosted artifact:

    GET    /api/workspace   → snapshot (404 until first save)
    PUT    /api/workspace   → store snapshot (raw JSON body)
    DELETE /api/workspace   → erase snapshot
    GET    /healthz         → liveness/readiness for Fly checks

Swapping this single-snapshot store for real relational endpoints
(/calls, /flags, /phrases …) is the planned next step — the snapshot's
top-level keys are that future API's resource names.
"""

from __future__ import annotations

import os
import sqlite3
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse, Response

DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
DB_PATH = DATA_DIR / "earmark.db"
STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
INDEX = STATIC_DIR / "earmark.html"
WORKSPACE_ID = os.environ.get("WORKSPACE_ID", "default")
MAX_SNAPSHOT_BYTES = int(os.environ.get("MAX_SNAPSHOT_BYTES", 8 * 1024 * 1024))

app = FastAPI(title="Earmark", docs_url=None, redoc_url=None)


def db() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute(
        """CREATE TABLE IF NOT EXISTS workspace (
             id         TEXT PRIMARY KEY,
             snapshot   TEXT NOT NULL,
             updated_at REAL NOT NULL,
             bytes      INTEGER NOT NULL
           )"""
    )
    return conn


@app.get("/healthz")
@app.get("/api/healthz")
def healthz() -> dict:
    return {"ok": True, "service": "earmark"}


@app.get("/")
def index() -> FileResponse:
    return FileResponse(
        INDEX,
        media_type="text/html",
        headers={"Cache-Control": "no-cache"},
    )


@app.get("/api/workspace")
def get_workspace() -> Response:
    conn = db()
    try:
        row = conn.execute(
            "SELECT snapshot FROM workspace WHERE id = ?", (WORKSPACE_ID,)
        ).fetchone()
    finally:
        conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail="no snapshot yet")
    return Response(
        content=row[0],
        media_type="application/json",
        headers={"Cache-Control": "no-store"},
    )


@app.put("/api/workspace")
@app.post("/api/workspace")  # beacon-friendly alias (sendBeacon can't PUT)
async def put_workspace(request: Request) -> JSONResponse:
    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail="empty snapshot")
    if len(body) > MAX_SNAPSHOT_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"snapshot exceeds {MAX_SNAPSHOT_BYTES} bytes",
        )
    text = body.decode("utf-8", errors="strict")
    # cheap sanity check: must be a JSON object (full parse deferred to client)
    if not text.lstrip().startswith("{"):
        raise HTTPException(status_code=400, detail="snapshot must be JSON")
    conn = db()
    try:
        conn.execute(
            """INSERT INTO workspace (id, snapshot, updated_at, bytes)
               VALUES (?, ?, ?, ?)
               ON CONFLICT(id) DO UPDATE SET
                 snapshot = excluded.snapshot,
                 updated_at = excluded.updated_at,
                 bytes = excluded.bytes""",
            (WORKSPACE_ID, text, time.time(), len(body)),
        )
        conn.commit()
    finally:
        conn.close()
    return JSONResponse({"saved": True, "bytes": len(body)})


@app.delete("/api/workspace")
def delete_workspace() -> JSONResponse:
    conn = db()
    try:
        cur = conn.execute(
            "DELETE FROM workspace WHERE id = ?", (WORKSPACE_ID,)
        )
        conn.commit()
        deleted = cur.rowcount > 0
    finally:
        conn.close()
    return JSONResponse({"deleted": deleted})
