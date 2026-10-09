#!/usr/bin/env python3
"""Harbor & Grain inventory desk: search variants, capture a physical count."""

from __future__ import annotations

import json
import subprocess
import time
from datetime import date, datetime
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from uuid import UUID

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[1]
PGDATA = ROOT / ".pgdata"
SQL = ROOT / "sql"
PORT_DB = 54329
PORT_WEB = 8080
DSN = f"host=127.0.0.1 port={PORT_DB} dbname=furniture user=furniture"
ADMIN_DSN = f"host=127.0.0.1 port={PORT_DB} dbname=postgres user=furniture"

SEARCH_SQL = """
SELECT
  v.id::text AS id,
  v.sku,
  p.name AS product_name,
  v.name AS variant_name,
  p.description,
  c.name AS category,
  c.slug AS category_slug,
  b.name AS brand,
  f.name AS finish,
  v.list_price,
  p.width_cm,
  p.depth_cm,
  p.height_cm,
  COALESCE((
    SELECT string_agg(m.name, ', ' ORDER BY pm.is_primary DESC, m.name)
    FROM product_materials pm
    JOIN materials m ON m.id = pm.material_id
    WHERE pm.product_id = p.id
  ), '') AS materials
FROM product_variants v
JOIN products p ON p.id = v.product_id
JOIN categories c ON c.id = p.category_id
LEFT JOIN brands b ON b.id = p.brand_id
LEFT JOIN finishes f ON f.id = v.finish_id
WHERE v.is_active
  AND (
    %(q)s = ''
    OR v.sku ILIKE %(like)s
    OR p.name ILIKE %(like)s
    OR v.name ILIKE %(like)s
    OR c.name ILIKE %(like)s
    OR COALESCE(b.name, '') ILIKE %(like)s
    OR COALESCE(f.name, '') ILIKE %(like)s
    OR EXISTS (
      SELECT 1
      FROM product_materials pm
      JOIN materials m ON m.id = pm.material_id
      WHERE pm.product_id = p.id AND m.name ILIKE %(like)s
    )
  )
  AND (%(category)s = '' OR c.slug = %(category)s OR c.parent_id IN (
    SELECT id FROM categories WHERE slug = %(category)s
  ))
ORDER BY p.name, v.sku
"""

STOCK_SQL = """
SELECT
  i.variant_id::text AS variant_id,
  w.id::text AS warehouse_id,
  w.code,
  w.name,
  i.on_hand,
  i.reserved,
  (i.on_hand - i.reserved) AS available
FROM inventory_levels i
JOIN warehouses w ON w.id = i.warehouse_id
WHERE i.variant_id = ANY(%(ids)s::uuid[])
ORDER BY w.code
"""


def json_ready(value):
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, dict):
        return {k: json_ready(v) for k, v in value.items()}
    if isinstance(value, list):
        return [json_ready(v) for v in value]
    return value


def pg_ready() -> bool:
    try:
        with psycopg.connect(ADMIN_DSN, connect_timeout=2) as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        return False


def ensure_database() -> None:
    if not (PGDATA / "PG_VERSION").exists():
        PGDATA.mkdir(parents=True, exist_ok=True)
        subprocess.check_call(
            [
                "initdb",
                "-D",
                str(PGDATA),
                "-U",
                "furniture",
                "--auth=trust",
                "--encoding=UTF8",
                "--locale=C",
            ]
        )
    if not pg_ready():
        log = open(PGDATA / "server.log", "a")
        subprocess.Popen(
            [
                "postgres",
                "-D",
                str(PGDATA),
                "-p",
                str(PORT_DB),
                "-c",
                "listen_addresses=127.0.0.1",
                "-c",
                f"unix_socket_directories={PGDATA}",
            ],
            stdout=log,
            stderr=log,
        )
        for _ in range(40):
            if pg_ready():
                break
            time.sleep(0.25)
        else:
            raise SystemExit(f"Postgres did not start. See {PGDATA / 'server.log'}")

    subprocess.run(
        ["createdb", "-h", "127.0.0.1", "-p", str(PORT_DB), "-U", "furniture", "furniture"],
        check=False,
        capture_output=True,
    )
    with psycopg.connect(DSN, autocommit=True) as conn:
        exists = conn.execute(
            "SELECT to_regclass('public.product_variants') IS NOT NULL"
        ).fetchone()[0]
    if not exists:
        for script in ("schema.sql", "seed.sql"):
            subprocess.check_call(
                [
                    "psql",
                    "-h",
                    "127.0.0.1",
                    "-p",
                    str(PORT_DB),
                    "-U",
                    "furniture",
                    "-d",
                    "furniture",
                    "-v",
                    "ON_ERROR_STOP=1",
                    "-f",
                    str(SQL / script),
                ]
            )


def connect():
    return psycopg.connect(DSN, row_factory=dict_row)


