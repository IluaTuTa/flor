#!/usr/bin/env bash
# Step 7. Smoke-test: list GA4 tables and count today's events.
set -euo pipefail

PROJECT_ID="${1:-$(cat .bq_project 2>/dev/null || true)}"
DATASET="${2:-$(cat .bq_dataset 2>/dev/null || true)}"

if [[ -z "${PROJECT_ID:-}" || -z "${DATASET:-}" ]]; then
  echo "Usage: $0 <PROJECT_ID> <DATASET>   (e.g. $0 flor2u-prod analytics_123456789)"
  exit 1
fi

echo "=== Tables in ${PROJECT_ID}.${DATASET} (latest 20) ==="
bq ls --max_results=20 --format=prettyjson "${PROJECT_ID}:${DATASET}" \
  | grep -E '"tableId"|"type"' | head -40

echo
echo "=== Today's events (intraday streaming table) ==="
bq query --use_legacy_sql=false --project_id="$PROJECT_ID" --format=pretty "$(cat <<SQL
SELECT
  event_name,
  COUNT(*) AS events,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM \`${PROJECT_ID}.${DATASET}.events_intraday_*\`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
GROUP BY event_name
ORDER BY events DESC
LIMIT 20
SQL
)"
