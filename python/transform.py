"""Part 3: run staging → dimensions → facts → marts transforms."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "meta_dwh.duckdb"
SQL_FILES = [
    ROOT / "sql" / "01_staging.sql",
    ROOT / "sql" / "02_dimensions.sql",
    ROOT / "sql" / "03_facts.sql",
    ROOT / "sql" / "04_marts.sql",
]


def run_transforms(con) -> None:
    for path in SQL_FILES:
        con.execute(path.read_text(encoding="utf-8"))
        print(f"  applied {path.name}")


def _print_checks(con) -> None:
    checks = [
        ("stg.trino_query", "SELECT COUNT(*) FROM stg.trino_query"),
        ("stg.trino_query_table", "SELECT COUNT(*) FROM stg.trino_query_table"),
        ("core.fact_query", "SELECT COUNT(*) FROM core.fact_query"),
        ("core.bridge_query_table", "SELECT COUNT(*) FROM core.bridge_query_table"),
        ("core.fact_table_usage_daily", "SELECT COUNT(*) FROM core.fact_table_usage_daily"),
        ("mart.table_usage_daily", "SELECT COUNT(*) FROM mart.table_usage_daily"),
        ("mart.team_resource_daily", "SELECT COUNT(*) FROM mart.team_resource_daily"),
    ]
    for label, sql in checks:
        print(f"  {label}: {con.execute(sql).fetchone()[0]} rows")

    # DQ: attribution weights per query should sum to ~1
    bad = con.execute(
        """
        SELECT COUNT(*) FROM (
            SELECT query_id, SUM(attribution_weight) AS w
            FROM core.bridge_query_table
            GROUP BY query_id
            HAVING abs(SUM(attribution_weight) - 1.0) > 1e-6
        )
        """
    ).fetchone()[0]
    print(f"  dq weight_sum_ne_1: {bad} queries")

    # dave as-of: before 2026-01-04 licensing, on/after analytics
    dave = con.execute(
        """
        SELECT query_id, team_id, started_at
        FROM core.fact_query
        WHERE user_id = 'dave'
        ORDER BY started_at
        """
    ).fetchall()
    print("  dave query teams (as-of):")
    for row in dave:
        print(f"    {row}")


def main() -> int:
    try:
        import duckdb
    except ImportError:
        print("duckdb is not installed. Run: pip install -r requirements.txt", file=sys.stderr)
        return 1

    if not DB_PATH.exists():
        print(f"Missing {DB_PATH}. Run python/init_db.py first (or python/run_pipeline.py).", file=sys.stderr)
        return 1

    con = duckdb.connect(str(DB_PATH))
    try:
        print(f"Transforming {DB_PATH}")
        run_transforms(con)
        _print_checks(con)
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())
