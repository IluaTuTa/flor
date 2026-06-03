#!/usr/bin/env bash
# Shared helpers for the yandex-metrika skill scripts.
#
# Sourced by every scripts/*.sh. Provides: env/token loading, the cache layer,
# the Metrika API callers (stat + management) with isRobot/accuracy/attribution
# defaults and 429 handling, common argument parsing, and the 30-line stdout
# emitter described in the skill's "context window hygiene" philosophy.
set -euo pipefail

# ---- paths -----------------------------------------------------------------
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$LIB_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
CACHE_DIR="${YM_CACHE_DIR:-$SKILL_DIR/cache}"
API_BASE="https://api-metrika.yandex.net"
STDOUT_LINES=30

# ---- env / token -----------------------------------------------------------
# Token resolution order: process env -> skill config/.env -> repo-root .env.
ym_load_env() {
  if [[ -z "${YANDEX_METRIKA_TOKEN:-}" ]]; then
    for f in "$SKILL_DIR/config/.env" "$REPO_ROOT/.env"; do
      if [[ -f "$f" ]]; then set -a; source "$f"; set +a; fi
      [[ -n "${YANDEX_METRIKA_TOKEN:-}" ]] && break
    done
  fi
}

ym_require_token() {
  ym_load_env
  if [[ -z "${YANDEX_METRIKA_TOKEN:-}" ]]; then
    echo "YANDEX_METRIKA_TOKEN not set. See config/README.md to obtain one," >&2
    echo "then put it in config/.env or the repo-root .env." >&2
    exit 1
  fi
}

# ---- small utils -----------------------------------------------------------
ym_sha1() { printf '%s' "$1" | sha1sum | cut -c1-12; }
ym_die()  { echo "$*" >&2; exit 1; }

# Print at most STDOUT_LINES lines of a file, then a pointer to the full data.
# $1 = file, $2 = human label (optional)
ym_emit() {
  local file="$1" label="${2:-}"
  local total; total="$(wc -l < "$file" | tr -d ' ')"
  head -n "$STDOUT_LINES" "$file"
  if (( total > STDOUT_LINES )); then
    echo "... ($((total - STDOUT_LINES)) more rows)"
  fi
  [[ -n "$label" ]] && echo "[$label] $total rows -> $file" >&2
}

# ---- cache -----------------------------------------------------------------
ym_counter_dir() { echo "$CACHE_DIR/counter_$1"; }

# Report cache path for a given counter + params signature.
# $1 = counter id, $2 = report name, $3 = signature string
ym_report_path() {
  local cid="$1" name="$2" sig="$3"
  local dir; dir="$(ym_counter_dir "$cid")/reports"
  mkdir -p "$dir"
  echo "$dir/${name}_$(ym_sha1 "$sig").csv"
}

# ---- HTTP core -------------------------------------------------------------
# Low-level GET. Honours 429 Retry-After (<=60s -> wait+retry, else fail).
# Args: out_file then curl --data-urlencode style "key=value" pairs after URL.
# Usage: ym_get <url> <out_file> [ "k=v" ... ]
ym_get() {
  local url="$1" out="$2"; shift 2
  local data_args=() p
  for p in "$@"; do data_args+=( --data-urlencode "$p" ); done

  # Download to a temp file; only promote to $out on HTTP 200 so a failed call
  # (e.g. 403/5xx) never leaves an error body where a valid cache is expected.
  local attempt=0 max_attempts=3 hdr body code retry
  hdr="$(mktemp)"; body="$(mktemp)"
  while :; do
    attempt=$((attempt + 1))
    code="$(curl -sS -G -D "$hdr" -o "$body" -w '%{http_code}' \
      -H "Authorization: OAuth $YANDEX_METRIKA_TOKEN" \
      -H "Accept: application/x-yandex-tabular-stream-values" \
      "${data_args[@]}" "$url" || true)"

    local remaining
    remaining="$(awk 'tolower($1)=="x-ratelimit-remaining:"{print $2}' "$hdr" | tr -d '\r')"
    [[ -n "$remaining" ]] && echo "rate-limit remaining: $remaining" >&2

    if [[ "$code" == "429" && $attempt -lt $max_attempts ]]; then
      retry="$(awk 'tolower($1)=="retry-after:"{print $2}' "$hdr" | tr -d '\r')"
      retry="${retry:-30}"
      if (( retry <= 60 )); then
        echo "HTTP 429, retrying in ${retry}s (attempt $attempt/$max_attempts)" >&2
        sleep "$retry"; continue
      fi
      rm -f "$hdr" "$body"
      ym_die "HTTP 429 with Retry-After=${retry}s (>60s). Wait and re-run."
    fi
    break
  done
  rm -f "$hdr"

  if [[ "$code" != "200" ]]; then
    echo "HTTP $code from $url" >&2
    head -c 800 "$body" >&2; echo >&2
    rm -f "$body"
    exit 1
  fi
  mv "$body" "$out"
}

# Management API GET -> JSON file (cached as permanent unless --no-cache).
# Usage: ym_mgmt <path> <cache_file>
ym_mgmt() {
  local path="$1" cache_file="$2"
  if [[ "${NO_CACHE:-0}" != "1" && -s "$cache_file" ]]; then
    echo "cache hit: $cache_file" >&2
    return 0
  fi
  mkdir -p "$(dirname "$cache_file")"
  ym_get "$API_BASE$path" "$cache_file"
  echo "cached: $cache_file" >&2
}

