#!/usr/bin/env bash
# List all Metrika counters available to the token. Caches counters.json and a
# id<TAB>name<TAB>site TSV for fast grep. --search greps that TSV.
#
# Usage:
#   bash scripts/counters.sh
#   bash scripts/counters.sh --search "metallik"
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token

SEARCH=""; NO_CACHE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --search)   SEARCH="$2"; shift 2 ;;
    --no-cache) NO_CACHE=1; shift ;;
    *) ym_die "Unknown arg: $1" ;;
  esac
done

JSON="$CACHE_DIR/counters.json"
TSV="$CACHE_DIR/counters.tsv"
mkdir -p "$CACHE_DIR"

if [[ "$NO_CACHE" == "1" || ! -s "$JSON" ]]; then
  ym_get "$API_BASE/management/v1/counters" "$JSON" "per_page=1000"
  jq -r '.counters[] | [.id, .name, (.site // "")] | @tsv' "$JSON" > "$TSV"
  echo "cached: $JSON" >&2
else
  echo "cache hit: $JSON" >&2
fi

if [[ -n "$SEARCH" ]]; then
  echo -e "id\tname\tsite"
  grep -i -- "$SEARCH" "$TSV" || echo "(no counter matches '$SEARCH')" >&2
else
  { echo -e "id\tname\tsite"; cat "$TSV"; } > "$TSV.disp"
  ym_emit "$TSV.disp" "counters"
  rm -f "$TSV.disp"
fi
