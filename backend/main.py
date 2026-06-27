from __future__ import annotations

import hashlib
import hmac
import json
import mimetypes
import os
import secrets
import sqlite3

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except Exception:  # psycopg2 is only needed online when DATABASE_URL is set.
    psycopg2 = None
    RealDictCursor = None

from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()
USE_POSTGRES = DATABASE_URL.startswith(("postgres://", "postgresql://"))
DB_PATH = Path(os.getenv("DATABASE_PATH", "mson_predictions.db"))
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
SESSION_DAYS = int(os.getenv("SESSION_DAYS", "14"))
PBKDF2_ROUNDS = 180_000
JORDAN_TZ = timezone(timedelta(hours=3))
STATIC_DIR = Path(os.getenv("STATIC_DIR", str(PROJECT_DIR / "frontend" / "build" / "web"))).resolve()

if USE_POSTGRES and psycopg2 is None:
    raise RuntimeError("DATABASE_URL is set but psycopg2 is not installed. Run: pip install -r requirements.txt")

DB_INTEGRITY_ERROR = (sqlite3.IntegrityError,) if psycopg2 is None else (sqlite3.IntegrityError, psycopg2.IntegrityError)


def next_jordan_one_am() -> datetime:
    """Return the next 1:00 AM in Jordan time, converted to UTC."""
    now_jordan = utc_now().astimezone(JORDAN_TZ)
    target_jordan = now_jordan.replace(hour=1, minute=0, second=0, microsecond=0)
    if target_jordan <= now_jordan:
        target_jordan += timedelta(days=1)
    return target_jordan.astimezone(timezone.utc)


def one_am_seed_matches() -> list[tuple[str, str, datetime, str]]:
    kickoff = next_jordan_one_am()
    return [
        ("Brazil", "Scotland", kickoff, "World Cup 2026"),
        ("Morocco", "Haiti", kickoff, "World Cup 2026"),
    ]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_now() -> str:
    return utc_now().isoformat()


def parse_dt(value: str) -> datetime:
    cleaned = str(value).strip().replace("Z", "+00:00")
    dt = datetime.fromisoformat(cleaned)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def normalize_name(name: str) -> str:
    return " ".join(str(name).strip().lower().split())


def hash_password(password: str, salt: str | None = None) -> tuple[str, str]:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), PBKDF2_ROUNDS)
    return digest.hex(), salt


def verify_password(password: str, stored_hash: str, salt: str) -> bool:
    digest, _ = hash_password(password, salt)
    return hmac.compare_digest(digest, stored_hash)


class Row(dict):
    """Small dict row so SQLite and PostgreSQL responses behave the same."""

    def keys(self):
        return super().keys()


def _convert_placeholders(sql: str) -> str:
    if not USE_POSTGRES:
        return sql
    return sql.replace("?", "%s")


class CursorAdapter:
    def __init__(self, cursor):
        self.cursor = cursor

    @property
    def rowcount(self) -> int:
        return self.cursor.rowcount

    @property
    def lastrowid(self):
        return getattr(self.cursor, "lastrowid", None)

    def fetchone(self):
        row = self.cursor.fetchone()
        if row is None:
            return None
        if isinstance(row, dict):
            return Row(row)
        return Row(dict(row))

    def fetchall(self):
        rows = self.cursor.fetchall()
        out = []
        for row in rows:
            out.append(Row(row) if isinstance(row, dict) else Row(dict(row)))
        return out


class DatabaseAdapter:
    def __enter__(self):
        if USE_POSTGRES:
            connect_kwargs = {"cursor_factory": RealDictCursor}
            if "sslmode=" not in DATABASE_URL.lower():
                connect_kwargs["sslmode"] = "require"
            self.conn = psycopg2.connect(DATABASE_URL, **connect_kwargs)
        else:
            self.conn = sqlite3.connect(DB_PATH)
            self.conn.row_factory = sqlite3.Row
            self.conn.execute("PRAGMA foreign_keys = ON")
        return self

    def __exit__(self, exc_type, exc, tb):
        try:
            if exc_type is not None:
                self.conn.rollback()
        finally:
            self.conn.close()
        return False

    def execute(self, sql: str, params=()):
        cur = self.conn.cursor()
        cur.execute(_convert_placeholders(sql), params)
        return CursorAdapter(cur)

    def executescript(self, script: str):
        if USE_POSTGRES:
            cur = self.conn.cursor()
            for statement in [part.strip() for part in script.split(";") if part.strip()]:
                cur.execute(statement)
            return CursorAdapter(cur)
        return CursorAdapter(self.conn.executescript(script))

    def commit(self):
        self.conn.commit()


