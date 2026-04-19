# Firebase Analytics -> BigQuery -> Claude Code

End-to-end guide to wire up GA4 export for the Flor2u app and query it from
Claude Code through the BigQuery MCP server.

## 1. Install gcloud

```bash
./scripts/01-install-gcloud.sh
```

Handles macOS (Homebrew) and Debian/Ubuntu. For other systems follow
<https://cloud.google.com/sdk/docs/install>, then re-run the rest.

## 2. Authenticate and pick the project

```bash
./scripts/02-auth-and-discover.sh
```

What the script does:

1. Runs `gcloud auth login` and `gcloud auth application-default login`.
2. Lists all your GCP/Firebase projects. You paste the Flor2u project ID.
3. Enables the `bigquery.googleapis.com` and `firebase.googleapis.com` APIs.
4. Lists BigQuery datasets and searches for one matching `analytics_<number>`
   (this is the dataset the GA4 export creates). If found, it writes the
   project ID and dataset name into `.bq_project` / `.bq_dataset` so the
   following scripts pick them up automatically.

## 3. Enable the GA4 -> BigQuery export (if it was not already)

If step 2 reported "GA4 -> BigQuery export is NOT enabled":

1. Open <https://console.firebase.google.com/> and pick the Flor2u project.
2. Gear icon -> **Project settings** -> **Integrations** tab -> **BigQuery** -> **Link**.
3. Choose the GA4 property used by the iOS and Android apps.
4. Pick a region (use **EU** for EU-hosted data; if unsure, choose the same
   region your other BigQuery workloads already use — this field is
   immutable).
5. Enable both toggles:
   - **Daily** — daily `events_YYYYMMDD` table, complete ~24h after the day ends.
   - **Streaming** — near real-time `events_intraday_YYYYMMDD` table.
6. Click **Link**.

The first `events_*` table lands within 24 hours. `events_intraday_*` starts
populating within minutes. Re-run `./scripts/02-auth-and-discover.sh`
afterwards to cache the dataset name.

## 4. Create the service account and download a key

```bash
./scripts/03-create-service-account.sh
```

Creates `flor2u-bq-reader@<project>.iam.gserviceaccount.com` with roles:

- `roles/bigquery.dataViewer` — read table data and metadata.
- `roles/bigquery.jobUser`    — run queries (required even for read-only).

The key is written to `.secrets/flor2u-bq-reader.json` (git-ignored, chmod 600).

## 5. Configure environment

```bash
cp .env.example .env
```

Fill in:

- `BIGQUERY_PROJECT`  — Flor2u GCP project ID.
- `BIGQUERY_DATASET`  — `analytics_<property_id>`.
- `BIGQUERY_LOCATION` — `EU` or `US`, whichever you picked in step 3.
- `GOOGLE_APPLICATION_CREDENTIALS` — absolute path to the JSON key.

Load it into the shell that will start Claude Code:

```bash
set -a && source .env && set +a
```

## 6. Configure the BigQuery MCP server

`.mcp.json` is already in the repo and reads the four variables above.
It launches [`mcp-server-bigquery`](https://pypi.org/project/mcp-server-bigquery/)
through `uvx` (no install step required — `uvx` fetches and runs it).

Install `uv` if you do not have it:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then, inside the Flor2u repo:

```bash
claude
```

Claude Code picks up `.mcp.json`, starts the BigQuery server, and the tools
`bigquery__list_tables`, `bigquery__describe_table`, `bigquery__execute_query`
become available in the session.

## 7. Smoke-test

```bash
./scripts/04-verify-bigquery.sh
```

Lists GA4 tables and groups today's events by name.

Inside Claude Code you can ask things like:

- "List all tables in the BigQuery dataset."
- "Run `sql/05_today_events.sql` — show live event counts for today."
- "Run `sql/01_purchase_funnel.sql` for the last 30 days."

## Troubleshooting

**`bq ls` returns empty.** The export was just linked; GA4 needs up to 24h
for the first `events_*` table. `events_intraday_*` appears within minutes
but only while the app sends events.

**`Access Denied: BigQuery BigQuery: Permission denied` in Claude Code.**
Re-check that `GOOGLE_APPLICATION_CREDENTIALS` points at the JSON key and
that the service account has both roles from step 4.

**Dataset location mismatch.** `bq` and MCP must use the same region as the
dataset. If queries fail with "Not found: Dataset ... in location X", update
`BIGQUERY_LOCATION` in `.env`.

**Intraday table missing.** Streaming export is a separate toggle in the
Firebase integration — confirm it is on.
