#!/usr/bin/env bash
# Yandex Direct client logins that drove traffic in the period. Caches the
# resulting logins to counter_<id>/direct_clients.json + .tsv for use as input
# to direct_costs.sh.
#
# NOTE: best-effort dimension mapping (ym:s:directClientLogin) — verify against
# the live API on first run and adjust if the API rejects the dimension.
#
# Usage:
#   bash scripts/direct_clients.sh --counter <ID> --date1 2026-04-08 [--date2 ...]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

METRICS="ym:s:visits,ym:s:users"
DIMS="ym:s:directClientLogin"

ym_stat "direct_clients" "$METRICS" "$DIMS" "-ym:s:visits"

# Persist the login column for direct_costs.sh (first column of the TSV).
DIR="$(ym_counter_dir "$COUNTER")"
cut -f1 "$REPORT_TSV" | sed '1d' | sort -u > "$DIR/direct_clients.tsv" || true
jq -n --rawfile t "$DIR/direct_clients.tsv" \
  '{logins: ($t | split("\n") | map(select(length>0)))}' \
  > "$DIR/direct_clients.json" 2>/dev/null || true
echo "logins -> $DIR/direct_clients.tsv" >&2
