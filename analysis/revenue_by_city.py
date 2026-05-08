"""Revenue / orders / AOV by city.

Two input shapes accepted:
1. The output of sql/03_revenue_by_city.sql (already aggregated): columns
   country, city, orders, buyers, revenue, aov.
2. A raw events CSV with user_pseudo_id, event_name, geo_city, geo_country,
   ecommerce_purchase_revenue, ecommerce_transaction_id - it will be aggregated.

Usage:
    python3 analysis/revenue_by_city.py data/03_revenue_by_city.csv
    python3 analysis/revenue_by_city.py data/events.csv --top 30
"""
from __future__ import annotations
import argparse
from pathlib import Path

import pandas as pd

AGG_COLS = {"country", "city", "orders", "revenue"}


def aggregate_raw(df: pd.DataFrame) -> pd.DataFrame:
    purchases = df[(df["event_name"] == "purchase") & df["ecommerce_purchase_revenue"].notna()].copy()
    grouped = (purchases
               .groupby([purchases["geo_country"].fillna("(not set)"),
                         purchases["geo_city"].fillna("(not set)")])
               .agg(orders=("ecommerce_transaction_id", "nunique"),
                    buyers=("user_pseudo_id", "nunique"),
                    revenue=("ecommerce_purchase_revenue", "sum"))
               .reset_index())
    grouped.columns = ["country", "city", "orders", "buyers", "revenue"]
    grouped["aov"] = grouped["revenue"] / grouped["orders"]
    return grouped


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", type=Path)
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--country", default="Russia")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    if not AGG_COLS.issubset(df.columns):
        df = aggregate_raw(df)
    if "buyers" not in df.columns:
        df["buyers"] = pd.NA
    if "aov" not in df.columns:
        df["aov"] = df["revenue"] / df["orders"]

    df = df[df["country"] == args.country].sort_values("revenue", ascending=False).head(args.top)
    df["revenue"] = df["revenue"].round(2)
    df["aov"] = df["aov"].round(2)
    print(df.to_string(index=False))
    print(f"\n{args.country} totals: orders={int(df['orders'].sum()):,}  revenue={df['revenue'].sum():,.2f}")


if __name__ == "__main__":
    main()
