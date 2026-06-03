#!/usr/bin/env bash
# Organic traffic by search engine. Forces trafficSource=='organic'.
#
# Usage:
#   bash scripts/search_engines.sh --counter <ID> --date1 2026-04-08 \
#     [--date2 ...] [--limit 50] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

# Force organic regardless of --source.
ym_add_filter "ym:s:trafficSource=='organic'"

METRICS="ym:s:visits,ym:s:users,ym:s:bounceRate,ym:s:pageDepth"
DIMS="ym:s:searchEngine"

ym_stat "search_engines" "$METRICS" "$DIMS" "-ym:s:visits"
