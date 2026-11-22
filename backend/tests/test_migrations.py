import os
import sqlite3
import subprocess
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]


def _alembic(db_path: Path, *args: str) -> None:
    env = {**os.environ, "PUT_DATABASE_URL": f"sqlite+aiosqlite:///{db_path.as_posix()}"}
    subprocess.run(
        [sys.executable, "-X", "utf8", "-m", "alembic", *args],
        cwd=BACKEND_DIR,
        env=env,
        check=True,
        capture_output=True,
    )


def test_migrations_upgrade_and_downgrade(tmp_path: Path) -> None:
    db_path = tmp_path / "migrations.db"

    _alembic(db_path, "upgrade", "head")
    with sqlite3.connect(db_path) as connection:
        tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master")}
        cities = connection.execute("SELECT COUNT(*) FROM cities").fetchone()[0]
        models = connection.execute("SELECT COUNT(*) FROM car_models").fetchone()[0]
    assert {
        "users",
        "cities",
        "auth_codes",
        "refresh_tokens",
        "trips",
        "cars",
        "bookings",
        "payments",
        "notifications",
        "reviews",
        "complaints",
        "cancellations",
    } <= tables
    assert cities >= 20
    assert models >= 50

    _alembic(db_path, "downgrade", "base")
    _alembic(db_path, "upgrade", "head")
