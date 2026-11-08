-- Part 3: staging transforms
-- Normalize terminal Trino queries, resolve team as-of start time, equal-split weights.

DELETE FROM stg.trino_query_table;
DELETE FROM stg.trino_query;

INSERT INTO stg.trino_query
WITH terminal AS (
    SELECT *
    FROM raw.trino_query_history
    WHERE query_state IN ('FINISHED', 'FAILED')
),
table_counts AS (
    SELECT
        query_id,
        COUNT(*) AS table_count
    FROM raw.trino_query_accessed_tables
    GROUP BY query_id
),
with_team AS (
    SELECT
        q.query_id,
        q.user_id,
        COALESCE(t.team_id, 'unknown') AS team_id,
        q.query_state,
        q.query_source,
        q.started_at,
        q.ended_at,
        CAST(strftime(q.started_at, '%Y%m%d') AS INTEGER) AS date_id,
        q.cpu_time_ms,
        q.wall_time_ms,
        q.bytes_scanned,
        q.peak_memory_bytes,
        q.output_rows,
        q.output_bytes,
        (q.query_state = 'FAILED') AS is_failed,
        COALESCE(tc.table_count, 0) AS table_count
    FROM terminal q
    LEFT JOIN meta.user_team_scd t
        ON q.user_id = t.user_id
       AND q.started_at >= t.valid_from
       AND (t.valid_to IS NULL OR q.started_at < t.valid_to)
    LEFT JOIN table_counts tc
        ON q.query_id = tc.query_id
)
SELECT *
FROM with_team;

INSERT INTO stg.trino_query_table
WITH accessed AS (
    SELECT
        a.query_id,
        a.catalog_name || '.' || a.schema_name || '.' || a.table_name AS table_fqn,
        a.catalog_name,
        a.schema_name,
        a.table_name,
        a.access_type
    FROM raw.trino_query_accessed_tables a
    INNER JOIN stg.trino_query q
        ON a.query_id = q.query_id
),
weighted AS (
    SELECT
        query_id,
        table_fqn,
        catalog_name,
        schema_name,
        table_name,
        access_type,
        1.0 / COUNT(*) OVER (PARTITION BY query_id) AS attribution_weight,
        'equal_split' AS attribution_method
    FROM accessed
)
SELECT *
FROM weighted;
