#!/usr/bin/env bash
# Traffic broken down by source, with quality metrics.
#
# Usage:
#   bash scripts/traffic_summary.sh --counter <ID> --date1 2026-04-08 \
#     [--date2 2026-05-07] [--group month] [--device mobile] \
#     [--source organic] [--limit 50] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

METRICS="ym:s:visits,ym:s:users,ym:s:pageviews,ym:s:bounceRate,ym:s:pageDepth,ym:s:avgVisitDurationSeconds"
DIMS="ym:s:trafficSource"
[[ -n "${GROUP:-}" ]] && DIMS="ym:s:date,$DIMS"

ym_stat "traffic_summary" "$METRICS" "$DIMS" "-ym:s:visits"
