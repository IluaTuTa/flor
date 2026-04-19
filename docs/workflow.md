# Collaborative analytics workflow

You run SQL locally (or in the BigQuery console), commit the CSV, and we
iterate on metrics together here.

## One-time

```bash
set -a && source .env && set +a
mkdir -p data
```

## Each analysis

```bash
# 1. Export a query result to data/
./scripts/bq-export.sh sql/01_purchase_funnel.sql
./scripts/bq-export.sh sql/05_today_events.sql

# 2. Commit it so Claude Code sees the data
git add data/*.csv
git commit -m "data: purchase funnel snapshot $(date -u +%F)"
git push

# 3. Ask in the chat:
#    "посчитай воронку по data/01_purchase_funnel.csv"
#    "построй график retention для data/02_retention_cohorts.csv"
```

## Ad-hoc queries

You can also paste query results directly into the chat, or drop any CSV
into `data/`. As long as it has the columns the analysis script expects
(see each script's docstring), Claude can run it.

## Directories

| Path       | Purpose                                             | Git |
|------------|-----------------------------------------------------|-----|
| `sql/`     | Parameterised SQL templates                         | tracked |
| `data/`    | CSV exports from BigQuery                           | tracked (small) / ignored if large |
| `analysis/`| Python scripts that read `data/*.csv` -> metrics    | tracked |
| `.secrets/`| Service-account JSON key                            | ignored |
