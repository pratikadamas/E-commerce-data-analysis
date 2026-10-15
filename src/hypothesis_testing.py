"""
src/hypothesis_testing.py
Statistical Hypothesis Testing, Normality / Variance Assumptions, and Effect Sizes
Part of E-Commerce Discount Impact Analysis Portfolio Project
"""

from typing import Dict, Tuple, Any
import numpy as np
import pandas as pd
from scipy import stats


def check_normality(
    group1: pd.Series,
    group2: pd.Series,
    labels: Tuple[str, str] = ("Discounted", "Non-Discounted")
) -> Dict[str, Any]:
    """Evaluates normality assumptions using:
    - Sample sizes
    - Skewness and Kurtosis
    - D'Agostino K-squared test (suitable for larger samples)
    - Kolmogorov-Smirnov test against normal distribution
    Includes methodological caveats regarding high sample sensitivity.
    """
    results = {}
    for grp, label in zip([group1, group2], labels):
        clean_grp = grp.dropna()
        n = len(clean_grp)
        skew = float(stats.skew(clean_grp))
        kurt = float(stats.kurtosis(clean_grp))

        # D'Agostino test
        dag_stat, dag_p = stats.normaltest(clean_grp) if n >= 20 else (np.nan, np.nan)

        # KS test against fitted normal
        ks_stat, ks_p = stats.kstest(
            clean_grp, "norm", args=(clean_grp.mean(), clean_grp.std(ddof=1))
        )

        results[label] = {
            "n": n,
            "mean": float(clean_grp.mean()),
            "std": float(clean_grp.std(ddof=1)),
            "skewness": skew,
            "kurtosis": kurt,
            "dagostino_stat": float(dag_stat),
            "dagostino_p": float(dag_p),
            "ks_stat": float(ks_stat),
            "ks_p": float(ks_p),
            "normality_caveat": (
                "For large n (>1000), goodness-of-fit tests reject the null for trivial deviations. "
                "By the Central Limit Theorem (CLT), the sampling distribution of the mean is asymptotically normal."
            ),
        }
    return results


def check_variance_equality(
    group1: pd.Series,
    group2: pd.Series,
    labels: Tuple[str, str] = ("Discounted", "Non-Discounted")
) -> Dict[str, Any]:
    """Tests homoscedasticity using Levene's test (centered at median for robustness against skewness)
    and Bartlett's test.
    """
    g1 = group1.dropna()
    g2 = group2.dropna()

    levene_stat, levene_p = stats.levene(g1, g2, center="median")
    fligner_stat, fligner_p = stats.fligner(g1, g2)

    var1 = float(g1.var(ddof=1))
    var2 = float(g2.var(ddof=1))
    var_ratio = var1 / var2 if var2 > 0 else np.nan

    return {
        "variance_group1": var1,
        "variance_group2": var2,
        "variance_ratio": var_ratio,
        "levene_stat": float(levene_stat),
        "levene_p": float(levene_p),
        "fligner_stat": float(fligner_stat),
        "fligner_p": float(fligner_p),
        "equal_var_assumption": bool(levene_p >= 0.05),
        "recommendation": (
            "Variances differ significantly (Levene p < 0.05); Welch's t-test is strictly required."
            if levene_p < 0.05
            else "Equal variances cannot be rejected."
        ),
    }


def perform_welch_ttest(
    group1: pd.Series,
    group2: pd.Series,
    alpha: float = 0.05
) -> Dict[str, Any]:
    """Executes Welch's two-sample independent t-test (equal_var=False, two-sided).
    Calculates Welch-Satterthwaite degrees of freedom.
    """
    g1 = group1.dropna()
    g2 = group2.dropna()

    t_stat, p_val = stats.ttest_ind(g1, g2, equal_var=False, alternative="two-sided")

    # Satterthwaite degrees of freedom
    v1 = g1.var(ddof=1)
    v2 = g2.var(ddof=1)
    n1 = len(g1)
    n2 = len(g2)
    df = (v1 / n1 + v2 / n2) ** 2 / (((v1 / n1) ** 2 / (n1 - 1)) + ((v2 / n2) ** 2 / (n2 - 1)))

    decision = "Reject H0" if p_val < alpha else "Fail to reject H0"

    return {
        "t_statistic": float(t_stat),
        "p_value": float(p_val),
        "degrees_of_freedom": float(df),
        "alpha": alpha,
        "decision": decision,
        "interpretation": (
            f"Statistically significant difference detected at alpha={alpha} (p={p_val:.4e}). "
            "Reject null hypothesis that population mean AOVs are equal."
            if p_val < alpha
            else f"Insufficient evidence to reject null hypothesis at alpha={alpha} (p={p_val:.4f})."
        ),
    }


