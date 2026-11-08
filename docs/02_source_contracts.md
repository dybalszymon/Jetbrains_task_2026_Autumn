# Part 2 — Source contracts & code layout

This part materializes the design as **DDL + mock sources**. Transformations come in Part 3.

## Layout

```text
sql/00_ddl.sql              -- schemas + empty tables (DuckDB dialect)
sql/00_load_sources.sql     -- load CSVs into raw/meta source tables
sample_data/
  trino_query_history.csv
  trino_query_accessed_tables.csv
  meta_user_team_scd.csv
  meta_table_catalog.csv
python/init_db.py           -- create DuckDB file and run Part 2 SQL
```

## Source contracts

### `raw.trino_query_history`

One row per terminal Trino query.

| Column | Type | Notes |
|--------|------|-------|
| query_id | VARCHAR | PK |
| user_id | VARCHAR | Principal |
| query_state | VARCHAR | `FINISHED` / `FAILED` (sample has no RUNNING) |
| query_source | VARCHAR | `ui` / `jdbc` / `dbt` / … |
| started_at | TIMESTAMP | UTC |
| ended_at | TIMESTAMP | UTC |
| cpu_time_ms | BIGINT | |
| wall_time_ms | BIGINT | |
| bytes_scanned | BIGINT | |
| peak_memory_bytes | BIGINT | |
| output_rows | BIGINT | |
| output_bytes | BIGINT | |

### `raw.trino_query_accessed_tables`

One row per (`query_id`, accessed table). Structured relation list (preferred over SQL parsing).

| Column | Type | Notes |
|--------|------|-------|
| query_id | VARCHAR | FK → query history |
| catalog_name | VARCHAR | e.g. `analytics` |
| schema_name | VARCHAR | e.g. `mart` |
| table_name | VARCHAR | e.g. `ide_usage_daily` |
| access_type | VARCHAR | `SELECT` / `INSERT` / `MERGE` |

`table_fqn` = `catalog_name || '.' || schema_name || '.' || table_name`.

### `meta.user_team_scd`

SCD2 org mapping.

| Column | Type | Notes |
|--------|------|-------|
| user_id | VARCHAR | |
| team_id | VARCHAR | |
| team_name | VARCHAR | |
| valid_from | TIMESTAMP | Inclusive |
| valid_to | TIMESTAMP | Exclusive; empty = current |
| is_current | BOOLEAN | |

### `meta.table_catalog`

Optional enrichment for Iceberg analytical tables.

| Column | Type | Notes |
|--------|------|-------|
| table_fqn | VARCHAR | PK natural key |
| layer | VARCHAR | `raw` / `stage` / `mart` |
| owner_team_id | VARCHAR | Data owner |
| description | VARCHAR | For humans / AI agents |
| is_iceberg | BOOLEAN | In-scope filter |

## Local engine choice

**DuckDB** is used only so the assignment runs without a Trino cluster. SQL stays close to ANSI / Trino and can be ported later. Production target remains Trino + Iceberg on S3.
