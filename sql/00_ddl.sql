-- Part 2: Meta DWH DDL (DuckDB)
-- Creates empty schemas/tables aligned with docs/01_design.md

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS meta;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

-- ---------------------------------------------------------------------------
-- Sources (loaded from sample_data in 00_load_sources.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS raw.trino_query_history (
    query_id            VARCHAR NOT NULL,
    user_id             VARCHAR NOT NULL,
    query_state         VARCHAR NOT NULL,
    query_source        VARCHAR,
    started_at          TIMESTAMP NOT NULL,
    ended_at            TIMESTAMP NOT NULL,
    cpu_time_ms         BIGINT NOT NULL,
    wall_time_ms        BIGINT NOT NULL,
    bytes_scanned       BIGINT NOT NULL,
    peak_memory_bytes   BIGINT NOT NULL,
    output_rows         BIGINT NOT NULL,
    output_bytes        BIGINT NOT NULL,
    PRIMARY KEY (query_id)
);

CREATE TABLE IF NOT EXISTS raw.trino_query_accessed_tables (
    query_id            VARCHAR NOT NULL,
    catalog_name        VARCHAR NOT NULL,
    schema_name         VARCHAR NOT NULL,
    table_name          VARCHAR NOT NULL,
    access_type         VARCHAR NOT NULL,
    PRIMARY KEY (query_id, catalog_name, schema_name, table_name)
);

CREATE TABLE IF NOT EXISTS meta.user_team_scd (
    user_id             VARCHAR NOT NULL,
    team_id             VARCHAR NOT NULL,
    team_name           VARCHAR NOT NULL,
    valid_from          TIMESTAMP NOT NULL,
    valid_to            TIMESTAMP,          -- NULL = currently valid
    is_current          BOOLEAN NOT NULL,
    PRIMARY KEY (user_id, valid_from)
);

CREATE TABLE IF NOT EXISTS meta.table_catalog (
    table_fqn           VARCHAR NOT NULL,
    layer               VARCHAR,
    owner_team_id       VARCHAR,
    description         VARCHAR,
    is_iceberg          BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (table_fqn)
);

-- ---------------------------------------------------------------------------
-- Staging
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stg.trino_query (
    query_id            VARCHAR NOT NULL,
    user_id             VARCHAR NOT NULL,
    team_id             VARCHAR NOT NULL,
    query_state         VARCHAR NOT NULL,
    query_source        VARCHAR,
    started_at          TIMESTAMP NOT NULL,
    ended_at            TIMESTAMP NOT NULL,
    date_id             INTEGER NOT NULL,
    cpu_time_ms         BIGINT NOT NULL,
    wall_time_ms        BIGINT NOT NULL,
    bytes_scanned       BIGINT NOT NULL,
    peak_memory_bytes   BIGINT NOT NULL,
    output_rows         BIGINT NOT NULL,
    output_bytes        BIGINT NOT NULL,
    is_failed           BOOLEAN NOT NULL,
    table_count         INTEGER NOT NULL,
    PRIMARY KEY (query_id)
);

CREATE TABLE IF NOT EXISTS stg.trino_query_table (
    query_id            VARCHAR NOT NULL,
    table_fqn           VARCHAR NOT NULL,
    catalog_name        VARCHAR NOT NULL,
    schema_name         VARCHAR NOT NULL,
    table_name          VARCHAR NOT NULL,
    access_type         VARCHAR NOT NULL,
    attribution_weight  DOUBLE NOT NULL,
    attribution_method  VARCHAR NOT NULL,
    PRIMARY KEY (query_id, table_fqn)
);

-- ---------------------------------------------------------------------------
-- Core dimensions
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.dim_date (
    date_id             INTEGER NOT NULL,
    date                DATE NOT NULL,
    year                INTEGER NOT NULL,
    month               INTEGER NOT NULL,
    iso_week            INTEGER NOT NULL,
    day_name            VARCHAR NOT NULL,
    PRIMARY KEY (date_id)
);

CREATE TABLE IF NOT EXISTS core.dim_user (
    user_id             VARCHAR NOT NULL,
    user_email          VARCHAR,
    user_type           VARCHAR NOT NULL,  -- human | service
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS core.dim_team (
    team_id             VARCHAR NOT NULL,
    team_name           VARCHAR NOT NULL,
    cost_center         VARCHAR,
    PRIMARY KEY (team_id)
);

CREATE TABLE IF NOT EXISTS core.dim_table (
    table_id            VARCHAR NOT NULL,  -- stable hash/fqn key
    table_fqn           VARCHAR NOT NULL,
    catalog_name        VARCHAR NOT NULL,
    schema_name         VARCHAR NOT NULL,
    table_name          VARCHAR NOT NULL,
    layer               VARCHAR,
    owner_team_id       VARCHAR,
    description         VARCHAR,
    is_iceberg          BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (table_id)
);

-- ---------------------------------------------------------------------------
-- Core facts / bridges
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS core.fact_query (
    query_id            VARCHAR NOT NULL,
    user_id             VARCHAR NOT NULL,
    team_id             VARCHAR NOT NULL,
    date_id             INTEGER NOT NULL,
    query_state         VARCHAR NOT NULL,
    query_source        VARCHAR,
    started_at          TIMESTAMP NOT NULL,
    ended_at            TIMESTAMP NOT NULL,
    cpu_time_ms         BIGINT NOT NULL,
    wall_time_ms        BIGINT NOT NULL,
    bytes_scanned       BIGINT NOT NULL,
    peak_memory_bytes   BIGINT NOT NULL,
    output_rows         BIGINT NOT NULL,
    output_bytes        BIGINT NOT NULL,
    table_count         INTEGER NOT NULL,
    is_failed           BOOLEAN NOT NULL,
    PRIMARY KEY (query_id)
);

CREATE TABLE IF NOT EXISTS core.bridge_query_table (
    query_id                        VARCHAR NOT NULL,
    table_id                        VARCHAR NOT NULL,
    access_type                     VARCHAR NOT NULL,
    attribution_weight              DOUBLE NOT NULL,
    attribution_method              VARCHAR NOT NULL,
    attributed_cpu_time_ms          DOUBLE NOT NULL,
    attributed_bytes_scanned        DOUBLE NOT NULL,
    attributed_peak_memory_bytes    DOUBLE NOT NULL,
    PRIMARY KEY (query_id, table_id)
);

CREATE TABLE IF NOT EXISTS core.fact_table_usage_daily (
    date_id                         INTEGER NOT NULL,
    table_id                        VARCHAR NOT NULL,
    user_id                         VARCHAR NOT NULL,
    team_id                         VARCHAR NOT NULL,
    query_count                     BIGINT NOT NULL,
    failed_query_count              BIGINT NOT NULL,
    attributed_cpu_time_ms          DOUBLE NOT NULL,
    attributed_bytes_scanned        DOUBLE NOT NULL,
    attributed_peak_memory_bytes    DOUBLE NOT NULL,
    PRIMARY KEY (date_id, table_id, user_id, team_id)
);

-- ---------------------------------------------------------------------------
-- Marts
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mart.table_usage_daily (
    date_id                         INTEGER NOT NULL,
    table_id                        VARCHAR NOT NULL,
    table_fqn                       VARCHAR NOT NULL,
    distinct_users                  BIGINT NOT NULL,
    query_count                     BIGINT NOT NULL,
    failed_query_count              BIGINT NOT NULL,
    attributed_cpu_time_ms          DOUBLE NOT NULL,
    attributed_bytes_scanned        DOUBLE NOT NULL,
    PRIMARY KEY (date_id, table_id)
);

CREATE TABLE IF NOT EXISTS mart.team_resource_daily (
    date_id                         INTEGER NOT NULL,
    team_id                         VARCHAR NOT NULL,
    team_name                       VARCHAR NOT NULL,
    query_count                     BIGINT NOT NULL,
    failed_query_count              BIGINT NOT NULL,
    cpu_time_ms                     BIGINT NOT NULL,
    wall_time_ms                    BIGINT NOT NULL,
    bytes_scanned                   BIGINT NOT NULL,
    peak_memory_bytes_max           BIGINT NOT NULL,
    distinct_users                  BIGINT NOT NULL,
    distinct_tables                 BIGINT NOT NULL,
    PRIMARY KEY (date_id, team_id)
);

-- ETL control (used from Part 3+)
CREATE TABLE IF NOT EXISTS meta.etl_watermark (
    pipeline_name       VARCHAR NOT NULL,
    watermark_ts        TIMESTAMP NOT NULL,
    updated_at          TIMESTAMP NOT NULL,
    PRIMARY KEY (pipeline_name)
);