def perform_mann_whitney_u(group1: pd.Series, group2: pd.Series) -> Dict[str, Any]:
    """Non-parametric robustness check comparing distribution medians/ranks."""
    g1 = group1.dropna()
    g2 = group2.dropna()
    u_stat, p_val = stats.mannwhitneyu(g1, g2, alternative="two-sided")
    return {
        "mann_whitney_u_stat": float(u_stat),
        "mann_whitney_p_value": float(p_val),
        "median_group1": float(g1.median()),
        "median_group2": float(g2.median()),
        "median_diff": float(g1.median() - g2.median()),
    }


def calculate_effect_sizes_and_ci(
    group1: pd.Series,
    group2: pd.Series,
    alpha: float = 0.05
) -> Dict[str, Any]:
    """Computes effect sizes and Welch 95% Confidence Interval for mean difference.
    - Absolute Mean Difference
    - Percentage Mean Difference
    - 95% Confidence Interval using Welch-Satterthwaite df
    - Pooled Standard Deviation
    - Cohen's d (standardized mean difference)
    - Hedges' g (bias-corrected Cohen's d for unbalanced sample sizes)
    """
    g1 = group1.dropna()
    g2 = group2.dropna()

    n1, n2 = len(g1), len(g2)
    m1, m2 = float(g1.mean()), float(g2.mean())
    s1, s2 = float(g1.std(ddof=1)), float(g2.std(ddof=1))
    v1, v2 = s1 ** 2, s2 ** 2

    mean_diff = m1 - m2
    pct_diff = (mean_diff / m2) * 100 if m2 != 0 else np.nan

    # Standard error of difference under unequal variances
    se_diff = np.sqrt(v1 / n1 + v2 / n2)

    # Welch-Satterthwaite df
    df = (v1 / n1 + v2 / n2) ** 2 / (((v1 / n1) ** 2 / (n1 - 1)) + ((v2 / n2) ** 2 / (n2 - 1)))

    # Confidence Interval
    ci_lower, ci_upper = stats.t.interval(1 - alpha, df=df, loc=mean_diff, scale=se_diff)

    # Pooled Standard Deviation
    s_pooled = np.sqrt(((n1 - 1) * v1 + (n2 - 1) * v2) / (n1 + n2 - 2))

    # Cohen's d
    cohens_d = mean_diff / s_pooled if s_pooled > 0 else np.nan

    # Hedges' g (correction factor for sample size)
    hedges_correction = 1 - (3 / (4 * (n1 + n2) - 9))
    hedges_g = cohens_d * hedges_correction

    # Effect size magnitude interpretation
    abs_d = abs(cohens_d)
    if abs_d < 0.2:
        d_interp = "Negligible"
    elif abs_d < 0.5:
        d_interp = "Small"
    elif abs_d < 0.8:
        d_interp = "Medium"
    else:
        d_interp = "Large"

    return {
        "n_group1": n1,
        "n_group2": n2,
        "mean_group1": m1,
        "mean_group2": m2,
        "std_group1": s1,
        "std_group2": s2,
        "mean_difference": float(mean_diff),
        "pct_difference": float(pct_diff),
        "se_difference": float(se_diff),
        "ci_lower": float(ci_lower),
        "ci_upper": float(ci_upper),
        "ci_level": 1 - alpha,
        "s_pooled": float(s_pooled),
        "cohens_d": float(cohens_d),
        "hedges_g": float(hedges_g),
        "effect_size_magnitude": d_interp,
    }


def run_full_hypothesis_pipeline(
    delivered_orders: pd.DataFrame,
    alpha: float = 0.05
) -> Dict[str, Any]:
    """End-to-end hypothesis testing pipeline evaluating order-level AOV."""
    disc_orders = delivered_orders.loc[delivered_orders["has_discount"], "order_value"]
    nodisc_orders = delivered_orders.loc[~delivered_orders["has_discount"], "order_value"]

    norm_res = check_normality(disc_orders, nodisc_orders)
    var_res = check_variance_equality(disc_orders, nodisc_orders)
    welch_res = perform_welch_ttest(disc_orders, nodisc_orders, alpha=alpha)
    mwu_res = perform_mann_whitney_u(disc_orders, nodisc_orders)
    eff_res = calculate_effect_sizes_and_ci(disc_orders, nodisc_orders, alpha=alpha)

    return {
        "normality": norm_res,
        "variance": var_res,
        "welch_test": welch_res,
        "mann_whitney": mwu_res,
        "effect_sizes": eff_res,
    }
