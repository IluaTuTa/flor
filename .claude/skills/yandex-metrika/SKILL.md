---
name: yandex-metrika
description: >-
  Work with the Yandex Metrika Reporting API v1 — traffic, conversions, UTM,
  search engines, e-commerce and Yandex Direct costs. Use when the user asks
  about Metrika counters, site analytics, visits/users/conversions, traffic
  sources, UTM campaigns, or Direct ad spend for a counter.
---

# yandex-metrika

Cache-first wrappers around the Yandex Metrika Reporting API v1. Reports go to
CSV/TSV files; stdout is capped at 30 lines to keep the context window clean.

## Config

Requires `YANDEX_METRIKA_TOKEN`. Resolution order: process env →
`config/.env` → repo-root `.env`. See `config/README.md` to obtain a token.
The repo-root `.env` already carries `YANDEX_METRIKA_TOKEN` and
`YANDEX_METRIKA_COUNTER_ID` for this project.

## Philosophy

- **Cache-first** — config data (counters, goals, info) cached long-term;
  reports cached by `counter + dates + params`. Always check cache before the API.
- **Context hygiene** — stdout ≤ 30 lines; full data in CSV/TSV under `cache/`.
  Search the cache with `grep`/`rg` instead of reloading into context.
- **Accurate data** — `accuracy=1` (no sampling), `isRobot=='No'` by default.
- **Attribution** — default `lastsign`. Ask the user on first run.

## Workflow — STOP, do this before any analysis

1. List counters: `bash scripts/counters.sh`
2. If the counter is not obvious, ask: *"О каком счётчике/сайте идёт речь?
   Укажите ID, название или домен."* Search by domain/name:
   `bash scripts/counters.sh --search "metallik"`
3. Counter info + goals:
   `bash scripts/counter_info.sh --counter <ID>` and
   `bash scripts/goals.sh --counter <ID>`
4. Ask which goals are conversions, then save
   `cache/counter_<id>/config.json`:
   ```json
   {
     "attribution": "lastsign",
     "conversion_goals": [
       {"id": 12345, "name": "Заказ оформлен"},
       {"id": 67890, "name": "Заявка отправлена"}
     ]
   }
   ```
5. Run task-specific reports.

## Scripts

Common call shape:
```
bash scripts/<script>.sh --counter <ID> --date1 YYYY-MM-DD [--date2 ...] \
  [--group month] [--csv path]
```

| Script | Description | Special params |
| --- | --- | --- |
| `counters.sh` | List counters | `--search "query"` |
| `goals.sh` | Counter goals | — |
| `counter_info.sh` | Counter metadata | — |
| `traffic_summary.sh` | Traffic by source | — |
| `conversions.sh` | Goal reaches/rates | `--goals "ID,ID"` / `--all-goals`; default from config.json |
| `utm_report.sh` | UTM breakdown | — |
| `search_engines.sh` | Organic by search engine | — |
| `ecommerce.sh` | Purchases, revenue, AOV | `--currency RUB\|USD\|EUR` (auto from counter_info) |
| `direct_clients.sh` | Direct logins | — |
| `direct_costs.sh` | Direct costs (`ym:ad:*`) | `--direct-client-logins "login"`; no `--group/--device/--source` |
| `comparison.sh` | Compare two periods | `--date1a/--date2a/--date1b/--date2b`, `--dimension`, `--metrics` |
| `metrika_get.sh` | Arbitrary API call (drilldown, bytime, custom) | raw `key=value` params |

### Common report params

| Param | Required | Default | Values |
| --- | --- | --- | --- |
| `--counter` | yes | — | counter ID |
| `--date1` | yes | — | `YYYY-MM-DD` |
| `--date2` | no | today | `YYYY-MM-DD` |
| `--group` | no | — | `day`, `week`, `month` |
| `--device` | no | all | `desktop`, `mobile`, `tablet` |
| `--source` | no | all | `organic`, `ad`, `referral`, `direct`, `social` |
| `--attribution` | no | `lastsign` | `lastsign`, `last`, `first` |
| `--limit` | no | API default | row count |
| `--csv` | no | — | export path |
| `--no-cache` | no | — | skip cache |

Not every script supports every common param — see *Special params*.

## Cache layout (`cache/`)

- `counters.json` + `counters.tsv` — all counters
- `counter_<id>/info.json` — metadata (permanent)
- `counter_<id>/goals.json` + `goals.tsv` — goals
- `counter_<id>/config.json` — attribution + conversion goals
- `counter_<id>/direct_clients.json` + `.tsv` — Direct logins
- `counter_<id>/reports/*.tsv` (+ exported `*.csv`) — report results

Search the cache: `grep "text" cache/counters.tsv` or `rg "text" cache/`.

## API limits

Reporting API ≈ 200 requests / 5 min. On `429` the scripts honour
`Retry-After` (≤ 60s → wait and retry, otherwise fail with a message).

## Bridge mode (sandboxed sessions, e.g. Claude Code on the web)

When `curl https://api-metrika.yandex.net/` returns `403 host_not_allowed`,
the runner sits behind the Anthropic Egress Gateway and direct calls are
blocked. `.claude/settings.json → sandbox.network.allowedDomains` does **not**
open it (that knob is for local bubblewrap, not cloud egress).

Instead, run queries through the GitHub Actions bridge — workflow
`.github/workflows/metrika-query.yml`. The workflow runs the same skill
scripts on a GitHub runner (egress open), then commits the result to the
orphan branch `metrika-cache` at `snapshots/<request_id>.tsv` +
`snapshots/<request_id>.meta.json`.

**Setup (one-time):**

1. Add repo secret `YANDEX_METRIKA_TOKEN` (Settings → Secrets and variables → Actions).
2. Optionally set repo variable `YANDEX_METRIKA_COUNTER_ID` as default.
3. First run creates the `metrika-cache` branch automatically.

**Usage (per query, what Claude does):**

1. Generate `request_id` (e.g. `yyyymmdd-hhmmss-<short_hash>`).
2. Trigger the workflow on the current ref:
   `mcp__github__actions_run_trigger` with
   `method=run_workflow`, `workflow_id=metrika-query.yml`,
   inputs: `{request_id, script, counter, date1, date2, extra_args}`.
   `extra_args` is shell-tokenised (`--dimensions ... --limit ...`).
3. Poll the latest workflow run for that workflow until `status=completed`:
   `mcp__github__actions_list` (`list_workflow_runs`, branch=workflow ref).
4. Read the result:
   `mcp__github__get_file_contents`
   `path=snapshots/<request_id>.tsv`, `ref=metrika-cache`.
   Read `snapshots/<request_id>.meta.json` for `exit_code` and stderr.
5. Parse and render.

Caveat: bridge round-trip is ~20–30 s. For low-latency work, open egress in
the claude.ai environment settings or run Claude Code locally.

## Notes / best-effort mappings

Some dimension/param mappings (`--group` → API `group`, `--source` filter,
`direct_clients` dimension, `ym:ad:*` cost metrics) are best-effort and should
be verified against the live API on first run; adjust the relevant
`scripts/*.sh` if the API rejects a field.
