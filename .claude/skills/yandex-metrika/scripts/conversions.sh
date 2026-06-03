#!/usr/bin/env bash
# Goal reaches and conversion rates. Goal selection precedence:
#   --all-goals          -> every goal from goals.json
#   --goals "ID,ID"      -> explicit list
#   (default)            -> conversion_goals from counter_<id>/config.json
#
# Usage:
#   bash scripts/conversions.sh --counter <ID> --date1 2026-04-08 \
#     [--goals "12345,67890"] [--all-goals] [--group month] [--csv path]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
ym_require_token
ym_parse_common "$@"
ym_require_counter; ym_require_date1

GOALS=""; ALL_GOALS=0
i=0; rest=( "${YM_REST[@]:-}" )
while [[ $i -lt ${#rest[@]} ]]; do
  case "${rest[$i]}" in
    --goals)     GOALS="${rest[$((i+1))]}"; i=$((i+2)) ;;
    --all-goals) ALL_GOALS=1; i=$((i+1)) ;;
    "")          i=$((i+1)) ;;
    *) ym_die "Unknown arg: ${rest[$i]}" ;;
  esac
done

DIR="$(ym_counter_dir "$COUNTER")"
CONFIG="$DIR/config.json"

if [[ $ALL_GOALS -eq 1 ]]; then
  [[ -s "$DIR/goals.json" ]] || ym_die "Run goals.sh --counter $COUNTER first."
  GOALS="$(jq -r '[.goals[].id] | join(",")' "$DIR/goals.json")"
elif [[ -z "$GOALS" ]]; then
  [[ -s "$CONFIG" ]] || ym_die "No --goals/--all-goals and no config.json. See SKILL.md workflow."
  GOALS="$(jq -r '[.conversion_goals[].id] | join(",")' "$CONFIG")"
fi
[[ -n "$GOALS" ]] || ym_die "No goals resolved."

# Build metrics: reaches + conversionRate per goal.
METRICS="ym:s:visits"
IFS=',' read -ra GIDS <<< "$GOALS"
for g in "${GIDS[@]}"; do
  g="$(echo "$g" | tr -d ' ')"
  [[ -n "$g" ]] || continue
  METRICS="$METRICS,ym:s:goal${g}reaches,ym:s:goal${g}conversionRate"
done

DIMS=""
[[ -n "${GROUP:-}" ]] && DIMS="ym:s:date"

ym_stat "conversions" "$METRICS" "$DIMS" ""
