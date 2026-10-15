"""
tests/test_analysis.py
Unit and Integration Tests for E-Commerce Analysis Pipeline
"""

import unittest
import pandas as pd
import numpy as np

from src.data_cleaning import load_raw_data, validate_data_integrity, clean_and_prepare_delivered_orders
from src.hypothesis_testing import (
    perform_welch_ttest,
    calculate_effect_sizes_and_ci,
    check_variance_equality,
    check_normality,
)
from src.train_model import (
    prepare_ml_dataset,
    time_based_train_test_split,
    train_and_evaluate_all_models,
)


class TestEcommerceAnalysisPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.datasets = load_raw_data("data/raw")
        cls.delivered_orders, cls.delivered_items = clean_and_prepare_delivered_orders(cls.datasets)

    def test_01_raw_data_integrity(self):
        """Verify no missing foreign keys and all prices/quantities are positive."""
        audit = validate_data_integrity(self.datasets)
        self.assertEqual(audit["orphan_order_details"], 0)
        self.assertEqual(audit["orphan_orders_customers"], 0)
        self.assertEqual(audit["invalid_quantity"], 0)
        self.assertLess(audit["max_sales_discrepancy"], 1e-6)
        self.assertLess(audit["max_profit_discrepancy"], 1e-6)

    def test_02_delivered_orders_aggregation(self):
        """Verify proper aggregation of line items to order-level analytical unit."""
        self.assertEqual(len(self.delivered_orders), 4386)
        self.assertTrue((self.delivered_orders["order_value"] > 0).all())
        # Check discount groupings
        disc_count = self.delivered_orders["has_discount"].sum()
        nodisc_count = (~self.delivered_orders["has_discount"]).sum()
        self.assertEqual(disc_count, 4230)
        self.assertEqual(nodisc_count, 156)

    def test_03_statistical_testing(self):
        """Verify Welch t-test and effect size calculations."""
        disc = self.delivered_orders.loc[self.delivered_orders["has_discount"], "order_value"]
        nodisc = self.delivered_orders.loc[~self.delivered_orders["has_discount"], "order_value"]

        welch = perform_welch_ttest(disc, nodisc, alpha=0.05)
        self.assertIn("t_statistic", welch)
        self.assertIn("p_value", welch)
        self.assertLess(welch["p_value"], 0.05)
        self.assertEqual(welch["decision"], "Reject H0")

        eff = calculate_effect_sizes_and_ci(disc, nodisc, alpha=0.05)
        self.assertGreater(eff["mean_difference"], 0)
        self.assertGreater(eff["cohens_d"], 0.5)  # Moderate-to-large effect size
        self.assertLess(eff["ci_lower"], eff["ci_upper"])

    def test_04_time_based_split_ordering(self):
        """Verify time-based train/test split has no temporal leakage."""
        X, y, df = prepare_ml_dataset(self.delivered_orders)
        split_data = time_based_train_test_split(X, y, df, train_ratio=0.8)

        train_max_date = df.iloc[: split_data["split_idx"]]["OrderDate"].max()
        test_min_date = df.iloc[split_data["split_idx"] :]["OrderDate"].min()
        self.assertLessEqual(train_max_date, test_min_date)

    def test_05_model_performance(self):
        """Verify trained ML models beat the baseline with R2 > 0.85."""
        X, y, df = prepare_ml_dataset(self.delivered_orders)
        split_data = time_based_train_test_split(X, y, df, train_ratio=0.8)
        results = train_and_evaluate_all_models(split_data)

        gb_r2 = results["metrics"]["Gradient Boosting"]["Test_R2"]
        baseline_mae = results["metrics"]["Baseline (Mean)"]["Test_MAE"]
        gb_mae = results["metrics"]["Gradient Boosting"]["Test_MAE"]

        self.assertGreater(gb_r2, 0.85)
        self.assertLess(gb_mae, baseline_mae)


if __name__ == "__main__":
    unittest.main()
