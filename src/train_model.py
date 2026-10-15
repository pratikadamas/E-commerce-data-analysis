"""
src/train_model.py
Order Profitability Machine Learning Pipeline
Part of E-Commerce Discount Impact Analysis Portfolio Project
"""

import os
from typing import Dict, Tuple, Any
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.dummy import DummyRegressor
from sklearn.linear_model import Ridge
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import TimeSeriesSplit, cross_val_score


def prepare_ml_dataset(
    delivered_orders: pd.DataFrame
) -> Tuple[pd.DataFrame, pd.Series, pd.DataFrame]:
    """Prepares feature matrix X and target y.
    Prevents data leakage by removing CostPrice, UnitPrice products, and direct margin calculations.
    Target: total_profit (Order-level realized gross profit).
    """
    df = delivered_orders.sort_values("OrderDate").reset_index(drop=True)

    target_col = "total_profit"
    y = df[target_col]

    # Select operational features available at order checkout / fulfillment
    feature_cols = [
        "order_value",
        "total_quantity",
        "item_count",
        "avg_discount",
        "max_discount",
        "has_discount",
        "Age",
        "CustomerTenureDays",
        "OrderYear",
        "OrderMonth",
        "OrderDayOfWeek",
        "IsWeekend",
        # Category composition (counts of items in each category)
        "Beauty",
        "Books",
        "Electronics",
        "Fashion",
        "Home",
    ]
    categorical_cols = ["PaymentMethod", "Region", "Gender"]

    # Ensure all columns exist
    for c in ["Beauty", "Books", "Electronics", "Fashion", "Home"]:
        if c not in df.columns:
            df[c] = 0

    X_raw = df[feature_cols + categorical_cols]
    X_encoded = pd.get_dummies(X_raw, columns=categorical_cols, drop_first=True)

    return X_encoded, y, df


def time_based_train_test_split(
    X: pd.DataFrame,
    y: pd.Series,
    df: pd.DataFrame,
    train_ratio: float = 0.8
) -> Dict[str, Any]:
    """Performs time-based chronological train-test split to simulate real-world forecasting."""
    n = len(df)
    split_idx = int(n * train_ratio)

    X_train, X_test = X.iloc[:split_idx], X.iloc[split_idx:]
    y_train, y_test = y.iloc[:split_idx], y.iloc[split_idx:]

    train_start = df.iloc[0]["OrderDate"].strftime("%Y-%m-%d")
    train_end = df.iloc[split_idx - 1]["OrderDate"].strftime("%Y-%m-%d")
    test_start = df.iloc[split_idx]["OrderDate"].strftime("%Y-%m-%d")
    test_end = df.iloc[-1]["OrderDate"].strftime("%Y-%m-%d")

    return {
        "X_train": X_train,
        "X_test": X_test,
        "y_train": y_train,
        "y_test": y_test,
        "split_idx": split_idx,
        "train_period": f"{train_start} to {train_end}",
        "test_period": f"{test_start} to {test_end}",
        "train_size": len(X_train),
        "test_size": len(X_test),
    }


def train_and_evaluate_all_models(
    split_data: Dict[str, Any],
    random_state: int = 42
) -> Dict[str, Any]:
    """Trains Baseline, Ridge, Random Forest, and Gradient Boosting models.
    Computes cross-validation, MAE, RMSE, and R2 on holdout test set.
    """
    X_train = split_data["X_train"]
    y_train = split_data["y_train"]
    X_test = split_data["X_test"]
    y_test = split_data["y_test"]

    models = {
        "Baseline (Mean)": DummyRegressor(strategy="mean"),
        "Ridge Regression": Ridge(alpha=10.0),
        "Random Forest": RandomForestRegressor(n_estimators=100, max_depth=10, random_state=random_state),
        "Gradient Boosting": GradientBoostingRegressor(
            n_estimators=120, learning_rate=0.08, max_depth=4, random_state=random_state
        ),
    }

    results = {}
    fitted_models = {}

    tscv = TimeSeriesSplit(n_splits=5)

    for name, model in models.items():
        # Cross-validation on train set
        if name != "Baseline (Mean)":
            cv_scores = cross_val_score(model, X_train, y_train, cv=tscv, scoring="r2")
            cv_r2 = float(cv_scores.mean())
        else:
            cv_r2 = 0.0

        # Fit model on full training set
        model.fit(X_train, y_train)
        fitted_models[name] = model

        # Predict on holdout test set
        preds = model.predict(X_test)

        mae = float(mean_absolute_error(y_test, preds))
        rmse = float(np.sqrt(mean_squared_error(y_test, preds)))
        r2 = float(r2_score(y_test, preds))

        results[name] = {
            "CV_R2": cv_r2,
            "Test_MAE": mae,
            "Test_RMSE": rmse,
            "Test_R2": r2,
            "predictions": preds,
        }

    return {"metrics": results, "models": fitted_models}


def extract_feature_importances(
    model: Any,
    feature_names: list
) -> pd.DataFrame:
    """Extracts and ranks feature importances from tree-based model."""
    if hasattr(model, "feature_importances_"):
        importances = model.feature_importances_
        df_imp = pd.DataFrame({
            "Feature": feature_names,
            "Importance": importances
        }).sort_values("Importance", ascending=False).reset_index(drop=True)
        return df_imp
    return pd.DataFrame()


def plot_model_evaluation(
    model: Any,
    X_test: pd.DataFrame,
    y_test: pd.Series,
    model_name: str = "Gradient Boosting",
    save_path: str = "reports/figures/05_model_diagnostics.png"
) -> plt.Figure:
    """Generates actual vs predicted plot and residual distribution."""
    preds = model.predict(X_test)
    residuals = y_test - preds

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5), dpi=300)

    # Actual vs Predicted
    ax1.scatter(y_test, preds, alpha=0.4, color="#1f77b4", edgecolor="none", s=25)
    min_val = min(y_test.min(), preds.min())
    max_val = max(y_test.max(), preds.max())
    ax1.plot([min_val, max_val], [min_val, max_val], "r--", linewidth=2, label="Perfect Fit (y=x)")
    ax1.set_title(f"{model_name}: Actual vs. Predicted Profit")
    ax1.set_xlabel("Actual Realized Profit ($)")
    ax1.set_ylabel("Predicted Profit ($)")
    ax1.legend()

    # Residuals
    sns.histplot(residuals, kde=True, ax=ax2, color="#2ca02c", bins=30, alpha=0.6)
    ax2.axvline(0, color="black", linestyle="--")
    ax2.set_title(f"{model_name}: Residuals Distribution (Mean={residuals.mean():.1f})")
    ax2.set_xlabel("Residual (Actual - Predicted) ($)")
    ax2.set_ylabel("Count")

    plt.tight_layout()
    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        plt.savefig(save_path, bbox_inches="tight")
    return fig
