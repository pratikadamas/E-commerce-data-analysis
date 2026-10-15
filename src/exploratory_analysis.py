"""
src/exploratory_analysis.py
Exploratory Data Analysis and Visualization Functions
Part of E-Commerce Discount Impact Analysis Portfolio Project
"""

import os
from typing import Dict, Tuple
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns


# Set styling
plt.style.use("seaborn-v0_8-whitegrid" if "seaborn-v0_8-whitegrid" in plt.style.available else "default")
plt.rcParams.update({
    "font.family": "sans-serif",
    "font.size": 11,
    "axes.titlesize": 13,
    "axes.titleweight": "bold",
    "axes.labelsize": 11,
    "figure.titlesize": 15,
    "figure.titleweight": "bold",
})

PRIMARY_COLOR = "#1f77b4"
ACCENT_COLOR = "#ff7f0e"
SUCCESS_COLOR = "#2ca02c"
DANGER_COLOR = "#d62728"


def compute_group_statistics(delivered_orders: pd.DataFrame) -> pd.DataFrame:
    """Computes comprehensive descriptive statistics for Discounted vs Non-Discounted orders."""
    stats_list = []
    groups = {
        "Discounted Orders": delivered_orders[delivered_orders["has_discount"]]["order_value"],
        "Non-Discounted Orders": delivered_orders[~delivered_orders["has_discount"]]["order_value"],
    }

    for label, series in groups.items():
        q25 = series.quantile(0.25)
        q75 = series.quantile(0.75)
        stats_list.append({
            "Group": label,
            "Count (n)": len(series),
            "Mean": series.mean(),
            "Std Dev": series.std(),
            "Median": series.median(),
            "IQR": q75 - q25,
            "25th Pct": q25,
            "75th Pct": q75,
            "Min": series.min(),
            "Max": series.max(),
            "Skewness": series.skew(),
        })

    return pd.DataFrame(stats_list).set_index("Group")


def plot_aov_distribution(
    delivered_orders: pd.DataFrame,
    save_path: str = "reports/figures/01_aov_distribution.png"
) -> plt.Figure:
    """Generates dual KDE and histogram comparing order values between groups."""
    fig, ax = plt.subplots(figsize=(10, 5), dpi=300)

    disc = delivered_orders[delivered_orders["has_discount"]]["order_value"]
    nodisc = delivered_orders[~delivered_orders["has_discount"]]["order_value"]

    sns.histplot(
        disc,
        color=PRIMARY_COLOR,
        kde=True,
        stat="density",
        bins=35,
        alpha=0.35,
        label=f"Discounted (n={len(disc):,}, Mean=${disc.mean():,.0f})",
        ax=ax,
    )
    sns.histplot(
        nodisc,
        color=ACCENT_COLOR,
        kde=True,
        stat="density",
        bins=25,
        alpha=0.45,
        label=f"Non-Discounted (n={len(nodisc):,}, Mean=${nodisc.mean():,.0f})",
        ax=ax,
    )

    ax.axvline(disc.mean(), color=PRIMARY_COLOR, linestyle="--", linewidth=1.8, label="Disc Mean")
    ax.axvline(nodisc.mean(), color=ACCENT_COLOR, linestyle="--", linewidth=1.8, label="No-Disc Mean")

    ax.set_title("Distribution of Order Values (AOV): Discounted vs. Non-Discounted")
    ax.set_xlabel("Order Value ($)")
    ax.set_ylabel("Probability Density")
    ax.legend(frameon=True, facecolor="white")
    ax.set_xlim(0, 140000)

    plt.tight_layout()
    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        plt.savefig(save_path, bbox_inches="tight")
    return fig


