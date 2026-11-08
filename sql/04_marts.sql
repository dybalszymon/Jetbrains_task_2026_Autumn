-- Part 3: business-facing daily marts

DELETE FROM mart.table_usage_daily;
DELETE FROM mart.team_resource_daily;

INSERT INTO mart.table_usage_daily
SELECT
    f.date_id,
    f.table_id,
    t.table_fqn,
    COUNT(DISTINCT f.user_id) AS distinct_users,
    SUM(f.query_count) AS query_count,
    SUM(f.failed_query_count) AS failed_query_count,
    SUM(f.attributed_cpu_time_ms) AS attributed_cpu_time_ms,
    SUM(f.attributed_bytes_scanned) AS attributed_bytes_scanned
FROM core.fact_table_usage_daily f
INNER JOIN core.dim_table t
    ON f.table_id = t.table_id
GROUP BY
    f.date_id,
    f.table_id,
    t.table_fqn;

INSERT INTO mart.team_resource_daily
SELECT
    q.date_id,
    q.team_id,
    tm.team_name,
    COUNT(*) AS query_count,
    SUM(CASE WHEN q.is_failed THEN 1 ELSE 0 END) AS failed_query_count,
    SUM(q.cpu_time_ms) AS cpu_time_ms,
    SUM(q.wall_time_ms) AS wall_time_ms,
    SUM(q.bytes_scanned) AS bytes_scanned,
    MAX(q.peak_memory_bytes) AS peak_memory_bytes_max,
    COUNT(DISTINCT q.user_id) AS distinct_users,
    COUNT(DISTINCT b.table_id) AS distinct_tables
FROM core.fact_query q
INNER JOIN core.dim_team tm
    ON q.team_id = tm.team_id
LEFT JOIN core.bridge_query_table b
    ON q.query_id = b.query_id
GROUP BY
    q.date_id,
    q.team_id,
    tm.team_name;

-- Watermark for incremental story (full rebuild demo sets it to max ended_at)
DELETE FROM meta.etl_watermark WHERE pipeline_name = 'meta_dwh_usage';
INSERT INTO meta.etl_watermark
SELECT
    'meta_dwh_usage' AS pipeline_name,
    COALESCE(MAX(ended_at), TIMESTAMPTZ '1970-01-01') AS watermark_ts,
    CURRENT_TIMESTAMP AS updated_at
FROM core.fact_query;