def search(q: str, category: str) -> list[dict]:
    q = q.strip()
    category = category.strip()
    with connect() as conn:
        rows = conn.execute(
            SEARCH_SQL,
            {"q": q, "like": f"%{q}%", "category": category},
        ).fetchall()
        ids = [r["id"] for r in rows]
        stock = []
        if ids:
            stock = conn.execute(STOCK_SQL, {"ids": ids}).fetchall()
        cats = conn.execute(
            "SELECT slug, name FROM categories ORDER BY sort_order, name"
        ).fetchall()
        warehouses = conn.execute(
            "SELECT id::text AS id, code, name FROM warehouses WHERE is_active ORDER BY code"
        ).fetchall()
    by_variant: dict[str, list] = {}
    for level in stock:
        by_variant.setdefault(level["variant_id"], []).append(
            {k: v for k, v in level.items() if k != "variant_id"}
        )
    for row in rows:
        row["stock"] = by_variant.get(row["id"], [])
        row["available"] = sum(s["available"] for s in row["stock"])
        row["on_hand"] = sum(s["on_hand"] for s in row["stock"])
    return {
        "results": json_ready(rows),
        "categories": cats,
        "warehouses": warehouses,
    }


def movements(variant_id: str) -> list[dict]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT
              sm.occurred_at,
              sm.movement_type::text AS movement_type,
              sm.quantity,
              sm.reference,
              w.code AS warehouse,
              trim(e.first_name || ' ' || e.last_name) AS employee
            FROM stock_movements sm
            JOIN warehouses w ON w.id = sm.warehouse_id
            LEFT JOIN employees e ON e.id = sm.employee_id
            WHERE sm.variant_id = %s
            ORDER BY sm.occurred_at DESC
            LIMIT 12
            """,
            (variant_id,),
        ).fetchall()
    return json_ready(rows)


def capture(body: dict) -> dict:
    variant_id = body["variant_id"]
    warehouse_id = body["warehouse_id"]
    mode = body.get("mode", "count")
    quantity = int(body["quantity"])
    note = (body.get("note") or "").strip() or None
    if mode not in {"count", "receipt", "damage"}:
        raise ValueError("mode must be count, receipt, or damage")
    if quantity < 0 or (mode != "count" and quantity == 0):
        raise ValueError("quantity must be a positive count")

    with connect() as conn:
        employee_id = conn.execute(
            """
            SELECT id FROM employees
            WHERE is_active
            ORDER BY (role = 'manager') DESC, hired_on
            LIMIT 1
            """
        ).fetchone()["id"]
        row = conn.execute(
            """
            SELECT on_hand, reserved
            FROM inventory_levels
            WHERE warehouse_id = %s AND variant_id = %s
            FOR UPDATE
            """,
            (warehouse_id, variant_id),
        ).fetchone()
        if row is None:
            conn.execute(
                """
                INSERT INTO inventory_levels (warehouse_id, variant_id, on_hand, reserved)
                VALUES (%s, %s, 0, 0)
                """,
                (warehouse_id, variant_id),
            )
            on_hand, reserved = 0, 0
        else:
            on_hand, reserved = row["on_hand"], row["reserved"]

        if mode == "count":
            new_on_hand = quantity
            delta = new_on_hand - on_hand
            movement = "adjustment"
        elif mode == "receipt":
            delta = quantity
            new_on_hand = on_hand + delta
            movement = "receipt"
        else:
            delta = -quantity
            new_on_hand = on_hand + delta
            movement = "damage"

        if new_on_hand < reserved:
            raise ValueError(
                f"count {new_on_hand} is below {reserved} reserved. Release those first."
            )
        if new_on_hand < 0:
            raise ValueError("that would take stock below zero")

        if delta != 0:
            conn.execute(
                """
                UPDATE inventory_levels
                SET on_hand = %s, updated_at = now()
                WHERE warehouse_id = %s AND variant_id = %s
                """,
                (new_on_hand, warehouse_id, variant_id),
            )
            conn.execute(
                """
                INSERT INTO stock_movements
                  (warehouse_id, variant_id, movement_type, quantity, reference, employee_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (warehouse_id, variant_id, movement, delta, note, employee_id),
            )
        conn.commit()
        level = conn.execute(
            """
            SELECT on_hand, reserved, (on_hand - reserved) AS available
            FROM inventory_levels
            WHERE warehouse_id = %s AND variant_id = %s
            """,
            (warehouse_id, variant_id),
        ).fetchone()
    return {
        "ok": True,
        "unchanged": delta == 0,
        "delta": delta,
        "level": json_ready(level),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[inventory] {self.address_string()} {fmt % args}")

    def _send(self, status: int, payload, content_type: str) -> None:
        body = payload if isinstance(payload, bytes) else payload.encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status: int, data) -> None:
        self._send(status, json.dumps(data), "application/json")

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            page = (ROOT / "web" / "static" / "index.html").read_bytes()
            self._send(200, page, "text/html; charset=utf-8")
            return
        qs = parse_qs(parsed.query)
        try:
            if parsed.path == "/api/search":
                self._json(
                    200,
                    search(qs.get("q", [""])[0], qs.get("category", [""])[0]),
                )
                return
            if parsed.path == "/api/movements":
                self._json(200, {"movements": movements(qs["variant_id"][0])})
                return
        except Exception as exc:
            self._json(400, {"error": str(exc)})
            return
        self._json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/capture":
            self._json(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
            self._json(200, capture(body))
        except (ValueError, KeyError, psycopg.Error) as exc:
            self._json(400, {"error": str(exc)})


def main() -> None:
    ensure_database()
    server = ThreadingHTTPServer(("127.0.0.1", PORT_WEB), Handler)
    print(f"Inventory desk http://127.0.0.1:{PORT_WEB}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
