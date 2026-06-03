#!/usr/bin/env bash
# List goals of a counter. Caches goals.json + id<TAB>name<TAB>type TSV.
#
# Usage: bash scripts/goals.sh --counter <ID> [--no-cache]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter

DIR="$(ym_counter_dir "$COUNTER")"; mkdir -p "$DIR"
JSON="$DIR/goals.json"; TSV="$DIR/goals.tsv"

if [[ "${NO_CACHE:-0}" == "1" || ! -s "$JSON" ]]; then
  ym_get "$API_BASE/management/v1/counter/$COUNTER/goals" "$JSON"
  jq -r '.goals[] | [.id, .name, .type] | @tsv' "$JSON" > "$TSV"
  echo "cached: $JSON" >&2
else
  echo "cache hit: $JSON" >&2
fi

{ echo -e "id\tname\ttype"; cat "$TSV"; } > "$TSV.disp"
ym_emit "$TSV.disp" "goals"
rm -f "$TSV.disp"
