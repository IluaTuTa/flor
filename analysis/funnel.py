"""Compute the Flor2u purchase funnel from a GA4-like events CSV.

Expected input: CSV exported from BigQuery, one row per event, with at least
columns: user_pseudo_id, event_name. Anything else is ignored.

Usage:
    python3 analysis/funnel.py data/events.csv
    python3 analysis/funnel.py data/events.csv --out analysis/funnel.png
"""
from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

STEPS = ["first_open", "view_item", "add_to_cart", "begin_checkout", "purchase"]


def compute(df: pd.DataFrame) -> pd.DataFrame:
    users = df.groupby("user_pseudo_id")["event_name"].agg(set)
    rows = []
    prev = None
    first = None
    for i, step in enumerate(STEPS, 1):
        n = int(users.apply(lambda s, step=step: step in s).sum())
        if first is None:
            first = n
        rows.append({
            "step_num": i,
            "step": step,
            "users": n,
            "cr_from_first_open": n / first if first else None,
            "cr_from_prev_step": n / prev if prev else None,
        })
        prev = n
    return pd.DataFrame(rows)


def render(out: pd.DataFrame, path: Path) -> None:
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.barh(out["step"][::-1], out["users"][::-1])
    for i, (users, cr) in enumerate(zip(out["users"][::-1], out["cr_from_first_open"][::-1])):
        ax.text(users, i, f"  {users:,} ({cr:.1%})", va="center")
    ax.set_xlabel("users")
    ax.set_title("Flor2u purchase funnel")
    fig.tight_layout()
    fig.savefig(path, dpi=140)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", type=Path)
    ap.add_argument("--out", type=Path, default=None, help="optional PNG output")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    result = compute(df)
    print(result.to_string(index=False, float_format=lambda x: f"{x:.2%}" if 0 <= x <= 1 else f"{x:.2f}"))

    if args.out:
        render(result, args.out)
        print(f"chart -> {args.out}")


if __name__ == "__main__":
    main()
