"""Weekly retention from a GA4-style events CSV.

Expected columns: user_pseudo_id, event_name, event_timestamp (microseconds since epoch).

Usage:
    python3 analysis/retention.py data/events.csv
"""
from __future__ import annotations
import argparse
from pathlib import Path

import pandas as pd


def compute(df: pd.DataFrame, weeks: int = 8) -> pd.DataFrame:
    df = df.copy()
    df["dt"] = pd.to_datetime(df["event_timestamp"], unit="us")
    df["week"] = df["dt"].dt.to_period("W-MON").dt.start_time

    first_open = (df[df["event_name"] == "first_open"]
                  .groupby("user_pseudo_id")["week"].min()
                  .rename("cohort_week"))
    if first_open.empty:
        raise SystemExit("no first_open events in input")

    activity = df.groupby(["user_pseudo_id", "week"]).size().reset_index().drop(columns=0)
    joined = activity.merge(first_open, on="user_pseudo_id")
    joined["wn"] = ((joined["week"] - joined["cohort_week"]).dt.days // 7).astype(int)
    joined = joined[joined["wn"] >= 0]

    pivot = (joined.groupby(["cohort_week", "wn"])["user_pseudo_id"].nunique()
             .unstack(fill_value=0).sort_index(ascending=False))
    pivot = pivot.reindex(columns=range(weeks + 1), fill_value=0)
    cohort_size = pivot[0].replace(0, pd.NA)
    rates = pivot.div(cohort_size, axis=0)
    rates.insert(0, "cohort_size", pivot[0])
    return rates


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", type=Path)
    ap.add_argument("--weeks", type=int, default=8)
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    out = compute(df, weeks=args.weeks)

    pct_cols = [c for c in out.columns if c != "cohort_size"]
    display = out.copy()
    for c in pct_cols:
        display[c] = display[c].apply(lambda v: "-" if pd.isna(v) else f"{v:.1%}")
    display["cohort_size"] = display["cohort_size"].astype("Int64").astype(str)
    print(display.to_string())


if __name__ == "__main__":
    main()
