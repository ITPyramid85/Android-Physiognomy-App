"""LuckyStar admin panel API for the local luckystar database.

Loopback only. Reads and deletes the operational records the app stores:
users, readings, stored images, and consultations. There is no payments table.
"""

from __future__ import annotations

import json
import os
import re
from datetime import date, datetime
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from uuid import UUID

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parent
STATIC = ROOT / "static"
UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)


class ApiError(Exception):
    def __init__(self, code: str, status: int = 400):
        super().__init__(code)
        self.code = code
        self.status = status


def load_env(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def json_ready(value):
    if isinstance(value, dict):
        return {str(key): json_ready(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_ready(item) for item in value]
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else str(value)
    if isinstance(value, (bytes, memoryview)):
        return bytes(value).hex()
    return value


def connect():
    conn = psycopg.connect(
        host=os.environ["PGHOST"],
        port=os.environ["PGPORT"],
        user=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
        dbname=os.environ["PGDATABASE"],
        connect_timeout=5,
        row_factory=dict_row,
        autocommit=True,
    )
    conn.execute("SET statement_timeout = '20s'")
    return conn


def query(sql, params=None):
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or ())
            if cur.description is None:
                return []
            return [json_ready(dict(row)) for row in cur.fetchall()]


def one(sql, params=None):
    rows = query(sql, params)
    return rows[0] if rows else None


def arg(qs, name, default=""):
    return (qs.get(name) or [default])[0].strip()


def paging(qs):
    try:
        limit = int(arg(qs, "limit", "30"))
        offset = int(arg(qs, "offset", "0"))
    except ValueError as exc:
        raise ApiError("invalid_paging") from exc
    return min(max(limit, 1), 100), max(offset, 0)


def like(term: str) -> str:
    escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


def parse_uuid(value: str) -> str:
    if not UUID_RE.match(value or ""):
        raise ApiError("invalid_id")
    return value


def summary():
    row = one(
        """
        SELECT
          (SELECT count(*) FROM auth.users) AS users,
          (SELECT count(*) FROM public.profiles) AS profiles,
          (SELECT count(*) FROM public.readings) AS readings,
          (SELECT count(*) FROM public.readings WHERE type = 'face') AS face_readings,
          (SELECT count(*) FROM public.readings WHERE type = 'palm') AS palm_readings,
          (SELECT count(*) FROM public.readings WHERE image_path IS NOT NULL) AS readings_with_image,
          (SELECT count(*) FROM storage.objects) AS stored_files,
          (SELECT count(*) FROM public.consultations) AS consultations,
          (SELECT count(*) FROM public.consultation_messages) AS messages
        """
    )
    return {"summary": row, "activity": activity("", 8, 0)["items"]}


def users(term, limit, offset):
    pattern = like(term)
    where = """
      WHERE %s = ''
         OR coalesce(u.email, '') ILIKE %s ESCAPE '\\'
         OR coalesce(p.display_name, '') ILIKE %s ESCAPE '\\'
    """
    params = (term, pattern, pattern)
    total = one(
        f"""
        SELECT count(*) AS n
        FROM auth.users u
        LEFT JOIN public.profiles p ON p.id = u.id
        {where}
        """,
        params,
    )["n"]
    items = query(
        f"""
        SELECT u.id, u.email, u.created_at, u.raw_user_meta_data,
               p.display_name, p.locale, p.created_at AS profile_created_at,
               (SELECT count(*) FROM public.readings r WHERE r.user_id = u.id) AS reading_count,
               (SELECT count(*) FROM public.readings r WHERE r.user_id = u.id AND r.type = 'face') AS face_count,
               (SELECT count(*) FROM public.readings r WHERE r.user_id = u.id AND r.type = 'palm') AS palm_count,
               (SELECT count(*) FROM public.consultations c WHERE c.user_id = u.id) AS consultation_count,
               (SELECT max(r.created_at) FROM public.readings r WHERE r.user_id = u.id) AS last_reading_at
        FROM auth.users u
        LEFT JOIN public.profiles p ON p.id = u.id
        {where}
        ORDER BY u.created_at DESC
        LIMIT %s OFFSET %s
        """,
        (*params, limit, offset),
    )
    return {"total": total, "items": items}


def user_detail(user_id):
    parse_uuid(user_id)
    row = one(
        """
        SELECT u.id, u.email, u.created_at, u.raw_user_meta_data,
               p.display_name, p.locale, p.created_at AS profile_created_at,
               (SELECT count(*) FROM public.readings r WHERE r.user_id = u.id) AS reading_count,
               (SELECT count(*) FROM public.readings r WHERE r.user_id = u.id AND r.type = 'face') AS face_count,
               (SELECT count(*) FROM public.readings r WHERE r.user_id = u.id AND r.type = 'palm') AS palm_count,
               (SELECT count(*) FROM public.consultations c WHERE c.user_id = u.id) AS consultation_count,
               (SELECT max(r.created_at) FROM public.readings r WHERE r.user_id = u.id) AS last_reading_at
        FROM auth.users u
        LEFT JOIN public.profiles p ON p.id = u.id
        WHERE u.id = %s
        """,
        (user_id,),
    )
    if row is None:
        raise ApiError("not_found", 404)
    readings = query(
        """
        SELECT id, type, subject_name, image_path, model_used, locale, created_at,
               substring(result_text from 1 for 180) AS excerpt
        FROM public.readings
        WHERE user_id = %s
        ORDER BY created_at DESC
        LIMIT 50
        """,
        (user_id,),
    )
    consultations = query(
        """
        SELECT id, analysis_type, analysis_id, title, locale, model_used,
               message_count, last_message_at, created_at
        FROM public.consultations
        WHERE user_id = %s
        ORDER BY coalesce(last_message_at, created_at) DESC
        LIMIT 50
        """,
        (user_id,),
    )
    return {"user": row, "readings": readings, "consultations": consultations}


ACTIVITY_SQL = """
    SELECT kind, id, user_id, created_at, subtype, title, excerpt, image_path,
           locale, model_used, email, display_name
    FROM (
      SELECT 'reading'::text AS kind, r.id, r.user_id, r.created_at,
             r.type AS subtype, coalesce(r.subject_name, '') AS title,
             substring(r.result_text from 1 for 180) AS excerpt, r.image_path,
             r.locale, r.model_used, u.email, p.display_name
      FROM public.readings r
      LEFT JOIN auth.users u ON u.id = r.user_id
      LEFT JOIN public.profiles p ON p.id = r.user_id
      UNION ALL
      SELECT 'consultation', c.id, c.user_id, coalesce(c.created_at, c.last_message_at),
             c.analysis_type, coalesce(c.title, ''),
             substring(c.context_summary from 1 for 180), NULL,
             c.locale, c.model_used, u.email, p.display_name
      FROM public.consultations c
      LEFT JOIN auth.users u ON u.id = c.user_id
      LEFT JOIN public.profiles p ON p.id = c.user_id
      UNION ALL
      SELECT 'message', m.id, c.user_id, coalesce(m.created_at, c.created_at),
             m.role, coalesce(c.title, ''),
             substring(m.content from 1 for 180), NULL,
             c.locale, NULL, u.email, p.display_name
      FROM public.consultation_messages m
      JOIN public.consultations c ON c.id = m.consultation_id
      LEFT JOIN auth.users u ON u.id = c.user_id
      LEFT JOIN public.profiles p ON p.id = c.user_id
    ) events
"""


def activity(kind, limit, offset):
    if kind not in ("", "reading", "consultation", "message"):
        raise ApiError("invalid_filter")
    total = one(
        f"SELECT count(*) AS n FROM ({ACTIVITY_SQL}) s WHERE %s = '' OR kind = %s",
        (kind, kind),
    )["n"]
    items = query(
        f"""
        {ACTIVITY_SQL}
        WHERE %s = '' OR kind = %s
        ORDER BY created_at DESC NULLS LAST
        LIMIT %s OFFSET %s
        """,
        (kind, kind, limit, offset),
    )
    return {"total": total, "items": items}


def readings(kind, term, limit, offset):
    if kind not in ("", "face", "palm"):
        raise ApiError("invalid_filter")
    pattern = like(term)
    where = """
      WHERE (%s = '' OR r.type = %s)
        AND (%s = ''
             OR coalesce(r.subject_name, '') ILIKE %s ESCAPE '\\'
             OR coalesce(r.result_text, '') ILIKE %s ESCAPE '\\'
             OR coalesce(u.email, '') ILIKE %s ESCAPE '\\'
             OR coalesce(p.display_name, '') ILIKE %s ESCAPE '\\')
    """
    params = (kind, kind, term, pattern, pattern, pattern, pattern)
    total = one(
        f"""
        SELECT count(*) AS n
        FROM public.readings r
        LEFT JOIN auth.users u ON u.id = r.user_id
        LEFT JOIN public.profiles p ON p.id = r.user_id
        {where}
        """,
        params,
    )["n"]
    items = query(
        f"""
        SELECT r.id, r.user_id, r.type, r.subject_name, r.image_path, r.model_used,
               r.locale, r.created_at, substring(r.result_text from 1 for 220) AS excerpt,
               u.email, p.display_name,
               (SELECT count(*) FROM public.consultations c WHERE c.analysis_id = r.id) AS consultation_count
        FROM public.readings r
        LEFT JOIN auth.users u ON u.id = r.user_id
        LEFT JOIN public.profiles p ON p.id = r.user_id
        {where}
        ORDER BY r.created_at DESC
        LIMIT %s OFFSET %s
        """,
        (*params, limit, offset),
    )
    return {"total": total, "items": items}


def reading_detail(reading_id):
    parse_uuid(reading_id)
    row = one(
        """
        SELECT r.id, r.user_id, r.type, r.subject_name, r.image_path, r.result_text,
               r.model_used, r.locale, r.created_at, u.email, p.display_name,
               o.id AS object_id, o.bucket_id, o.created_at AS stored_at, o.metadata
        FROM public.readings r
        LEFT JOIN auth.users u ON u.id = r.user_id
        LEFT JOIN public.profiles p ON p.id = r.user_id
        LEFT JOIN storage.objects o
          ON o.bucket_id = 'readings' AND o.name = r.image_path
        WHERE r.id = %s
        """,
        (reading_id,),
    )
    if row is None:
        raise ApiError("not_found", 404)
    linked = query(
        """
        SELECT id, title, analysis_type, message_count, last_message_at, created_at
        FROM public.consultations
        WHERE analysis_id = %s
        ORDER BY created_at DESC
        """,
        (reading_id,),
    )
    return {"reading": row, "consultations": linked}


def images(kind):
    if kind not in ("", "face", "palm", "stored", "missing"):
        raise ApiError("invalid_filter")
    bucket = one(
        """
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets
        WHERE id = 'readings'
        """
    )
    items = query(
        """
        SELECT r.id AS reading_id, r.type, r.subject_name, r.image_path, r.created_at,
               r.user_id, r.locale, u.email, p.display_name,
               o.id AS object_id, o.created_at AS stored_at, o.updated_at, o.metadata,
               (o.id IS NOT NULL) AS has_file
        FROM public.readings r
        LEFT JOIN auth.users u ON u.id = r.user_id
        LEFT JOIN public.profiles p ON p.id = r.user_id
        LEFT JOIN storage.objects o
          ON o.bucket_id = 'readings' AND o.name = r.image_path
        WHERE (%s = '' OR r.type = %s OR (%s = 'stored' AND o.id IS NOT NULL) OR (%s = 'missing' AND o.id IS NULL))
        ORDER BY r.created_at DESC
        LIMIT 200
        """,
        (kind, kind, kind, kind),
    )
    orphans = query(
        """
        SELECT o.id, o.bucket_id, o.name, o.owner, o.created_at, o.updated_at, o.metadata,
               u.email, p.display_name
        FROM storage.objects o
        LEFT JOIN auth.users u ON u.id = o.owner
        LEFT JOIN public.profiles p ON p.id = o.owner
        WHERE o.bucket_id = 'readings'
          AND NOT EXISTS (
            SELECT 1 FROM public.readings r WHERE r.image_path = o.name
          )
        ORDER BY o.created_at DESC
        LIMIT 200
        """
    )
    return {"bucket": bucket, "items": items, "orphans": orphans}


def consultations(kind, term, limit, offset):
    if kind not in ("", "face", "palm"):
        raise ApiError("invalid_filter")
    pattern = like(term)
    where = """
      WHERE (%s = '' OR c.analysis_type = %s)
        AND (%s = ''
             OR coalesce(c.title, '') ILIKE %s ESCAPE '\\'
             OR coalesce(c.context_summary, '') ILIKE %s ESCAPE '\\'
             OR coalesce(u.email, '') ILIKE %s ESCAPE '\\'
             OR coalesce(p.display_name, '') ILIKE %s ESCAPE '\\'
             OR coalesce(r.subject_name, '') ILIKE %s ESCAPE '\\')
    """
    params = (kind, kind, term, pattern, pattern, pattern, pattern, pattern)
    total = one(
        f"""
        SELECT count(*) AS n
        FROM public.consultations c
        LEFT JOIN auth.users u ON u.id = c.user_id
        LEFT JOIN public.profiles p ON p.id = c.user_id
        LEFT JOIN public.readings r ON r.id = c.analysis_id
        {where}
        """,
        params,
    )["n"]
    items = query(
        f"""
        SELECT c.id, c.user_id, c.analysis_type, c.analysis_id, c.title, c.locale,
               c.model_used, c.message_count, c.last_message_at, c.created_at,
               substring(c.context_summary from 1 for 180) AS excerpt,
               r.subject_name, u.email, p.display_name
        FROM public.consultations c
        LEFT JOIN auth.users u ON u.id = c.user_id
        LEFT JOIN public.profiles p ON p.id = c.user_id
        LEFT JOIN public.readings r ON r.id = c.analysis_id
        {where}
        ORDER BY coalesce(c.last_message_at, c.created_at) DESC
        LIMIT %s OFFSET %s
        """,
        (*params, limit, offset),
    )
    return {"total": total, "items": items}


def consultation_detail(consultation_id):
    parse_uuid(consultation_id)
    row = one(
        """
        SELECT c.id, c.user_id, c.analysis_type, c.analysis_id, c.title, c.locale,
               c.model_used, c.message_count, c.last_message_at, c.created_at,
               c.context_summary, c.context_features,
               r.subject_name, r.type AS reading_type, u.email, p.display_name
        FROM public.consultations c
        LEFT JOIN auth.users u ON u.id = c.user_id
        LEFT JOIN public.profiles p ON p.id = c.user_id
        LEFT JOIN public.readings r ON r.id = c.analysis_id
        WHERE c.id = %s
        """,
        (consultation_id,),
    )
    if row is None:
        raise ApiError("not_found", 404)
    messages = query(
        """
        SELECT id, role, content, token_count, created_at
        FROM public.consultation_messages
        WHERE consultation_id = %s
        ORDER BY created_at ASC
        """,
        (consultation_id,),
    )
    return {"consultation": row, "messages": messages}


def delete_record(kind, record_id):
    parse_uuid(record_id)
    statements = {
        "user": "DELETE FROM auth.users WHERE id = %s RETURNING id",
        "reading": "DELETE FROM public.readings WHERE id = %s RETURNING id",
        "consultation": "DELETE FROM public.consultations WHERE id = %s RETURNING id",
        "object": "DELETE FROM storage.objects WHERE id = %s RETURNING id",
    }
    if kind not in statements:
        raise ApiError("invalid_filter")
    row = one(statements[kind], (record_id,))
    if row is None:
        raise ApiError("not_found", 404)
    return {"deleted": kind, "id": row["id"]}


class AdminHandler(BaseHTTPRequestHandler):
    server_version = "LuckyStarAdmin/1.0"

    def do_GET(self):
        try:
            parsed = urlparse(self.path)
            path = parsed.path
            qs = parse_qs(parsed.query)
            if path in ("/", "/index.html"):
                self._file(STATIC / "index.html", "text/html; charset=utf-8")
                return
            if path == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
                return
            limit, offset = paging(qs)
            record_id = arg(qs, "id")
            if path == "/api/admin/summary":
                payload = summary()
            elif path == "/api/admin/users" and record_id:
                payload = user_detail(record_id)
            elif path == "/api/admin/users":
                payload = users(arg(qs, "q"), limit, offset)
            elif path == "/api/admin/activity":
                payload = activity(arg(qs, "kind"), limit, offset)
            elif path == "/api/admin/readings" and record_id:
                payload = reading_detail(record_id)
            elif path == "/api/admin/readings":
                payload = readings(arg(qs, "type"), arg(qs, "q"), limit, offset)
            elif path == "/api/admin/images":
                payload = images(arg(qs, "type"))
            elif path == "/api/admin/consultations" and record_id:
                payload = consultation_detail(record_id)
            elif path == "/api/admin/consultations":
                payload = consultations(arg(qs, "type"), arg(qs, "q"), limit, offset)
            else:
                raise ApiError("not_found", 404)
            self._json(200, payload)
        except ApiError as exc:
            self._json(exc.status, {"error": exc.code})
        except Exception as exc:  # noqa: BLE001
            self._json(500, {"error": "server_error", "detail": str(exc).split("\n")[0]})

    def do_POST(self):
        try:
            if urlparse(self.path).path != "/api/admin/delete":
                raise ApiError("not_found", 404)
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 20_000:
                raise ApiError("invalid_body")
            body = json.loads(self.rfile.read(length).decode("utf-8"))
            payload = delete_record(str(body.get("kind", "")), str(body.get("id", "")))
            self._json(200, payload)
        except ApiError as exc:
            self._json(exc.status, {"error": exc.code})
        except Exception as exc:  # noqa: BLE001
            self._json(500, {"error": "server_error", "detail": str(exc).split("\n")[0]})

    def _json(self, status: int, payload: dict) -> None:
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _file(self, path: Path, content_type: str) -> None:
        raw = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, fmt: str, *args) -> None:
        print(f"[admin] {self.address_string()} {fmt % args}", flush=True)


def main() -> None:
    load_env(ROOT / ".env")
    host = os.environ.get("STUDIO_HOST", "127.0.0.1")
    port = int(os.environ.get("STUDIO_PORT", "54323"))
    if host not in ("127.0.0.1", "localhost"):
        raise SystemExit("Admin panel must bind to loopback.")
    httpd = ThreadingHTTPServer((host, port), AdminHandler)
    print(f"LuckyStar Admin  http://{host}:{port}", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
