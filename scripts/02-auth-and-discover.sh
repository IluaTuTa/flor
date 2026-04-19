#!/usr/bin/env bash
# Step 2-3. Login, list Firebase/GCP projects, and check whether the GA4 ->
# BigQuery export is enabled.
set -euo pipefail

# Open browser login. If running on a headless server use
# `gcloud auth login --no-launch-browser` instead.
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  gcloud auth login
fi
gcloud auth application-default login

echo
echo "=== Your GCP/Firebase projects ==="
gcloud projects list --format="table(projectId,name,projectNumber)"
echo

read -rp "Enter your Firebase project ID: " PROJECT_ID
gcloud config set project "$PROJECT_ID"
gcloud services enable bigquery.googleapis.com firebase.googleapis.com --project "$PROJECT_ID"

echo
echo "=== BigQuery datasets (GA4 export creates 'analytics_<property_id>') ==="
bq ls --project_id="$PROJECT_ID" || true
echo

DATASET="$(bq ls --project_id="$PROJECT_ID" --format=prettyjson 2>/dev/null \
  | grep -oE 'analytics_[0-9]+' | head -1 || true)"

if [[ -n "$DATASET" ]]; then
  echo "GA4 -> BigQuery export is ENABLED."
  echo "Dataset: $PROJECT_ID.$DATASET"
  echo "$DATASET" > .bq_dataset
  echo "$PROJECT_ID" > .bq_project
else
  cat <<'EOF'
GA4 -> BigQuery export is NOT enabled for this project.

Enable it manually (takes ~1 minute, data starts flowing within 24h):
  1. Open https://console.firebase.google.com -> pick your project
  2. Settings (gear) -> Integrations -> BigQuery -> "Link"
  3. Choose the GA4 property, select the region (EU or US), enable
     "Streaming" (near real-time) and "Daily" exports, click Link.
  4. Re-run this script tomorrow to see the dataset.

Alternative path via Google Analytics:
  Admin -> Product links -> BigQuery Links -> Link.
EOF
fi
