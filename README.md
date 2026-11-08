# Meta DWH — Trino / Iceberg table usage

Take-home solution for tracking **how analytical Iceberg tables are used** on a Trino cluster: who queries them, which teams consume cluster resources, and how that changes over time.

## Quick start

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt

python python/run_pipeline.py    # DDL + sample load + transforms
python python/run_examples.py    # answers the brief's Q1 / Q2
```

Local engine is **DuckDB** so the project runs without a Trino cluster. SQL is plain enough to port to Trino later.

## What this answers

| Question | Where |
|----------|--------|
| Distinct users of table X in a period | `sql/05_example_queries.sql` → Q1a (exact), Q1b (daily trend) |
| Resources consumed by team Y in a period | Q2a / Q2b (mart), Q2c (period-exact distincts) |

Demo parameters in the example SQL:

- table X = `analytics.mart.ide_usage_daily`
- team Y = `team_analytics`
- period = `2026-01-02` … `2026-01-05`

## Architecture

```text
Trino query history + accessed tables + org SCD + table catalog
        ↓
   staging (normalize, team as-of, equal-split weights)
        ↓
   core dims / fact_query / bridge_query_table / daily fact
        ↓
   marts: table_usage_daily, team_resource_daily
```

### Tables (grain)

| Table | Grain | Role |
|-------|-------|------|
| `core.fact_query` | 1 row = 1 query | Source of truth for **team** resource use |
| `core.bridge_query_table` | 1 row = (query, table) | Table access + `1/N` cost attribution |
| `core.fact_table_usage_daily` | date × table × user × team | Flexible slice for exact period distincts |
| `mart.table_usage_daily` | date × table | Popularity + attributed resources |
| `mart.team_resource_daily` | date × team | Team cost (**unsplit** query metrics) |

Full assumptions, ER, metrics, and update/backfill strategy: [`docs/01_design.md`](docs/01_design.md).

## Design choices (short)

1. **Team cost from `fact_query`** — multi-table queries must not double-count CPU/bytes when reporting team Y.
2. **Table cost via equal split `1/N`** — default until per-table scan metrics exist; method stored as `attribution_method`.
3. **User → team as-of `started_at`** — SCD2 mapping; transfers do not rewrite history (see user `dave` in sample data).
4. **Daily marts + detailed facts** — trends from marts; exact period-distinct users from `fact_table_usage_daily`.
5. **Resource proxies** — `cpu_time_ms`, `wall_time_ms`, `bytes_scanned`, `peak_memory_bytes` (Trino stats, not cloud invoice $).

## Repository layout

```text
sample_data/          mock Trino history, accessed tables, org SCD, table catalog
sql/00_ddl.sql        schemas and empty tables
sql/01_staging.sql … 04_marts.sql
sql/05_example_queries.sql
python/init_db.py     create DB + load CSV sources
python/transform.py   run transforms
python/run_pipeline.py
python/run_examples.py
docs/01_design.md     detailed design (assumptions, model, updates)
```

## How data would be updated (production sketch)

- Daily (or hourly) incremental load of terminal Trino events.
- Reprocess a **2-day lookback** for late arrivals; `MERGE` on `query_id`.
- Rebuild daily partitions for touched `date_id`s (idempotent overwrite).
- Logic change (e.g. better attribution) → replay staging→marts over a date range from immutable raw events.

## Production follow-ups

- Prefer Trino event listener / analyzer relations over SQL parsing.
- Replace equal split with Iceberg / plan-level per-table bytes when available.
- Wire orchestration (Airflow/etc.) and DQ tests (`sum(weight)≈1`, orphan keys).
- Publish `dim_table` + usage marts as metadata for AI agents (what exists and what is actually used).
