# Flor2u Analytics

Firebase Analytics (GA4) is exported to BigQuery and queried from Claude Code
through an MCP server. This repo contains the setup scripts, SQL templates
for the core product metrics, and the MCP configuration.

Flor2u is a federal flower-delivery service in Russia. 85% of orders come
from the iOS and Android apps (React Native).

## Quick start

```bash
./scripts/01-install-gcloud.sh
./scripts/02-auth-and-discover.sh           # login + list projects + detect dataset
./scripts/03-create-service-account.sh      # creates SA + downloads JSON key
cp .env.example .env                        # fill in the paths it prints
set -a && source .env && set +a
./scripts/04-verify-bigquery.sh             # smoke-test: list tables + today's events
```

Full walk-through: [docs/bigquery-setup.md](docs/bigquery-setup.md).

## Layout

```
scripts/    step-by-step shell scripts (01..04)
sql/        parameterised SQL templates for the core Flor2u metrics
docs/       setup guide
.mcp.json   Claude Code MCP server config for BigQuery
.env.example variables consumed by .mcp.json
```

## Metrics covered by sql/

| File | Metric |
|------|--------|
| `01_purchase_funnel.sql`   | first_open -> view_item -> add_to_cart -> begin_checkout -> purchase, with step-to-step CR |
| `02_retention_cohorts.sql` | Weekly install cohorts, W1/W2/W4/W8 retention |
| `03_revenue_by_city.sql`   | Revenue, orders, AOV by city (Russia only) |
| `04_platform_behavior.sql` | iOS vs Android by app version |
| `05_today_events.sql`      | Live events from `events_intraday_*` (smoke test) |