# Stat API GET -> TSV (tabular stream). Always adds isRobot=='No', accuracy=1
# and the chosen attribution. Caches by signature unless date2 is today or
# --no-cache is set. Writes TSV to $REPORT_TSV and (optionally) CSV to --csv.
#
# Globals consumed: COUNTER DATE1 DATE2 ATTRIBUTION LIMIT NO_CACHE EXTRA_FILTERS
# Args: report_name metrics dimensions [sort]
ym_stat() {
  local name="$1" metrics="$2" dimensions="${3:-}" sort="${4:-}"

  local robot="ym:s:isRobot=='No'"
  local filters="$robot"
  [[ -n "${EXTRA_FILTERS:-}" ]] && filters="(${EXTRA_FILTERS}) AND $robot"

  local sig="id=$COUNTER|m=$metrics|d=$dimensions|f=$filters|s=$sort|l=${LIMIT:-}|a=$ATTRIBUTION|d1=$DATE1|d2=$DATE2"
  REPORT_TSV="$(ym_report_path "$COUNTER" "$name" "$sig").tsv"

  local today cacheable=1
  today="$(date -u +%F)"
  [[ "$DATE2" == "$today" || "$DATE2" > "$today" ]] && cacheable=0

  if [[ $cacheable -eq 1 && "${NO_CACHE:-0}" != "1" && -s "$REPORT_TSV" ]]; then
    echo "cache hit: $REPORT_TSV" >&2
  else
    local params=(
      "id=$COUNTER" "metrics=$metrics" "date1=$DATE1" "date2=$DATE2"
      "filters=$filters" "accuracy=1" "attribution=$ATTRIBUTION"
    )
    [[ -n "$dimensions" ]] && params+=( "dimensions=$dimensions" )
    [[ -n "$sort" ]]       && params+=( "sort=$sort" )
    [[ -n "${LIMIT:-}" ]]  && params+=( "limit=$LIMIT" )
    [[ -n "${GROUP:-}" ]]  && params+=( "group=$GROUP" )

    local tmp; tmp="$(mktemp)"
    ym_get "$API_BASE/stat/v1/data" "$tmp" "${params[@]}"
    if [[ $cacheable -eq 1 ]]; then
      mkdir -p "$(dirname "$REPORT_TSV")"; mv "$tmp" "$REPORT_TSV"
      echo "cached: $REPORT_TSV" >&2
    else
      REPORT_TSV="$tmp"
      echo "not cached (date2=$DATE2 includes today)" >&2
    fi
  fi

  if [[ -n "${CSV_OUT:-}" ]]; then
    ym_tsv_to_csv "$REPORT_TSV" "$CSV_OUT"
    echo "csv: $CSV_OUT" >&2
  fi
  ym_emit "$REPORT_TSV" "$name"
}

# Convert a tab-separated stream to RFC-4180 CSV.
ym_tsv_to_csv() {
  local in="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  python3 - "$in" "$out" <<'PY'
import csv, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f, open(dst, "w", newline="", encoding="utf-8") as g:
    w = csv.writer(g)
    for line in f:
        w.writerow(line.rstrip("\n").split("\t"))
PY
}

# ---- common arg parsing ----------------------------------------------------
# Sets: COUNTER DATE1 DATE2 GROUP DEVICE SOURCE ATTRIBUTION LIMIT CSV_OUT
#       NO_CACHE EXTRA_FILTERS  and leaves unknown args in YM_REST[].
ym_parse_common() {
  COUNTER=""; DATE1=""; DATE2="$(date -u +%F)"; GROUP=""; DEVICE="all"
  SOURCE="all"; ATTRIBUTION="lastsign"; LIMIT=""; CSV_OUT=""; NO_CACHE=0
  EXTRA_FILTERS=""; YM_REST=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --counter)     COUNTER="$2"; shift 2 ;;
      --date1)       DATE1="$2"; shift 2 ;;
      --date2)       DATE2="$2"; shift 2 ;;
      --group)       GROUP="$2"; shift 2 ;;
      --device)      DEVICE="$2"; shift 2 ;;
      --source)      SOURCE="$2"; shift 2 ;;
      --attribution) ATTRIBUTION="$2"; shift 2 ;;
      --limit)       LIMIT="$2"; shift 2 ;;
      --csv)         CSV_OUT="$2"; shift 2 ;;
      --no-cache)    NO_CACHE=1; shift ;;
      *)             YM_REST+=( "$1" ); shift ;;
    esac
  done

  # device -> filter
  if [[ "$DEVICE" != "all" ]]; then
    ym_add_filter "ym:s:deviceCategory=='$DEVICE'"
  fi
  # source -> trafficSource filter
  if [[ "$SOURCE" != "all" ]]; then
    ym_add_filter "ym:s:trafficSource=='$SOURCE'"
  fi
}

ym_add_filter() {
  if [[ -z "$EXTRA_FILTERS" ]]; then EXTRA_FILTERS="$1"
  else EXTRA_FILTERS="$EXTRA_FILTERS AND $1"; fi
}

ym_require_counter() { [[ -n "${COUNTER:-}" ]] || ym_die "--counter <ID> is required"; }
ym_require_date1()   { [[ -n "${DATE1:-}"   ]] || ym_die "--date1 YYYY-MM-DD is required"; }
