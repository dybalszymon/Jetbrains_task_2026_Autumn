-- Part 4: example analytical queries for the assignment brief
-- Prerequisites: python python/run_pipeline.py
--
-- Q1: How many distinct users queried table X during a period?
-- Q2: How many resources did team Y consume during that period?

-- Shared demo parameters (edit as needed)
--   table X : analytics.mart.ide_usage_daily
--   team Y  : team_analytics
--   period  : 2026-01-02 .. 2026-01-05  → date_id 20260102 .. 20260105

-- =============================================================================
-- Q1a — Exact distinct users for table X over the whole period
--       (preferred for the literal brief question)
-- =============================================================================
SELECT
    t.table_fqn,
    COUNT(DISTINCT f.user_id) AS distinct_users,
    SUM(f.query_count) AS query_count,
    ROUND(SUM(f.attributed_bytes_scanned), 0) AS attributed_bytes_scanned,
    ROUND(SUM(f.attributed_cpu_time_ms), 0) AS attributed_cpu_time_ms
FROM core.fact_table_usage_daily f
JOIN core.dim_table t
    ON f.table_id = t.table_id
WHERE t.table_fqn = 'analytics.mart.ide_usage_daily'
  AND f.date_id BETWEEN 20260102 AND 20260105
GROUP BY t.table_fqn;

-- =============================================================================
-- Q1b — Daily trend for table X (historical perspective / dashboard)
--       Note: SUM(distinct_users) across days is NOT period-distinct.
-- =============================================================================
SELECT
    m.date_id,
    m.table_fqn,
    m.distinct_users,
    m.query_count,
    m.failed_query_count,
    ROUND(m.attributed_bytes_scanned, 0) AS attributed_bytes_scanned,
    ROUND(m.attributed_cpu_time_ms, 0) AS attributed_cpu_time_ms
FROM mart.table_usage_daily m
WHERE m.table_fqn = 'analytics.mart.ide_usage_daily'
  AND m.date_id BETWEEN 20260102 AND 20260105
ORDER BY m.date_id;

-- =============================================================================
-- Q2a — Resources consumed by team Y over the period
--       Uses query-level metrics (no multi-table double counting).
-- =============================================================================
SELECT
    r.team_id,
    r.team_name,
    SUM(r.query_count) AS query_count,
    SUM(r.failed_query_count) AS failed_query_count,
    SUM(r.cpu_time_ms) AS cpu_time_ms,
    SUM(r.wall_time_ms) AS wall_time_ms,
    SUM(r.bytes_scanned) AS bytes_scanned,
    MAX(r.peak_memory_bytes_max) AS peak_memory_bytes_max,
    -- period-distinct users/tables need the fact grain (see Q2c)
    SUM(r.distinct_users) AS distinct_users_sum_of_daily
FROM mart.team_resource_daily r
WHERE r.team_id = 'team_analytics'
  AND r.date_id BETWEEN 20260102 AND 20260105
GROUP BY r.team_id, r.team_name;

-- =============================================================================
-- Q2b — Daily resource trend for team Y
-- =============================================================================
SELECT
    r.date_id,
    r.team_id,
    r.team_name,
    r.query_count,
    r.cpu_time_ms,
    r.bytes_scanned,
    r.wall_time_ms,
    r.peak_memory_bytes_max,
    r.distinct_users,
    r.distinct_tables
FROM mart.team_resource_daily r
WHERE r.team_id = 'team_analytics'
  AND r.date_id BETWEEN 20260102 AND 20260105
ORDER BY r.date_id;

-- =============================================================================
-- Q2c — Exact period-distinct users / tables for team Y
-- =============================================================================
SELECT
    q.team_id,
    COUNT(DISTINCT q.user_id) AS distinct_users,
    COUNT(DISTINCT b.table_id) AS distinct_tables,
    COUNT(*) AS query_count,
    SUM(q.cpu_time_ms) AS cpu_time_ms,
    SUM(q.bytes_scanned) AS bytes_scanned
FROM core.fact_query q
LEFT JOIN core.bridge_query_table b
    ON q.query_id = b.query_id
WHERE q.team_id = 'team_analytics'
  AND q.date_id BETWEEN 20260102 AND 20260105
GROUP BY q.team_id;

-- =============================================================================
-- Bonus — Who drove usage of table X? (useful for ownership / AI discovery)
-- =============================================================================
SELECT
    t.table_fqn,
    f.user_id,
    f.team_id,
    SUM(f.query_count) AS query_count,
    ROUND(SUM(f.attributed_bytes_scanned), 0) AS attributed_bytes_scanned
FROM core.fact_table_usage_daily f
JOIN core.dim_table t
    ON f.table_id = t.table_id
WHERE t.table_fqn = 'analytics.mart.ide_usage_daily'
  AND f.date_id BETWEEN 20260102 AND 20260105
GROUP BY t.table_fqn, f.user_id, f.team_id
ORDER BY attributed_bytes_scanned DESC, query_count DESC;
