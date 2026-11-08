# Part 3 — Transformations

## Pipeline

```text
raw.* + meta.*
    → sql/01_staging.sql      stg.trino_query, stg.trino_query_table
    → sql/02_dimensions.sql   core.dim_*
    → sql/03_facts.sql        core.fact_query, bridge_query_table, fact_table_usage_daily
    → sql/04_marts.sql        mart.table_usage_daily, mart.team_resource_daily
```

## Run

```bash
python python/run_pipeline.py
# or, if DB already loaded:
python python/transform.py
```

## Logic notes

1. **Staging** keeps only `FINISHED` / `FAILED` queries; resolves `team_id` as-of `started_at` from SCD; sets equal-split `attribution_weight = 1/N`.
2. **Dimensions** rebuild from staging + catalog/SCD (demo uses full rebuild; production would MERGE).
3. **Facts** copy query metrics unchanged; bridge multiplies metrics by weight; daily fact aggregates by date×table×user×team.
4. **Marts**  
   - table usage → popularity + attributed resources  
   - team resources → **unsplit** metrics from `fact_query` (no double-count)
