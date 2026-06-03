#!/usr/bin/env bash
# UTM breakdown (source / medium / campaign) with visits and users.
#
# Usage:
#   bash scripts/utm_report.sh --counter <ID> --date1 2026-04-08 \
#     [--date2 ...] [--limit 100] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

METRICS="ym:s:visits,ym:s:users,ym:s:bounceRate"
DIMS="ym:s:lastsignUTMSource,ym:s:lastsignUTMMedium,ym:s:lastsignUTMCampaign"

ym_stat "utm_report" "$METRICS" "$DIMS" "-ym:s:visits"
