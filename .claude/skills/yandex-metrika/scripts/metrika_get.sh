#!/usr/bin/env bash
# Escape hatch for arbitrary Metrika API calls (drilldown, custom dimensions,
# bytime, etc.). Pass the API path and raw key=value params; isRobot/accuracy
# are NOT added automatically here — you control everything.
#
# Usage:
#   bash scripts/metrika_get.sh /stat/v1/data \
#     "id=32273834" "metrics=ym:s:visits" "dimensions=ym:s:startURL" \
#     "date1=2026-04-08" "date2=2026-05-07" "filters=ym:s:isRobot=='No'" \
#     [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token

[[ $# -ge 1 ]] || ym_die "Usage: metrika_get.sh <api_path> [key=value ...] [--csv path]"
PATH_ARG="$1"; shift

CSV_OUT=""; PARAMS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv) CSV_OUT="$2"; shift 2 ;;
    *)     PARAMS+=( "$1" ); shift ;;
  esac
done

tmp="$(mktemp)"
ym_get "$API_BASE$PATH_ARG" "$tmp" "${PARAMS[@]}"
[[ -n "$CSV_OUT" ]] && { ym_tsv_to_csv "$tmp" "$CSV_OUT"; echo "csv: $CSV_OUT" >&2; }
ym_emit "$tmp" "metrika_get"
rm -f "$tmp"
