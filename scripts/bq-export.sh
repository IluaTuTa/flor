#!/usr/bin/env bash
# Run one of the SQL templates from sql/ against BigQuery and dump the result
# into data/<name>.csv so it can be analysed in Claude Code.
#
# Usage:  ./scripts/bq-export.sh sql/01_purchase_funnel.sql
#         ./scripts/bq-export.sh sql/05_today_events.sql data/today.csv
set -euo pipefail

SQL_FILE="${1:?Usage: $0 <sql_file> [out_csv]}"
OUT_FILE="${2:-data/$(basename "${SQL_FILE%.sql}").csv}"

PROJECT="${BIGQUERY_PROJECT:-$(cat .bq_project 2>/dev/null || true)}"
DATASET="${BIGQUERY_DATASET:-$(cat .bq_dataset 2>/dev/null || true)}"
LOCATION="${BIGQUERY_LOCATION:-EU}"

if [[ -z "$PROJECT" || -z "$DATASET" ]]; then
  echo "Set BIGQUERY_PROJECT and BIGQUERY_DATASET (e.g. source .env) first."
  exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"

# Substitute @project / @dataset placeholders before sending to bq.
sed -e "s/@project/${PROJECT}/g" -e "s/@dataset/${DATASET}/g" "$SQL_FILE" \
  | bq query --nouse_legacy_sql --location="$LOCATION" --format=csv --max_rows=100000 \
  > "$OUT_FILE"

echo "Wrote $(wc -l < "$OUT_FILE") lines to $OUT_FILE"
