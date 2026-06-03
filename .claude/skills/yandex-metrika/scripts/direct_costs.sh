#!/usr/bin/env bash
# Yandex Direct ad costs (ym:ad:* scope). This scope needs the explicit list of
# Direct client logins and does NOT support --group/--device/--source or the
# isRobot filter, so it bypasses ym_stat and calls the API directly.
#
# Logins precedence: --direct-client-logins "a,b"  ->  cached direct_clients.tsv
#
# Usage:
#   bash scripts/direct_costs.sh --counter <ID> --date1 2026-04-08 \
#     [--date2 ...] [--direct-client-logins "login1,login2"] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

LOGINS=""
i=0; rest=( "${YM_REST[@]:-}" )
while [[ $i -lt ${#rest[@]} ]]; do
  case "${rest[$i]}" in
    --direct-client-logins) LOGINS="${rest[$((i+1))]}"; i=$((i+2)) ;;
    "")                     i=$((i+1)) ;;
    *) ym_die "Unknown arg: ${rest[$i]}" ;;
  esac
done

if [[ -z "$LOGINS" ]]; then
  TSV="$(ym_counter_dir "$COUNTER")/direct_clients.tsv"
  [[ -s "$TSV" ]] || ym_die "No --direct-client-logins and no cached logins. Run direct_clients.sh first."
  LOGINS="$(paste -sd, "$TSV")"
fi

METRICS="ym:ad:clicks,ym:ad:RUBConvertedAdCost,ym:ad:visits,ym:ad:goalsRUBConvertedAdCost"
DIMS="ym:ad:directClientLogin"

sig="id=$COUNTER|ad|m=$METRICS|d=$DIMS|logins=$LOGINS|d1=$DATE1|d2=$DATE2|a=$ATTRIBUTION"
OUT="$(ym_report_path "$COUNTER" "direct_costs" "$sig").tsv"

today="$(date -u +%F)"; cacheable=1
[[ "$DATE2" == "$today" || "$DATE2" > "$today" ]] && cacheable=0

if [[ $cacheable -eq 1 && "${NO_CACHE:-0}" != "1" && -s "$OUT" ]]; then
  echo "cache hit: $OUT" >&2
else
  tmp="$(mktemp)"
  ym_get "$API_BASE/stat/v1/data" "$tmp" \
    "id=$COUNTER" "metrics=$METRICS" "dimensions=$DIMS" \
    "date1=$DATE1" "date2=$DATE2" \
    "direct_client_logins=$LOGINS" "accuracy=1" "attribution=$ATTRIBUTION"
  if [[ $cacheable -eq 1 ]]; then mkdir -p "$(dirname "$OUT")"; mv "$tmp" "$OUT";
    echo "cached: $OUT" >&2; else OUT="$tmp"; echo "not cached (includes today)" >&2; fi
fi

[[ -n "${CSV_OUT:-}" ]] && { ym_tsv_to_csv "$OUT" "$CSV_OUT"; echo "csv: $CSV_OUT" >&2; }
ym_emit "$OUT" "direct_costs"
