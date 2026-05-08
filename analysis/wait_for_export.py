"""Wait for the GA4 -> BigQuery export to materialise, then print a summary.

Polls list_datasets() every 30 seconds until a dataset matching `analytics_*`
appears, then dumps the table list and runs the today-events query.

Usage:
    GOOGLE_APPLICATION_CREDENTIALS=.secrets/flor2u-bq-reader.json \
        python3 analysis/wait_for_export.py --project flor2u
"""
from __future__ import annotations
import argparse
import re
import time

from google.cloud import bigquery


def find_analytics_dataset(client: bigquery.Client):
    for ds in client.list_datasets():
        if re.match(r"analytics_\d+", ds.dataset_id):
            return client.get_dataset(ds.reference)
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--interval", type=int, default=30, help="seconds between polls")
    ap.add_argument("--max-wait", type=int, default=1800, help="give up after N seconds")
    args = ap.parse_args()

    client = bigquery.Client(project=args.project)
    deadline = time.time() + args.max_wait
    while True:
        ds = find_analytics_dataset(client)
        if ds is not None:
            break
        if time.time() > deadline:
            raise SystemExit("Timed out waiting for analytics_* dataset to appear.")
        print(f"... no analytics_* dataset yet, sleeping {args.interval}s")
        time.sleep(args.interval)

    print(f"\nDataset: {ds.full_dataset_id} | location={ds.location}")
    tables = list(client.list_tables(ds.reference, max_results=20))
    print("Tables:")
    for t in tables:
        print(f"  {t.table_id}  ({t.table_type})")

    intraday = [t for t in tables if t.table_id.startswith("events_intraday_")]
    if intraday:
        sql = f"""
        SELECT event_name,
               COUNT(*) AS events,
               COUNT(DISTINCT user_pseudo_id) AS users
        FROM `{args.project}.{ds.dataset_id}.events_intraday_*`
        WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
        GROUP BY event_name
        ORDER BY events DESC
        LIMIT 30
        """
        print("\nToday's events:")
        for row in client.query(sql, location=ds.location).result():
            print(f"  {row.event_name:30s}  events={row.events:>8}  users={row.users:>6}")


if __name__ == "__main__":
    main()
