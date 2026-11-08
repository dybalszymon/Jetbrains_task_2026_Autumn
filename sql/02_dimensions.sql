-- Part 3: rebuild core dimensions from staging + metadata

DELETE FROM core.dim_date;
INSERT INTO core.dim_date
SELECT DISTINCT
    q.date_id,
    CAST(q.started_at AS DATE) AS date,
    EXTRACT(year FROM q.started_at)::INTEGER AS year,
    EXTRACT(month FROM q.started_at)::INTEGER AS month,
    EXTRACT(week FROM q.started_at)::INTEGER AS iso_week,
    dayname(CAST(q.started_at AS DATE)) AS day_name
FROM stg.trino_query q;

DELETE FROM core.dim_user;
INSERT INTO core.dim_user
SELECT DISTINCT
    user_id,
    CASE
        WHEN user_id LIKE 'svc-%' THEN user_id || '@service.local'
        ELSE user_id || '@jetbrains.example'
    END AS user_email,
    CASE
        WHEN user_id LIKE 'svc-%' THEN 'service'
        ELSE 'human'
    END AS user_type,
    TRUE AS is_active
FROM stg.trino_query;

DELETE FROM core.dim_team;
INSERT INTO core.dim_team
WITH scd_teams AS (
    SELECT
        team_id,
        arg_max(team_name, valid_from) AS team_name
    FROM meta.user_team_scd
    GROUP BY team_id
),
all_team_ids AS (
    SELECT team_id FROM scd_teams
    UNION
    SELECT DISTINCT team_id FROM stg.trino_query
)
SELECT
    a.team_id,
    COALESCE(s.team_name, CASE WHEN a.team_id = 'unknown' THEN 'Unknown' ELSE a.team_id END) AS team_name,
    NULL AS cost_center
FROM all_team_ids a
LEFT JOIN scd_teams s
    ON a.team_id = s.team_id;

DELETE FROM core.dim_table;
INSERT INTO core.dim_table
SELECT DISTINCT
    t.table_fqn AS table_id,
    t.table_fqn,
    t.catalog_name,
    t.schema_name,
    t.table_name,
    c.layer,
    c.owner_team_id,
    c.description,
    COALESCE(c.is_iceberg, TRUE) AS is_iceberg
FROM stg.trino_query_table t
LEFT JOIN meta.table_catalog c
    ON t.table_fqn = c.table_fqn;
