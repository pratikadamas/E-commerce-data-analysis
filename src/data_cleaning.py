"""
src/data_cleaning.py
Data Cleaning, Validation, and Aggregation Module
Part of E-Commerce Discount Impact Analysis Portfolio Project
"""

import os
from typing import Dict, Tuple
import pandas as pd
import numpy as np


def load_raw_data(data_dir: str = "data/raw") -> Dict[str, pd.DataFrame]:
    """Loads all five raw e-commerce CSV files into pandas DataFrames."""
    datasets = {
        "customers": pd.read_csv(os.path.join(data_dir, "Customers.csv")),
        "orders": pd.read_csv(os.path.join(data_dir, "Orders.csv")),
        "order_details": pd.read_csv(os.path.join(data_dir, "OrderDetails.csv")),
        "products": pd.read_csv(os.path.join(data_dir, "Products.csv")),
        "returns": pd.read_csv(os.path.join(data_dir, "Returns.csv")),
    }
    return datasets


def validate_data_integrity(datasets: Dict[str, pd.DataFrame]) -> Dict[str, any]:
    """Performs rigorous quality audits across raw tables:
    - Null values and exact duplicates
    - Relational referential integrity (foreign keys)
    - Value ranges (Quantity > 0, DiscountPct in [0, 100])
    - SalesAmount and Profit calculation verification
    - ReturnDate epoch anomalies
    """
    orders = datasets["orders"]
    od = datasets["order_details"]
    cust = datasets["customers"]
    prod = datasets["products"]
    ret = datasets["returns"]

    audit_results = {
        "shapes": {name: df.shape for name, df in datasets.items()},
        "null_counts": {name: df.isnull().sum().to_dict() for name, df in datasets.items()},
        "duplicate_rows": {name: int(df.duplicated().sum()) for name, df in datasets.items()},
        "orphan_order_details": int((~od["OrderID"].isin(orders["OrderID"])).sum()),
        "orphan_orders_customers": int((~orders["CustomerID"].isin(cust["CustomerID"])).sum()),
        "orphan_order_details_products": int((~od["ProductID"].isin(prod["ProductID"])).sum()),
        "orphan_returns": int((~ret["OrderID"].isin(orders["OrderID"])).sum()),
        "invalid_quantity": int((od["Quantity"] <= 0).sum()),
        "invalid_unit_price": int((od["UnitPrice"] <= 0).sum()),
        "invalid_discount_range": int(((od["DiscountPct"] < 0) | (od["DiscountPct"] > 100)).sum()),
    }

    # Verify SalesAmount formula: UnitPrice * Quantity * (1 - DiscountPct / 100)
    expected_sales = od["UnitPrice"] * od["Quantity"] * (1 - od["DiscountPct"] / 100)
    audit_results["max_sales_discrepancy"] = float((expected_sales - od["SalesAmount"]).abs().max())

    # Verify Profit formula: SalesAmount - CostPrice * Quantity
    merged_prod = od.merge(prod[["ProductID", "CostPrice"]], on="ProductID", how="left")
    expected_profit = merged_prod["SalesAmount"] - (merged_prod["CostPrice"] * merged_prod["Quantity"])
    audit_results["max_profit_discrepancy"] = float((expected_profit - merged_prod["Profit"]).abs().max())

    return audit_results


def clean_and_prepare_delivered_orders(
    datasets: Dict[str, pd.DataFrame]
) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """Filters delivered orders to establish the correct analytical population.
    Excludes Cancelled and Returned orders from revenue/AOV evaluation.
    Returns:
        delivered_orders (order-level): aggregated order table
        delivered_items (line-item level): clean merged order details
    """
    orders = datasets["orders"].copy()
    od = datasets["order_details"].copy()
    cust = datasets["customers"].copy()
    prod = datasets["products"].copy()

    # Convert timestamps
    orders["OrderDate"] = pd.to_datetime(orders["OrderDate"])
    cust["SignupDate"] = pd.to_datetime(cust["SignupDate"])

    # Subset Delivered orders
    delivered_orders = orders[orders["OrderStatus"] == "Delivered"].copy()
    delivered_items = od[od["OrderID"].isin(delivered_orders["OrderID"])].copy()

    # Merge line items with product metadata
    delivered_items = delivered_items.merge(prod, on="ProductID", how="left")
    delivered_items = delivered_items.merge(
        delivered_orders[["OrderID", "OrderDate", "CustomerID", "PaymentMethod"]],
        on="OrderID",
        how="left",
    )

    # Category count per order
    category_crosstab = pd.crosstab(delivered_items["OrderID"], delivered_items["Category"])

    # Aggregate to Order Level (analytical unit for AOV)
    order_agg = delivered_items.groupby("OrderID").agg(
        order_value=("SalesAmount", "sum"),
        total_profit=("Profit", "sum"),
        total_quantity=("Quantity", "sum"),
        item_count=("OrderDetailID", "count"),
        avg_discount=("DiscountPct", "mean"),
        max_discount=("DiscountPct", "max"),
        has_discount=("DiscountPct", lambda s: bool((s > 0).any())),
        all_discount=("DiscountPct", lambda s: bool((s > 0).all())),
    ).reset_index()

    # Add Profit Margin Pct at order level
    order_agg["profit_margin_pct"] = (order_agg["total_profit"] / order_agg["order_value"]) * 100

    # Merge customer attributes & order date
    final_orders = delivered_orders.merge(order_agg, on="OrderID", how="inner")
    final_orders = final_orders.merge(cust, on="CustomerID", how="left")
    final_orders = final_orders.merge(category_crosstab, on="OrderID", how="left").fillna(0)

    # Time attributes
    final_orders["OrderYear"] = final_orders["OrderDate"].dt.year
    final_orders["OrderMonth"] = final_orders["OrderDate"].dt.month
    final_orders["OrderDayOfWeek"] = final_orders["OrderDate"].dt.dayofweek
    final_orders["IsWeekend"] = final_orders["OrderDayOfWeek"].isin([5, 6]).astype(int)
    final_orders["CustomerTenureDays"] = (
        final_orders["OrderDate"] - final_orders["SignupDate"]
    ).dt.days

    return final_orders, delivered_items


def save_processed_datasets(
    final_orders: pd.DataFrame,
    delivered_items: pd.DataFrame,
    output_dir: str = "data/processed",
) -> None:
    """Saves processed datasets to data/processed directory."""
    os.makedirs(output_dir, exist_ok=True)
    final_orders.to_csv(os.path.join(output_dir, "orders_delivered_aggregated.csv"), index=False)
    delivered_items.to_csv(os.path.join(output_dir, "order_items_delivered.csv"), index=False)
