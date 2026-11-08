"""Part 4: execute example analytical queries and print results."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "meta_dwh.duckdb"
SQL_PATH = ROOT / "sql" / "05_example_queries.sql"


def _split_statements(sql_text: str) -> list[tuple[str, str]]:
    """Return (title, sql) pairs for executable SELECT statements."""
    statements: list[tuple[str, str]] = []
    title = "query"
    sql_lines: list[str] = []

    def flush() -> None:
        nonlocal sql_lines
        sql = "\n".join(sql_lines).strip().rstrip(";")
        if sql.upper().startswith("SELECT"):
            statements.append((title, sql))
        sql_lines = []

    for raw in sql_text.splitlines():
        line = raw.rstrip()
        stripped = line.strip()

        if stripped.startswith("-- ==="):
            flush()
            continue

        if stripped.startswith("-- Q") or stripped.startswith("-- Bonus"):
            flush()
            title = stripped.lstrip("- ").strip()
            continue

        if stripped.startswith("--") or not stripped:
            continue

        sql_lines.append(line)

    flush()
    return statements


def main() -> int:
    try:
        import duckdb
    except ImportError:
        print("duckdb is not installed. Run: pip install -r requirements.txt", file=sys.stderr)
        return 1

    if not DB_PATH.exists():
        print(f"Missing {DB_PATH}. Run python/run_pipeline.py first.", file=sys.stderr)
        return 1

    con = duckdb.connect(str(DB_PATH), read_only=True)
    try:
        statements = _split_statements(SQL_PATH.read_text(encoding="utf-8"))
        if not statements:
            print("No SELECT statements found.", file=sys.stderr)
            return 1

        print(f"Running example queries from {SQL_PATH.name}\n")
        for title, sql in statements:
            print("=" * 72)
            print(title)
            print("-" * 72)
            rel = con.execute(sql)
            cols = [d[0] for d in rel.description]
            rows = rel.fetchall()
            print(" | ".join(cols))
            if not rows:
                print("(no rows)")
            else:
                for row in rows:
                    print(" | ".join(str(v) for v in row))
            print()
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())