def plot_aov_boxplots(
    delivered_orders: pd.DataFrame,
    save_path: str = "reports/figures/02_aov_boxplots.png"
) -> plt.Figure:
    """Generates boxplots and violin plots showing median, quartiles, and dispersion."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5), dpi=300)

    df_plot = delivered_orders.copy()
    df_plot["DiscountGroup"] = np.where(
        df_plot["has_discount"], "Discounted (n=4,230)", "No-Discount (n=156)"
    )

    palette = {"Discounted (n=4,230)": PRIMARY_COLOR, "No-Discount (n=156)": ACCENT_COLOR}

    sns.boxplot(
        data=df_plot,
        x="DiscountGroup",
        y="order_value",
        palette=palette,
        ax=ax1,
        width=0.4,
        fliersize=3,
        showmeans=True,
        meanprops={"marker": "D", "markerfacecolor": "red", "markeredgecolor": "black"},
    )
    ax1.set_title("Order Value Boxplot (Red Diamond = Mean)")
    ax1.set_xlabel("Order Segment")
    ax1.set_ylabel("Order Value ($)")

    sns.boxplot(
        data=df_plot,
        x="DiscountGroup",
        y="profit_margin_pct",
        palette=palette,
        ax=ax2,
        width=0.4,
        fliersize=3,
        showmeans=True,
        meanprops={"marker": "D", "markerfacecolor": "red", "markeredgecolor": "black"},
    )
    ax2.set_title("Gross Profit Margin % Boxplot")
    ax2.set_xlabel("Order Segment")
    ax2.set_ylabel("Gross Profit Margin (%)")

    plt.tight_layout()
    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        plt.savefig(save_path, bbox_inches="tight")
    return fig


def plot_basket_size_comparison(
    delivered_orders: pd.DataFrame,
    save_path: str = "reports/figures/03_basket_size_comparison.png"
) -> plt.Figure:
    """Explains why AOV is higher in discounted orders: Basket size distribution."""
    fig, ax = plt.subplots(figsize=(9, 4.8), dpi=300)

    df_plot = delivered_orders.copy()
    df_plot["DiscountGroup"] = np.where(df_plot["has_discount"], "Discounted", "Non-Discounted")

    basket_counts = (
        df_plot.groupby(["item_count", "DiscountGroup"])
        .size()
        .unstack(fill_value=0)
    )
    basket_pct = basket_counts.div(basket_counts.sum(axis=0), axis=1) * 100

    basket_pct.plot(
        kind="bar",
        ax=ax,
        color=[PRIMARY_COLOR, ACCENT_COLOR],
        width=0.6,
        edgecolor="black",
        alpha=0.85,
    )

    ax.set_title("Basket Size Distribution (% of Orders by Number of Items in Cart)")
    ax.set_xlabel("Number of Line Items in Order")
    ax.set_ylabel("Percentage of Segment Orders (%)")
    ax.legend(title="Segment", frameon=True)
    plt.xticks(rotation=0)

    # Annotate bars
    for p in ax.patches:
        height = p.get_height()
        if height > 0:
            ax.annotate(
                f"{height:.1f}%",
                (p.get_x() + p.get_width() / 2.0, height + 1),
                ha="center",
                va="bottom",
                fontsize=9,
            )

    ax.set_ylim(0, 100)
    plt.tight_layout()
    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        plt.savefig(save_path, bbox_inches="tight")
    return fig


def plot_margin_compression_by_discount_tier(
    delivered_items: pd.DataFrame,
    save_path: str = "reports/figures/04_margin_compression_tier.png"
) -> plt.Figure:
    """Shows the commercial trade-off: Profit margin erosion as discount percentage increases."""
    fig, ax = plt.subplots(figsize=(9, 4.8), dpi=300)

    tier_summary = delivered_items.groupby("DiscountPct").agg(
        total_sales=("SalesAmount", "sum"),
        total_profit=("Profit", "sum"),
        item_count=("OrderDetailID", "count"),
    ).reset_index()

    tier_summary["margin_pct"] = (tier_summary["total_profit"] / tier_summary["total_sales"]) * 100

    ax.plot(
        tier_summary["DiscountPct"],
        tier_summary["margin_pct"],
        marker="o",
        linewidth=2.5,
        color=DANGER_COLOR,
        markersize=8,
    )

    for _, row in tier_summary.iterrows():
        ax.annotate(
            f"{row['margin_pct']:.1f}%",
            (row["DiscountPct"], row["margin_pct"] + 1.0),
            ha="center",
            fontweight="bold",
            fontsize=10,
        )

    ax.set_title("Gross Profit Margin Erosion Across Discount Tiers")
    ax.set_xlabel("Discount Percentage (%)")
    ax.set_ylabel("Realized Gross Margin (%)")
    ax.set_ylim(10, 48)

    plt.tight_layout()
    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        plt.savefig(save_path, bbox_inches="tight")
    return fig
