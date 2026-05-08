#!/usr/bin/env bash
# Fetch a Yandex Metrika /stat/v1/data report as TSV and cache it under
# cache/metrika/. Re-runs with the same parameters return the cached file
# instead of hitting the API. Periods that include today are never cached.
#
# Usage:
#   ./scripts/metrika-fetch.sh \
#     --metrics ym:s:visits,ym:s:users,ym:s:pageviews \
#     --dimensions ym:s:trafficSource \
#     --date1 2026-04-08 --date2 2026-05-07 \
#     [--filters "ym:s:deviceCategory=='mobile'"] \
#     [--sort -ym:s:visits] [--limit 1000] \
#     [--attribution lastsign] \
#     [--out cache/metrika/custom.tsv] \
#     [--force]
set -euo pipefail

API_BASE="https://api-metrika.yandex.net"
ENDPOINT="/stat/v1/data"
CACHE_DIR="cache/metrika"

metrics=""
dimensions=""
date1=""
date2=""
extra_filters=""
sort=""
limit="1000"
attribution="lastsign"
out=""
force="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metrics)      metrics="$2"; shift 2 ;;
    --dimensions)   dimensions="$2"; shift 2 ;;
    --date1)        date1="$2"; shift 2 ;;
    --date2)        date2="$2"; shift 2 ;;
    --filters)      extra_filters="$2"; shift 2 ;;
    --sort)         sort="$2"; shift 2 ;;
    --limit)        limit="$2"; shift 2 ;;
    --attribution)  attribution="$2"; shift 2 ;;
    --out)          out="$2"; shift 2 ;;
    --force)        force="1"; shift ;;
    -h|--help)      sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${metrics:?--metrics required}"
: "${date1:?--date1 required (YYYY-MM-DD)}"
: "${date2:?--date2 required (YYYY-MM-DD)}"

if [[ -f .env ]]; then set -a; source .env; set +a; fi
: "${YANDEX_METRIKA_TOKEN:?Set YANDEX_METRIKA_TOKEN in env or .env}"
: "${YANDEX_METRIKA_COUNTER_ID:?Set YANDEX_METRIKA_COUNTER_ID in env or .env}"

robot="ym:s:isRobot=='No'"
if [[ -n "$extra_filters" ]]; then
  filters="($extra_filters) AND $robot"
else
  filters="$robot"
fi

today="$(date -u +%F)"
cacheable="1"
if [[ "$date2" == "$today" || "$date2" > "$today" ]]; then
  cacheable="0"
fi

key_input="id=$YANDEX_METRIKA_COUNTER_ID|m=$metrics|d=$dimensions|f=$filters|s=$sort|l=$limit|a=$attribution|d1=$date1|d2=$date2"
key="$(printf '%s' "$key_input" | sha1sum | cut -c1-12)"

if [[ -z "$out" ]]; then
  mkdir -p "$CACHE_DIR"
  slug="${date1}_${date2}_${key}"
  out="$CACHE_DIR/${slug}.tsv"
fi

if [[ "$cacheable" == "1" && "$force" != "1" && -s "$out" ]]; then
  echo "cache hit: $out" >&2
  cat "$out"
  exit 0
fi

tmp="$(mktemp)"
hdr="$(mktemp)"
trap 'rm -f "$tmp" "$hdr"' EXIT

http_code=$(curl -sS -D "$hdr" -o "$tmp" -w "%{http_code}" \
  -H "Authorization: OAuth $YANDEX_METRIKA_TOKEN" \
  -H "Accept: application/x-yandex-tabular-stream-values" \
  --get "$API_BASE$ENDPOINT" \
  --data-urlencode "id=$YANDEX_METRIKA_COUNTER_ID" \
  --data-urlencode "metrics=$metrics" \
  ${dimensions:+--data-urlencode "dimensions=$dimensions"} \
  --data-urlencode "date1=$date1" \
  --data-urlencode "date2=$date2" \
  --data-urlencode "filters=$filters" \
  ${sort:+--data-urlencode "sort=$sort"} \
  --data-urlencode "limit=$limit" \
  --data-urlencode "attribution=$attribution")

remaining=$(awk 'tolower($1)=="x-ratelimit-remaining:"{print $2}' "$hdr" | tr -d '\r')
[[ -n "$remaining" ]] && echo "rate-limit remaining: $remaining" >&2

if [[ "$http_code" != "200" ]]; then
  echo "HTTP $http_code from Metrika API:" >&2
  head -c 1000 "$tmp" >&2; echo >&2
  exit 1
fi

if [[ "$cacheable" == "1" ]]; then
  mv "$tmp" "$out"
  trap 'rm -f "$hdr"' EXIT
  echo "cached: $out" >&2
  cat "$out"
else
  echo "not cached (date2=$date2 includes today)" >&2
  cat "$tmp"
fi
