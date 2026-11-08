-- Part 2: load mock sources into raw/meta tables (reference SQL)
-- Preferred entrypoint on Windows: python/init_db.py (uses absolute CSV paths).
-- Paths below are relative to the DuckDB working directory (repo root).

DELETE FROM raw.trino_query_accessed_tables;
DELETE FROM raw.trino_query_history;
DELETE FROM meta.user_team_scd;
DELETE FROM meta.table_catalog;

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
FROM read_csv_auto('sample_data/trino_query_history.csv', header := true);

INSERT INTO raw.trino_query_accessed_tables
SELECT
    query_id,
    catalog_name,
    schema_name,
    table_name,
    access_type
FROM read_csv_auto('sample_data/trino_query_accessed_tables.csv', header := true);

INSERT INTO meta.user_team_scd
SELECT
    user_id,
    team_id,
    team_name,
    valid_from::TIMESTAMP,
    CASE
        WHEN valid_to IS NULL OR trim(CAST(valid_to AS VARCHAR)) = '' THEN NULL
        ELSE valid_to::TIMESTAMP
    END AS valid_to,
    CAST(is_current AS BOOLEAN) AS is_current
FROM read_csv_auto(
    'sample_data/meta_user_team_scd.csv',
    header := true,
    timestampformat := '%Y-%m-%d %H:%M:%S',
    nullstr := ''
);

INSERT INTO meta.table_catalog
SELECT
    table_fqn,
    layer,
    owner_team_id,
    description,
    CAST(is_iceberg AS BOOLEAN) AS is_iceberg
FROM read_csv_auto('sample_data/meta_table_catalog.csv', header := true);
