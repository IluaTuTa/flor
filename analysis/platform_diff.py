"""iOS vs Android slice from a GA4-style events CSV.

Expected columns: user_pseudo_id, event_name, platform, app_version
(optional: ecommerce_purchase_revenue).

Usage:
    python3 analysis/platform_diff.py data/events.csv
"""
from __future__ import annotations
import argparse
from pathlib import Path

import pandas as pd


def compute(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = df[df["platform"].isin(["IOS", "ANDROID"])]
    grp = df.groupby(["platform", df.get("app_version", pd.Series(["?"] * len(df))).fillna("?")])
    out = grp.agg(
        users=("user_pseudo_id", "nunique"),
        view_item=("event_name", lambda s: (s == "view_item").sum()),
        add_to_cart=("event_name", lambda s: (s == "add_to_cart").sum()),
        purchases=("event_name", lambda s: (s == "purchase").sum()),
        revenue=("ecommerce_purchase_revenue",
                 "sum" if "ecommerce_purchase_revenue" in df.columns else "size"),
    ).reset_index()
    out.columns = ["platform", "app_version", "users", "view_item", "add_to_cart", "purchases", "revenue"]
    out["purchase_cr"] = out["purchases"] / out["users"]
    return out.sort_values(["platform", "users"], ascending=[True, False])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", type=Path)
    args = ap.parse_args()
    df = pd.read_csv(args.csv)
    out = compute(df)
    fmt = {"purchase_cr": "{:.2%}".format,
           "revenue": "{:,.2f}".format,
           "users": "{:,.0f}".format,
           "view_item": "{:,.0f}".format,
           "add_to_cart": "{:,.0f}".format,
           "purchases": "{:,.0f}".format}
    print(out.to_string(index=False, formatters=fmt))


if __name__ == "__main__":
    main()