def get_db() -> DatabaseAdapter:
    return DatabaseAdapter()


def row_to_dict(row) -> dict | None:
    if row is None:
        return None
    return dict(row)


def ensure_column(db: DatabaseAdapter, table: str, column: str, definition: str) -> None:
    if USE_POSTGRES:
        existing = db.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = ? AND column_name = ?
            """,
            (table, column),
        ).fetchone()
        if existing is None:
            db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
        return

    existing = {row["name"] for row in db.execute(f"PRAGMA table_info({table})").fetchall()}
    if column not in existing:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")

def vote_deadline_for_match(match: sqlite3.Row) -> datetime:
    value = match["vote_deadline_at"] if "vote_deadline_at" in match.keys() else None
    return parse_dt(value or match["kickoff_at"])


def user_public(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "full_name": row["full_name"],
        "normalized_name": row["normalized_name"],
        "role": row["role"],
        "manual_points": row["manual_points"] if "manual_points" in row.keys() else 0,
        "created_at": row["created_at"],
    }


def init_db() -> None:
    with get_db() as db:
        if USE_POSTGRES:
            db.executescript(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    full_name TEXT NOT NULL,
                    normalized_name TEXT NOT NULL UNIQUE,
                    password_hash TEXT NOT NULL,
                    salt TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'user',
                    manual_points INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS sessions (
                    token TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    created_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS matches (
                    id SERIAL PRIMARY KEY,
                    team_a TEXT NOT NULL,
                    team_b TEXT NOT NULL,
                    kickoff_at TEXT NOT NULL,
                    vote_deadline_at TEXT,
                    stage TEXT NOT NULL DEFAULT 'Group Stage',
                    status TEXT NOT NULL DEFAULT 'scheduled',
                    final_result TEXT CHECK(final_result IN ('A','DRAW','B')),
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS predictions (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    match_id INTEGER NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
                    prediction TEXT NOT NULL CHECK(prediction IN ('A','DRAW','B')),
                    locked INTEGER NOT NULL DEFAULT 1,
                    points INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    UNIQUE(user_id, match_id)
                );

                CREATE INDEX IF NOT EXISTS idx_predictions_match ON predictions(match_id);
                CREATE INDEX IF NOT EXISTS idx_matches_kickoff ON matches(kickoff_at);
                """
            )
            ensure_column(db, "users", "manual_points", "INTEGER NOT NULL DEFAULT 0")
            ensure_column(db, "matches", "vote_deadline_at", "TEXT")
        else:
            db.executescript(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    full_name TEXT NOT NULL,
                    normalized_name TEXT NOT NULL UNIQUE,
                    password_hash TEXT NOT NULL,
                    salt TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'user',
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS sessions (
                    token TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS matches (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    team_a TEXT NOT NULL,
                    team_b TEXT NOT NULL,
                    kickoff_at TEXT NOT NULL,
                    stage TEXT NOT NULL DEFAULT 'Group Stage',
                    status TEXT NOT NULL DEFAULT 'scheduled',
                    final_result TEXT CHECK(final_result IN ('A','DRAW','B')),
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS predictions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    match_id INTEGER NOT NULL,
                    prediction TEXT NOT NULL CHECK(prediction IN ('A','DRAW','B')),
                    locked INTEGER NOT NULL DEFAULT 1,
                    points INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                    FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE,
                    UNIQUE(user_id, match_id)
                );

                CREATE INDEX IF NOT EXISTS idx_predictions_match ON predictions(match_id);
                CREATE INDEX IF NOT EXISTS idx_matches_kickoff ON matches(kickoff_at);
                """
            )
            ensure_column(db, "users", "manual_points", "INTEGER NOT NULL DEFAULT 0")
            ensure_column(db, "matches", "vote_deadline_at", "TEXT")

        admin_exists = db.execute("SELECT 1 FROM users WHERE role = 'admin' LIMIT 1").fetchone()
        if not admin_exists:
            password_hash, salt = hash_password("Admin123!")
            db.execute(
                """
                INSERT INTO users(full_name, normalized_name, password_hash, salt, role, created_at)
                VALUES (?, ?, ?, ?, 'admin', ?)
                """,
                ("Admin", "admin", password_hash, salt, iso_now()),
            )

        # Replace earlier placeholder starter matches if this database was created from v2.
        placeholder_matches = db.execute(
            "SELECT COUNT(*) AS count FROM matches WHERE team_a IN ('Brazil', 'France') AND team_b IN ('Spain', 'Germany') AND final_result IS NULL"
        ).fetchone()["count"]
        if placeholder_matches:
            db.execute("DELETE FROM matches WHERE team_a IN ('Brazil', 'France') AND team_b IN ('Spain', 'Germany') AND final_result IS NULL")

        matches_count = db.execute("SELECT COUNT(*) AS count FROM matches").fetchone()["count"]
        if matches_count == 0:
            for team_a, team_b, kickoff, stage in one_am_seed_matches():
                db.execute(
                    """
                    INSERT INTO matches(team_a, team_b, kickoff_at, vote_deadline_at, stage, status, created_at)
                    VALUES (?, ?, ?, ?, ?, 'scheduled', ?)
                    """,
                    (team_a, team_b, kickoff.isoformat(), kickoff.isoformat(), stage, iso_now()),
                )
        db.commit()

def issue_token(user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    with get_db() as db:
        db.execute(
            "INSERT INTO sessions(token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
            (token, user_id, iso_now(), (utc_now() + timedelta(days=SESSION_DAYS)).isoformat()),
        )
        db.commit()
    return token


def require_user(headers) -> dict:
    auth = headers.get("Authorization", "")
    if not auth.lower().startswith("bearer "):
        raise ApiError(401, "Missing bearer token")
    token = auth.split(" ", 1)[1].strip()
    with get_db() as db:
        row = db.execute(
            """
            SELECT u.id, u.full_name, u.role, s.expires_at
            FROM sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token = ?
            """,
            (token,),
        ).fetchone()
        if not row:
            raise ApiError(401, "Invalid session")
        try:
            expired = parse_dt(row["expires_at"]) < utc_now()
        except Exception:
            expired = True
        if expired:
            db.execute("DELETE FROM sessions WHERE token = ?", (token,))
            db.commit()
            raise ApiError(401, "Session expired")
        return {"id": row["id"], "full_name": row["full_name"], "role": row["role"]}


def require_admin(headers) -> dict:
    user = require_user(headers)
    if user["role"] != "admin":
        raise ApiError(403, "Admin access required")
    return user


def prediction_stats(db: sqlite3.Connection, match_id: int) -> dict:
    rows = db.execute(
        "SELECT prediction, COUNT(*) AS count FROM predictions WHERE match_id = ? GROUP BY prediction",
        (match_id,),
    ).fetchall()
    counts = {"A": 0, "DRAW": 0, "B": 0}
    for row in rows:
        counts[row["prediction"]] = row["count"]
    total = sum(counts.values())
    percentages = {key: (round(value * 100 / total) if total else 0) for key, value in counts.items()}
    return {"total": total, "counts": counts, "percentages": percentages}


def match_out(row: sqlite3.Row, user_id: int, role: str, db: sqlite3.Connection) -> dict:
    kickoff = parse_dt(row["kickoff_at"])
    deadline = vote_deadline_for_match(row)
    has_started = kickoff <= utc_now()
    predictions_closed = deadline <= utc_now() or row["status"] == "finished"
    my_prediction = db.execute(
        "SELECT prediction, points, created_at FROM predictions WHERE user_id = ? AND match_id = ?",
        (user_id, row["id"]),
    ).fetchone()
    stats_visible = predictions_closed or has_started or role == "admin"
    return {
        "id": row["id"],
        "team_a": row["team_a"],
        "team_b": row["team_b"],
        "kickoff_at": row["kickoff_at"],
        "vote_deadline_at": row["vote_deadline_at"] or row["kickoff_at"],
        "stage": row["stage"],
        "status": row["status"],
        "final_result": row["final_result"],
        "has_started": has_started,
        "predictions_closed": predictions_closed,
        "is_finished": row["status"] == "finished",
        "my_prediction": row_to_dict(my_prediction),
        "stats_visible": stats_visible,
        "stats": prediction_stats(db, row["id"]) if stats_visible else None,
    }


class ApiError(Exception):
    def __init__(self, status: int, detail: str):
        super().__init__(detail)
        self.status = status
        self.detail = detail


def clean_match_payload(payload: dict) -> tuple[str, str, datetime, datetime, str]:
    team_a = str(payload.get("team_a", "")).strip()
    team_b = str(payload.get("team_b", "")).strip()
    kickoff_at = str(payload.get("kickoff_at", "")).strip()
    vote_deadline_at = str(payload.get("vote_deadline_at", "") or kickoff_at).strip()
    stage = str(payload.get("stage", "Group Stage")).strip() or "Group Stage"
    if len(team_a) < 2 or len(team_b) < 2:
        raise ApiError(400, "Team names must be at least 2 characters")
    try:
        kickoff = parse_dt(kickoff_at)
    except Exception:
        raise ApiError(400, "Invalid kickoff_at. Use ISO format like 2026-06-24T22:00:00Z")
    try:
        vote_deadline = parse_dt(vote_deadline_at)
    except Exception:
        raise ApiError(400, "Invalid vote_deadline_at. Use ISO format like 2026-06-24T22:00:00Z")
    return team_a, team_b, kickoff, vote_deadline, stage


def json_default(value):
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


class Handler(BaseHTTPRequestHandler):
    server_version = "MSONPredictor/0.2"

    def log_message(self, format, *args):
        print("%s - - [%s] %s" % (self.address_string(), self.log_date_time_string(), format % args))

    def send_json(self, data, status: int = 200):
        encoded = json.dumps(data, default=json_default).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.end_headers()
        self.wfile.write(encoded)

    def send_error_json(self, status: int, detail: str):
        self.send_json({"detail": detail}, status)

    def is_api_path(self, path: str) -> bool:
        return (
            path == "/health"
            or path == "/me"
            or path == "/matches"
            or path == "/predictions"
            or path.startswith("/predictions/")
            or path == "/leaderboard"
            or path == "/my-predictions"
            or path.startswith("/auth/")
            or path.startswith("/admin/")
            or path.startswith("/public/")
        )

    def serve_static(self):
        parsed = urlparse(self.path)
        requested = parsed.path
        if requested == "/":
            requested = "/index.html"
        target = (STATIC_DIR / requested.lstrip("/")).resolve()

        # Flutter web is a single-page app. If the requested path does not exist,
        # fall back to index.html so /display-style URLs can still load.
        if not str(target).startswith(str(STATIC_DIR)) or not target.exists() or target.is_dir():
            target = (STATIC_DIR / "index.html").resolve()

        if not target.exists():
            self.send_error_json(404, "Frontend build not found. Run flutter build web first.")
            return

        content_type, _ = mimetypes.guess_type(str(target))
        content_type = content_type or "application/octet-stream"
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.end_headers()

    def read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            raise ApiError(400, "Invalid JSON body")
        if not isinstance(data, dict):
            raise ApiError(400, "JSON body must be an object")
        return data

    def run_route(self, method: str):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        query = parse_qs(parsed.query)

        if method == "GET" and path == "/health":
            return {"ok": True, "time": iso_now(), "backend": "stdlib-no-install"}

        if method == "POST" and path == "/auth/register":
            payload = self.read_body()
            full_name = str(payload.get("full_name", "")).strip()
            password = str(payload.get("password", ""))
            normalized = normalize_name(full_name)
            if len(full_name) < 3 or len(full_name) > 80:
                raise ApiError(400, "Full name must be between 3 and 80 characters")
            if len(normalized.split()) < 2:
                raise ApiError(400, "Please enter your full first and last name")
            if len(password) < 6:
                raise ApiError(400, "Password must be at least 6 characters")
            password_hash, salt = hash_password(password)
            with get_db() as db:
                try:
                    db.execute(
                        """
                        INSERT INTO users(full_name, normalized_name, password_hash, salt, role, created_at)
                        VALUES (?, ?, ?, ?, 'user', ?)
                        """,
                        (full_name, normalized, password_hash, salt, iso_now()),
                    )
                    db.commit()
                except DB_INTEGRITY_ERROR:
                    raise ApiError(409, "This full name is already registered")
                user = db.execute("SELECT id, full_name, role FROM users WHERE normalized_name = ?", (normalized,)).fetchone()
                user_id = int(user["id"])
            return {"token": issue_token(user_id), "user": row_to_dict(user)}

        if method == "POST" and path == "/auth/login":
            payload = self.read_body()
            normalized = normalize_name(payload.get("full_name", ""))
            password = str(payload.get("password", ""))
            with get_db() as db:
                user = db.execute("SELECT * FROM users WHERE normalized_name = ?", (normalized,)).fetchone()
                if not user or not verify_password(password, user["password_hash"], user["salt"]):
                    raise ApiError(401, "Wrong name or password")
            return {
                "token": issue_token(int(user["id"])),
                "user": {"id": user["id"], "full_name": user["full_name"], "role": user["role"]},
            }

        if method == "GET" and path == "/me":
            return require_user(self.headers)

        if method == "GET" and path == "/matches":
            user = require_user(self.headers)
            scope = query.get("scope", ["all"])[0]
            if scope not in {"all", "today", "upcoming", "finished"}:
                raise ApiError(400, "Invalid scope")
            with get_db() as db:
                rows = db.execute("SELECT * FROM matches ORDER BY kickoff_at ASC, id ASC").fetchall()
                output = []
                today = utc_now().date()
                for row in rows:
                    kickoff = parse_dt(row["kickoff_at"])
                    if scope == "today" and kickoff.date() != today:
                        continue
                    if scope == "upcoming" and kickoff <= utc_now():
                        continue
                    if scope == "finished" and row["status"] != "finished":
                        continue
                    output.append(match_out(row, user["id"], user["role"], db))
            return output

        if method == "POST" and path == "/predictions":
            user = require_user(self.headers)
            payload = self.read_body()
            try:
                match_id = int(payload.get("match_id"))
            except Exception:
                raise ApiError(400, "Invalid match_id")
            prediction = str(payload.get("prediction", "")).upper()
            if prediction not in {"A", "DRAW", "B"}:
                raise ApiError(400, "Prediction must be A, DRAW, or B")
            with get_db() as db:
                match = db.execute("SELECT * FROM matches WHERE id = ?", (match_id,)).fetchone()
                if not match:
                    raise ApiError(404, "Match not found")
                if match["status"] == "finished" or vote_deadline_for_match(match) <= utc_now():
                    raise ApiError(409, "Predictions are closed for this match")
                try:
                    db.execute(
                        """
                        INSERT INTO predictions(user_id, match_id, prediction, locked, points, created_at)
                        VALUES (?, ?, ?, 1, 0, ?)
                        """,
                        (user["id"], match_id, prediction, iso_now()),
                    )
                    db.commit()
                except DB_INTEGRITY_ERROR:
                    raise ApiError(409, "You already locked a prediction for this match")
            return {"ok": True, "message": "Prediction locked"}

        if method == "DELETE" and path.startswith("/predictions/"):
            user = require_user(self.headers)
            parts = path.split("/")
            try:
                match_id = int(parts[2])
            except Exception:
                raise ApiError(400, "Invalid match_id")

            with get_db() as db:
                match = db.execute("SELECT * FROM matches WHERE id = ?", (match_id,)).fetchone()
                if not match:
                    raise ApiError(404, "Match not found")
                if match["status"] == "finished" or vote_deadline_for_match(match) <= utc_now():
                    raise ApiError(409, "Voting deadline passed. Prediction cannot be unlocked.")

                cur = db.execute(
                    "DELETE FROM predictions WHERE user_id = ? AND match_id = ?",
                    (user["id"], match_id),
                )
                if cur.rowcount == 0:
                    raise ApiError(404, "No locked prediction found for this match")
                db.commit()

            return {"ok": True, "message": "Prediction unlocked"}

        if method == "GET" and path == "/public/leaderboard":
            try:
                limit = int(query.get("limit", ["10"])[0])
            except Exception:
                limit = 10
            limit = max(1, min(limit, 50))
            with get_db() as db:
                rows = db.execute(
                    """
                    SELECT
                        u.id AS user_id,
                        u.full_name,
                        u.manual_points,
                        COALESCE(SUM(p.points), 0) AS prediction_points,
                        (u.manual_points + COALESCE(SUM(p.points), 0)) AS points,
                        COUNT(p.id) AS total_predictions,
                        COALESCE(SUM(CASE WHEN p.points = 1 THEN 1 ELSE 0 END), 0) AS correct_predictions
                    FROM users u
                    LEFT JOIN predictions p ON p.user_id = u.id
                    WHERE u.role = 'user'
                    GROUP BY u.id, u.full_name, u.manual_points
                    ORDER BY points DESC, correct_predictions DESC, total_predictions DESC, u.full_name ASC
                    LIMIT ?
                    """,
                    (limit,),
                ).fetchall()
                return [
                    {
                        "rank": index + 1,
                        "full_name": row["full_name"],
                        "points": row["points"],
                        "correct_predictions": row["correct_predictions"],
                        "total_predictions": row["total_predictions"],
                    }
                    for index, row in enumerate(rows)
                ]

        if method == "GET" and path == "/leaderboard":
            require_user(self.headers)
            with get_db() as db:
                rows = db.execute(
                    """
                    SELECT
                        u.id AS user_id,
                        u.full_name,
                        u.manual_points,
                        COALESCE(SUM(p.points), 0) AS prediction_points,
                        (u.manual_points + COALESCE(SUM(p.points), 0)) AS points,
                        COUNT(p.id) AS total_predictions,
                        COALESCE(SUM(CASE WHEN p.points = 1 THEN 1 ELSE 0 END), 0) AS correct_predictions
                    FROM users u
                    LEFT JOIN predictions p ON p.user_id = u.id
                    WHERE u.role = 'user'
                    GROUP BY u.id, u.full_name, u.manual_points
                    ORDER BY points DESC, correct_predictions DESC, total_predictions DESC, u.full_name ASC
                    """
                ).fetchall()
                return [row_to_dict(row) | {"rank": index + 1} for index, row in enumerate(rows)]

        if method == "GET" and path == "/my-predictions":
            user = require_user(self.headers)
            with get_db() as db:
                rows = db.execute(
                    """
                    SELECT
                        p.match_id,
                        p.prediction,
                        p.points,
                        p.created_at,
                        m.team_a,
                        m.team_b,
                        m.kickoff_at,
                        m.vote_deadline_at,
                        m.stage,
                        m.status,
                        m.final_result
                    FROM predictions p
                    JOIN matches m ON m.id = p.match_id
                    WHERE p.user_id = ?
                    ORDER BY m.kickoff_at DESC
                    """,
                    (user["id"],),
                ).fetchall()
                return [row_to_dict(row) for row in rows]

        if method == "POST" and path == "/admin/matches":
            require_admin(self.headers)
            payload = self.read_body()
            team_a, team_b, kickoff, vote_deadline, stage = clean_match_payload(payload)
            with get_db() as db:
                db.execute(
                    """
                    INSERT INTO matches(team_a, team_b, kickoff_at, vote_deadline_at, stage, status, created_at)
                    VALUES (?, ?, ?, ?, ?, 'scheduled', ?)
                    """,
                    (team_a, team_b, kickoff.isoformat(), vote_deadline.isoformat(), stage, iso_now()),
                )
                created = db.execute(
                    "SELECT id FROM matches WHERE team_a = ? AND team_b = ? AND kickoff_at = ? ORDER BY id DESC LIMIT 1",
                    (team_a, team_b, kickoff.isoformat()),
                ).fetchone()
                db.commit()
                return {"ok": True, "match_id": created["id"] if created else None}

        if method == "PATCH" and path.startswith("/admin/matches/") and not path.endswith("/result"):
            require_admin(self.headers)
            parts = path.split("/")
            try:
                match_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid match_id")
            payload = self.read_body()
            team_a, team_b, kickoff, vote_deadline, stage = clean_match_payload(payload)
            status = str(payload.get("status", "scheduled")).strip().lower() or "scheduled"
            if status not in {"scheduled", "finished"}:
                raise ApiError(400, "status must be scheduled or finished")
            with get_db() as db:
                row = db.execute("SELECT 1 FROM matches WHERE id = ?", (match_id,)).fetchone()
                if not row:
                    raise ApiError(404, "Match not found")
                db.execute(
                    """
                    UPDATE matches
                    SET team_a = ?, team_b = ?, kickoff_at = ?, vote_deadline_at = ?, stage = ?, status = ?
                    WHERE id = ?
                    """,
                    (team_a, team_b, kickoff.isoformat(), vote_deadline.isoformat(), stage, status, match_id),
                )
                db.commit()
            return {"ok": True}

        if method == "GET" and path.startswith("/admin/matches/") and path.endswith("/predictions"):
            require_admin(self.headers)
            parts = path.split("/")
            try:
                match_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid match_id")

            def label_for(match_row, value: str | None) -> str:
                value = str(value or "").upper()
                if value == "A":
                    return f"{match_row['team_a']} Win"
                if value == "B":
                    return f"{match_row['team_b']} Win"
                if value == "DRAW":
                    return "Draw"
                return "Not set"

            with get_db() as db:
                match = db.execute("SELECT * FROM matches WHERE id = ?", (match_id,)).fetchone()
                if not match:
                    raise ApiError(404, "Match not found")

                rows = db.execute(
                    """
                    SELECT
                        p.id,
                        p.user_id,
                        u.full_name,
                        u.normalized_name,
                        p.prediction,
                        p.points,
                        p.created_at
                    FROM predictions p
                    JOIN users u ON u.id = p.user_id
                    WHERE p.match_id = ?
                    ORDER BY u.full_name ASC
                    """,
                    (match_id,),
                ).fetchall()

                final_result = match["final_result"]
                total = len(rows)
                correct = 0
                wrong = 0
                output_rows = []

                for row in rows:
                    is_correct = None
                    if final_result:
                        is_correct = row["prediction"] == final_result
                        if is_correct:
                            correct += 1
                        else:
                            wrong += 1

                    output_rows.append(
                        {
                            "prediction_id": row["id"],
                            "user_id": row["user_id"],
                            "full_name": row["full_name"],
                            "username": row["normalized_name"],
                            "prediction": row["prediction"],
                            "prediction_label": label_for(match, row["prediction"]),
                            "points": row["points"],
                            "submitted_at": row["created_at"],
                            "is_correct": is_correct,
                        }
                    )

                return {
                    "match": {
                        "id": match["id"],
                        "team_a": match["team_a"],
                        "team_b": match["team_b"],
                        "stage": match["stage"],
                        "kickoff_at": match["kickoff_at"],
                        "vote_deadline_at": match["vote_deadline_at"] or match["kickoff_at"],
                        "status": match["status"],
                        "final_result": final_result,
                        "final_result_label": label_for(match, final_result) if final_result else "Not set",
                    },
                    "total_predictions": total,
                    "correct_predictions": correct,
                    "wrong_predictions": wrong,
                    "rows": output_rows,
                }

        if method == "GET" and path == "/admin/users":
            require_admin(self.headers)
            with get_db() as db:
                rows = db.execute(
                    """
                    SELECT
                        u.id, u.full_name, u.normalized_name, u.role, u.manual_points, u.created_at,
                        COUNT(p.id) AS total_predictions,
                        COALESCE(SUM(p.points), 0) AS prediction_points,
                        COALESCE(SUM(CASE WHEN p.points = 1 THEN 1 ELSE 0 END), 0) AS correct_predictions
                    FROM users u
                    LEFT JOIN predictions p ON p.user_id = u.id
                    GROUP BY u.id, u.full_name, u.normalized_name, u.role, u.manual_points, u.created_at
                    ORDER BY u.role ASC, u.full_name ASC
                    """
                ).fetchall()
                return [
                    dict(row) | {"password_note": "Hidden securely. Admin can reset password, not view it."}
                    for row in rows
                ]

        if method == "DELETE" and path.startswith("/admin/users/"):
            admin = require_admin(self.headers)
            parts = path.split("/")
            try:
                user_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid user_id")
            if user_id == admin["id"]:
                raise ApiError(409, "You cannot delete your own admin account")
            with get_db() as db:
                user_row = db.execute("SELECT role FROM users WHERE id = ?", (user_id,)).fetchone()
                if not user_row:
                    raise ApiError(404, "User not found")
                if user_row["role"] == "admin":
                    raise ApiError(409, "Admin users cannot be deleted from this page")
                db.execute("DELETE FROM users WHERE id = ?", (user_id,))
                db.commit()
            return {"ok": True}

        if method == "PATCH" and path.startswith("/admin/users/") and path.endswith("/password"):
            require_admin(self.headers)
            parts = path.split("/")
            try:
                user_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid user_id")
            payload = self.read_body()
            new_password = str(payload.get("new_password", ""))
            if len(new_password) < 6:
                raise ApiError(400, "New password must be at least 6 characters")
            password_hash, salt = hash_password(new_password)
            with get_db() as db:
                cur = db.execute("UPDATE users SET password_hash = ?, salt = ? WHERE id = ?", (password_hash, salt, user_id))
                if cur.rowcount == 0:
                    raise ApiError(404, "User not found")
                db.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
                db.commit()
            return {"ok": True}

        if method == "PATCH" and path.startswith("/admin/users/") and path.endswith("/manual-points"):
            require_admin(self.headers)
            parts = path.split("/")
            try:
                user_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid user_id")
            payload = self.read_body()
            try:
                manual_points = int(payload.get("manual_points", 0))
            except Exception:
                raise ApiError(400, "manual_points must be a whole number")
            with get_db() as db:
                cur = db.execute("UPDATE users SET manual_points = ? WHERE id = ? AND role = 'user'", (manual_points, user_id))
                if cur.rowcount == 0:
                    raise ApiError(404, "User not found")
                db.commit()
            return {"ok": True}

        if method == "PATCH" and path.startswith("/admin/matches/") and path.endswith("/result"):
            require_admin(self.headers)
            parts = path.split("/")
            try:
                match_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid match_id")
            payload = self.read_body()
            final_result = str(payload.get("final_result", "")).upper()
            if final_result not in {"A", "DRAW", "B"}:
                raise ApiError(400, "final_result must be A, DRAW, or B")
            with get_db() as db:
                match = db.execute("SELECT * FROM matches WHERE id = ?", (match_id,)).fetchone()
                if not match:
                    raise ApiError(404, "Match not found")
                db.execute("UPDATE matches SET final_result = ?, status = 'finished' WHERE id = ?", (final_result, match_id))
                db.execute(
                    "UPDATE predictions SET points = CASE WHEN prediction = ? THEN 1 ELSE 0 END WHERE match_id = ?",
                    (final_result, match_id),
                )
                affected = db.execute("SELECT COUNT(*) AS count FROM predictions WHERE match_id = ?", (match_id,)).fetchone()["count"]
                correct = db.execute(
                    "SELECT COUNT(*) AS count FROM predictions WHERE match_id = ? AND prediction = ?",
                    (match_id, final_result),
                ).fetchone()["count"]
                db.commit()
            return {"ok": True, "updated_predictions": affected, "correct_predictions": correct}

        if method == "DELETE" and path.startswith("/admin/matches/"):
            require_admin(self.headers)
            parts = path.split("/")
            try:
                match_id = int(parts[3])
            except Exception:
                raise ApiError(400, "Invalid match_id")
            with get_db() as db:
                db.execute("DELETE FROM matches WHERE id = ?", (match_id,))
                db.commit()
            return {"ok": True}

        if method == "POST" and path == "/admin/seed-demo":
            require_admin(self.headers)
            seed_matches = one_am_seed_matches()
            inserted = 0
            with get_db() as db:
                for team_a, team_b, kickoff, stage in seed_matches:
                    exists = db.execute(
                        "SELECT 1 FROM matches WHERE team_a = ? AND team_b = ? AND kickoff_at = ?",
                        (team_a, team_b, kickoff.isoformat()),
                    ).fetchone()
                    if exists:
                        continue
                    db.execute(
                        "INSERT INTO matches(team_a, team_b, kickoff_at, vote_deadline_at, stage, status, created_at) VALUES (?, ?, ?, ?, ?, 'scheduled', ?)",
                        (team_a, team_b, kickoff.isoformat(), kickoff.isoformat(), stage, iso_now()),
                    )
                    inserted += 1
                db.commit()
            return {"ok": True, "inserted": inserted, "kickoff_jordan_time": seed_matches[0][2].astimezone(JORDAN_TZ).isoformat()}

        raise ApiError(404, "Not found")

    def handle_method(self, method: str):
        try:
            data = self.run_route(method)
            self.send_json(data)
        except ApiError as exc:
            self.send_error_json(exc.status, exc.detail)
        except Exception as exc:
            print("SERVER ERROR:", repr(exc))
            self.send_error_json(500, "Server error: " + str(exc))

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if STATIC_DIR.exists() and not self.is_api_path(path):
            self.serve_static()
            return
        self.handle_method("GET")

    def do_POST(self):
        self.handle_method("POST")

    def do_PATCH(self):
        self.handle_method("PATCH")

    def do_DELETE(self):
        self.handle_method("DELETE")


if __name__ == "__main__":
    init_db()
    print("Michael & Son World Cup Predictor API")
    print("Stdlib HTTP backend with SQLite local / PostgreSQL online support")
    print(f"Database: {'PostgreSQL' if USE_POSTGRES else 'SQLite'}")
    print(f"Running on http://{HOST}:{PORT}")
    print(f"Static frontend directory: {STATIC_DIR}")
    print("Health check: /health")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
