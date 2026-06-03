#!/usr/bin/env bash
# E-commerce: purchases, revenue, average order value. Currency defaults to the
# counter's currency (from counter_info), override with --currency.
#
# Usage:
#   bash scripts/ecommerce.sh --counter <ID> --date1 2026-04-08 \
#     [--date2 ...] [--currency RUB|USD|EUR] [--group month] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

CURRENCY=""
i=0; rest=( "${YM_REST[@]:-}" )
while [[ $i -lt ${#rest[@]} ]]; do
  case "${rest[$i]}" in
    --currency) CURRENCY="${rest[$((i+1))]}"; i=$((i+2)) ;;
    "")         i=$((i+1)) ;;
    *) ym_die "Unknown arg: ${rest[$i]}" ;;
  esac
done

# Auto-detect currency from cached counter info when not given.
if [[ -z "$CURRENCY" ]]; then
  INFO="$(ym_counter_dir "$COUNTER")/info.json"
  [[ -s "$INFO" ]] && CURRENCY="$(jq -r '.counter.currency // empty' "$INFO" 2>/dev/null || true)"
fi
[[ -n "$CURRENCY" ]] && ym_add_filter "ym:s:productCurrency=='$CURRENCY'"

METRICS="ym:s:ecommercePurchases,ym:s:ecommerceRevenue,ym:s:ecommerceRevenuePerPurchase"
DIMS=""
[[ -n "${GROUP:-}" ]] && DIMS="ym:s:date"

ym_stat "ecommerce" "$METRICS" "$DIMS" ""
