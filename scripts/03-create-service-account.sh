#!/usr/bin/env bash
# Step 5. Create a service account for read-only BigQuery access
# and download a JSON key into .secrets/ (git-ignored).
set -euo pipefail

PROJECT_ID="${1:-$(cat .bq_project 2>/dev/null || true)}"
if [[ -z "${PROJECT_ID:-}" ]]; then
  echo "Usage: $0 <PROJECT_ID>   (or run 02-auth-and-discover.sh first)"
  exit 1
fi

SA_NAME="flor2u-bq-reader"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_DIR=".secrets"
KEY_FILE="${KEY_DIR}/${SA_NAME}.json"

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="Flor2u BigQuery Reader (Claude Code)" \
    --project="$PROJECT_ID"
fi

# Minimum roles to read GA4 export tables.
for role in roles/bigquery.dataViewer roles/bigquery.jobUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --condition=None \
    --quiet >/dev/null
done

if [[ ! -f "$KEY_FILE" ]]; then
  gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID"
  chmod 600 "$KEY_FILE"
fi

ABS_PATH="$(cd "$(dirname "$KEY_FILE")" && pwd)/$(basename "$KEY_FILE")"
echo
echo "Service account: $SA_EMAIL"
echo "Key file:        $ABS_PATH"
echo "Roles:           bigquery.dataViewer, bigquery.jobUser"
echo
echo "Export for this shell:"
echo "  export GOOGLE_APPLICATION_CREDENTIALS=\"$ABS_PATH\""
