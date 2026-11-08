-- Part 3: core facts and bridge (query-level truth + table attribution)

DELETE FROM core.bridge_query_table;
DELETE FROM core.fact_table_usage_daily;
DELETE FROM core.fact_query;

INSERT INTO core.fact_query
SELECT
    query_id,
    user_id,
    team_id,
    date_id,
    query_state,
    query_source,
    started_at,
    ended_at,
    cpu_time_ms,
    wall_time_ms,
    bytes_scanned,
    peak_memory_bytes,
    output_rows,
    output_bytes,
    table_count,
    is_failed
FROM stg.trino_query;

INSERT INTO core.bridge_query_table
SELECT
    s.query_id,
    s.table_fqn AS table_id,
    s.access_type,
    s.attribution_weight,
    s.attribution_method,
    q.cpu_time_ms * s.attribution_weight AS attributed_cpu_time_ms,
    q.bytes_scanned * s.attribution_weight AS attributed_bytes_scanned,
    q.peak_memory_bytes * s.attribution_weight AS attributed_peak_memory_bytes
FROM stg.trino_query_table s
INNER JOIN stg.trino_query q
    ON s.query_id = q.query_id;

INSERT INTO core.fact_table_usage_daily
SELECT
    q.date_id,
    b.table_id,
    q.user_id,
    q.team_id,
    COUNT(*) AS query_count,
    SUM(CASE WHEN q.is_failed THEN 1 ELSE 0 END) AS failed_query_count,
    SUM(b.attributed_cpu_time_ms) AS attributed_cpu_time_ms,
    SUM(b.attributed_bytes_scanned) AS attributed_bytes_scanned,
    SUM(b.attributed_peak_memory_bytes) AS attributed_peak_memory_bytes
FROM core.bridge_query_table b
INNER JOIN core.fact_query q
    ON b.query_id = q.query_id
GROUP BY
    q.date_id,
    b.table_id,
    q.user_id,
    q.team_id;
