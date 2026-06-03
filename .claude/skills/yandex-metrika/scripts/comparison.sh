#!/usr/bin/env bash
# Compare two periods via /stat/v1/data/comparison. Returns the chosen metrics
# for period A, period B and their relative change, optionally split by one
# dimension.
#
# Usage:
#   bash scripts/comparison.sh --counter <ID> \
#     --date1a 2026-03-01 --date2a 2026-03-31 \
#     --date1b 2026-04-01 --date2b 2026-04-30 \
#     [--dimension ym:s:trafficSource] \
#     [--metrics ym:s:visits,ym:s:users] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter

D1A=""; D2A=""; D1B=""; D2B=""; DIMENSION=""; METRICS="ym:s:visits,ym:s:users,ym:s:bounceRate"
i=0; rest=( "${YM_REST[@]:-}" )
while [[ $i -lt ${#rest[@]} ]]; do
  case "${rest[$i]}" in
    --date1a)    D1A="${rest[$((i+1))]}"; i=$((i+2)) ;;
    --date2a)    D2A="${rest[$((i+1))]}"; i=$((i+2)) ;;
    --date1b)    D1B="${rest[$((i+1))]}"; i=$((i+2)) ;;
    --date2b)    D2B="${rest[$((i+1))]}"; i=$((i+2)) ;;
    --dimension) DIMENSION="${rest[$((i+1))]}"; i=$((i+2)) ;;
    --metrics)   METRICS="${rest[$((i+1))]}"; i=$((i+2)) ;;
    "")          i=$((i+1)) ;;
    *) ym_die "Unknown arg: ${rest[$i]}" ;;
  esac
done
[[ -n "$D1A" && -n "$D2A" && -n "$D1B" && -n "$D2B" ]] \
  || ym_die "Need --date1a --date2a --date1b --date2b"

robot="ym:s:isRobot=='No'"
filters="$robot"; [[ -n "${EXTRA_FILTERS:-}" ]] && filters="(${EXTRA_FILTERS}) AND $robot"

sig="id=$COUNTER|cmp|m=$METRICS|d=$DIMENSION|f=$filters|a=$ATTRIBUTION|A=$D1A:$D2A|B=$D1B:$D2B"
OUT="$(ym_report_path "$COUNTER" "comparison" "$sig").tsv"

today="$(date -u +%F)"; cacheable=1
{ [[ "$D2A" == "$today" || "$D2A" > "$today" ]] || [[ "$D2B" == "$today" || "$D2B" > "$today" ]]; } && cacheable=0

if [[ $cacheable -eq 1 && "${NO_CACHE:-0}" != "1" && -s "$OUT" ]]; then
  echo "cache hit: $OUT" >&2
else
  params=(
    "id=$COUNTER" "metrics=$METRICS" "filters=$filters" "accuracy=1"
    "attribution=$ATTRIBUTION"
    "date1_a=$D1A" "date2_a=$D2A" "date1_b=$D1B" "date2_b=$D2B"
  )
  [[ -n "$DIMENSION" ]] && params+=( "dimensions=$DIMENSION" )
  [[ -n "${LIMIT:-}" ]] && params+=( "limit=$LIMIT" )
  tmp="$(mktemp)"
  ym_get "$API_BASE/stat/v1/data/comparison" "$tmp" "${params[@]}"
  if [[ $cacheable -eq 1 ]]; then mkdir -p "$(dirname "$OUT")"; mv "$tmp" "$OUT";
    echo "cached: $OUT" >&2; else OUT="$tmp"; echo "not cached (includes today)" >&2; fi
fi

[[ -n "${CSV_OUT:-}" ]] && { ym_tsv_to_csv "$OUT" "$CSV_OUT"; echo "csv: $CSV_OUT" >&2; }
ym_emit "$OUT" "comparison"
