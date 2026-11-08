"""Part 2: create local DuckDB Meta DWH and load sample sources."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "meta_dwh.duckdb"
DDL_PATH = ROOT / "sql" / "00_ddl.sql"
SAMPLE = ROOT / "sample_data"


def main() -> int:
    try:
        import duckdb
    except ImportError:
        print("duckdb is not installed. Run: pip install -r requirements.txt", file=sys.stderr)
        return 1

    DB_PATH.unlink(missing_ok=True)
    con = duckdb.connect(str(DB_PATH))

    try:
        con.execute(DDL_PATH.read_text(encoding="utf-8"))

        # Absolute paths avoid cwd / file_search_path issues on Windows.
        history = (SAMPLE / "trino_query_history.csv").as_posix()
        accessed = (SAMPLE / "trino_query_accessed_tables.csv").as_posix()
        teams = (SAMPLE / "meta_user_team_scd.csv").as_posix()
        catalog = (SAMPLE / "meta_table_catalog.csv").as_posix()

        con.execute("DELETE FROM raw.trino_query_accessed_tables")
        con.execute("DELETE FROM raw.trino_query_history")
        con.execute("DELETE FROM meta.user_team_scd")
        con.execute("DELETE FROM meta.table_catalog")

        con.execute(
            f"""
            INSERT INTO raw.trino_query_history
            SELECT
                query_id,
                user_id,
                query_state,
                query_source,
                started_at::TIMESTAMP,
                ended_at::TIMESTAMP,
                cpu_time_ms::BIGINT,
                wall_time_ms::BIGINT,
                bytes_scanned::BIGINT,
                peak_memory_bytes::BIGINT,
                output_rows::BIGINT,
                output_bytes::BIGINT
            FROM read_csv('{history}', header := true, auto_detect := true)
            """
        )

        con.execute(
            f"""
            INSERT INTO raw.trino_query_accessed_tables
            SELECT
                query_id,
                catalog_name,
                schema_name,
                table_name,
                access_type
            FROM read_csv('{accessed}', header := true, auto_detect := true)
            """
        )

        con.execute(
            f"""
            INSERT INTO meta.user_team_scd
            SELECT
                user_id,
                team_id,
                team_name,
                strptime(valid_from, '%Y-%m-%d %H:%M:%S') AS valid_from,
                CASE
                    WHEN valid_to IS NULL OR valid_to = '' THEN NULL
                    ELSE strptime(valid_to, '%Y-%m-%d %H:%M:%S')
                END AS valid_to,
                lower(CAST(is_current AS VARCHAR)) IN ('true', '1', 't') AS is_current
            FROM read_csv(
                '{teams}',
                header := true,
                all_varchar := true,
                nullstr := ''
            )
            """
        )

        con.execute(
            f"""
            INSERT INTO meta.table_catalog
            SELECT
                table_fqn,
                layer,
                owner_team_id,
                description,
                lower(CAST(is_iceberg AS VARCHAR)) IN ('true', '1', 't') AS is_iceberg
            FROM read_csv('{catalog}', header := true, auto_detect := true)
            """
        )

        print(f"Created {DB_PATH}")
        for label, sql in [
            ("raw.trino_query_history", "SELECT COUNT(*) FROM raw.trino_query_history"),
            (
                "raw.trino_query_accessed_tables",
                "SELECT COUNT(*) FROM raw.trino_query_accessed_tables",
            ),
            ("meta.user_team_scd", "SELECT COUNT(*) FROM meta.user_team_scd"),
            ("meta.table_catalog", "SELECT COUNT(*) FROM meta.table_catalog"),
        ]:
            n = con.execute(sql).fetchone()[0]
            print(f"  {label}: {n} rows")

        dave_teams = con.execute(
            """
            SELECT team_id, valid_from, valid_to, is_current
            FROM meta.user_team_scd
            WHERE user_id = 'dave'
            ORDER BY valid_from
            """
        ).fetchall()
        print("  dave team history:")
        for row in dave_teams:
            print(f"    {row}")

        return 0
    except Exception as exc:  # noqa: BLE001 - show load errors clearly for reviewers
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())
