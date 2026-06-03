#!/usr/bin/env bash
# Counter metadata (name, site, timezone, currency, ...). Cached permanently as
# counter_<id>/info.json.
#
# Usage: bash scripts/counter_info.sh --counter <ID> [--no-cache]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter

DIR="$(ym_counter_dir "$COUNTER")"; mkdir -p "$DIR"
JSON="$DIR/info.json"
ym_mgmt "/management/v1/counter/$COUNTER" "$JSON"

jq -r '.counter | "id\t\(.id)",
  "name\t\(.name)",
  "site\t\(.site // "")",
  "timezone\t\(.time_zone_name // "")",
  "currency\t\(.currency // "")",
  "status\t\(.status // "")"' "$JSON"
