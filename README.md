# 📊 E-Commerce Discount Impact Analysis Using Hypothesis Testing & Machine Learning

[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code Style: PEP 8](https://img.shields.io/badge/code%20style-PEP%208-green.svg)](https://pep8.org/)
[![Tests: Passing](https://img.shields.io/badge/tests-5%20passed-brightgreen.svg)](tests/)

> An end-to-end, industry-grade statistical analysis and machine learning pipeline investigating whether promotional discounts drive Average Order Value (AOV) expansion or profit margin dilution in e-commerce, extended with a leakage-free gradient boosted order profitability forecasting system.

---

## 📌 Executive Summary & Key Findings

| Metric / Dimension | Non-Discounted Orders | Discounted Orders | Delta / Impact | Statistical / Commercial Significance |
| :--- | :--- | :--- | :--- | :--- |
| **Delivered Orders ($n$)** | 156 ($3.6\%$) | 4,230 ($96.4\%$) | $4,386$ Total | Analytical population (delivered orders only) |
| **Mean AOV** | **$\$18,799.19$** | **$\$35,550.65$** | **$+89.11\%$** ($+\$16,751.46$) | **Welch's $t = 13.88$, $p = 1.87 \times 10^{-30}$** (Reject $H_0$) |
| **Median AOV** | $\$14,292.00$ | $\$32,649.20$ | $+128.4\%$ | **Mann-Whitney $U = 480,496.5, p = 3.22 \times 10^{-22}$** |
| **95% Confidence Interval** | — | — | **$[\$14,369.70, \$19,133.22]$** | True difference is large and strictly positive |
| **Standardized Effect Size** | — | — | **Cohen's $d = 0.744$**, **Hedges' $g = 0.744$** | **Medium-to-Large commercial magnitude** |
| **Mean Items / Basket** | 1.20 items | 2.56 items | **$+113.3\%$** | Primary mechanism driving order-level AOV |
| **Mean Units / Basket** | 3.12 units | 6.36 units | **$+103.8\%$** | Cross-selling and bundle expansion |
| **Mean Realized Margin** | **$38.65\%$** | **$32.24\%$** | **$-6.41$ percentage points** | Realized gross margin erosion |
| **Loss-Making Orders** | 0 orders ($0.0\%$) | 15 orders ($0.35\%$) | High-discount risk | Negative profit occurs only at $\ge 20\%$ discount |
| **Best ML Model ($R^2$)** | Baseline: $0.00$ | **Gradient Boosting: $0.9184$** | **$\text{MAE} = \$1,992.70$** | Reduced prediction error by $73.6\%$ vs baseline |

---

## 🎯 1. Business Problem & Hypotheses

### 1.1 Business Context
E-commerce businesses frequently deploy promotional discounts to stimulate customer demand and increase transaction volume. However, commercial debate persists between **Growth Marketing** (who argue discounts build larger carts and lift top-line revenue) and **Finance Operations** (who argue discounts erode profit margins and subsidize full-price buyers).

### 1.2 Hypotheses Formulation
We establish a two-sided independent two-sample test on the population mean AOV of delivered orders:

$$\begin{cases}
H_0: \mu_{\text{discount}} = \mu_{\text{no\_discount}} \quad \text{(Null Hypothesis: Mean AOV is identical)} \\
H_1: \mu_{\text{discount}} \neq \mu_{\text{no\_discount}} \quad \text{(Alternative Hypothesis: Mean AOV differs)}
\end{cases}$$

- **Significance Level ($\alpha$)**: $0.05$ (two-sided).
- **Test Statistic**: Independent two-sample **Welch's $t$-test** (robust to heteroscedasticity).

---

## 🗄️ 2. Dataset Architecture & Data Dictionary

The project analyzes five relational entities ($5,000$ total orders across $2.5$ years):

```
┌──────────────┐          ┌──────────────┐          ┌───────────────────┐
│  Customers   │ 1      * │    Orders    │ 1      * │   OrderDetails    │
│ (1,000 rows) ├──────────┤ (5,000 rows) ├──────────┤   (12,558 rows)   │
└──────────────┘          └──────┬───────┘          └─────────┬─────────┘
                                 │ 1                          │ *
                                 │                            │
                                 │ *                          │ 1
                          ┌──────┴───────┐          ┌─────────┴─────────┐
                          │   Returns    │          │     Products      │
                          │  (257 rows)  │          │     (82 rows)     │
                          └──────────────┘          └───────────────────┘
```

### Data Dictionary
| Table | Column | Type | Description |
| :--- | :--- | :--- | :--- |
| **Orders** | `OrderID` | String (PK) | Unique order identifier (`O00001` - `O05000`) |
| | `OrderDate` | Date | Order transaction date (`2024-01-01` to `2026-07-31`) |
| | `CustomerID` | String (FK) | Reference to customer (`C0001` - `C1000`) |
| | `PaymentMethod`| String | Payment channel (`UPI`, `Credit Card`, `Debit Card`, `Cash on Delivery`, `Net Banking`) |
| | `OrderStatus` | String | Order fulfillment state (`Delivered`: 4,386, `Cancelled`: 357, `Returned`: 257) |
| **OrderDetails** | `OrderDetailID`| String (PK) | Unique line item identifier (`OD000001` - `OD012558`) |
| | `OrderID` | String (FK) | Parent order identifier |
| | `ProductID` | String (FK) | Product SKU identifier (`P0001` - `P0082`) |
| | `Quantity` | Integer | Units ordered ($1$ to $4$) |
| | `UnitPrice` | Integer | Product catalogue unit price in INR/USD |
| | `DiscountPct` | Integer | Promotional discount percentage ($0, 5, 10, 15, 20, 25\%$) |
| | `SalesAmount` | Float | Final realized sales: $\text{UnitPrice} \times \text{Quantity} \times (1 - \text{DiscountPct}/100)$ |
| | `Profit` | Float | Realized gross profit: $\text{SalesAmount} - (\text{CostPrice} \times \text{Quantity})$ |
| **Customers** | `CustomerID` | String (PK) | Customer identifier |
| | `Gender`, `Age`, `City`, `Region`, `SignupDate` | Various | Customer demographic and cohort features |
| **Products** | `ProductID` | String (PK) | Product SKU identifier |
| | `ProductName`, `Category`, `CostPrice`, `SellingPrice` | Various | Catalogue metadata (Electronics, Fashion, Home, Beauty, Books) |
| **Returns** | `ReturnID`, `OrderID`, `ReturnDate`, `ReturnReason` | Various | Return audit log (`Damaged`, `Wrong Product`, `Not Needed`, etc.) |

---

## 🧹 3. Data Quality Audit & Analytical Unit Distinction

### 3.1 Quality Audit Summary
- **Null Values & Duplicates**: Zero missing values and zero duplicate rows across all five tables.
- **Referential Integrity**: Zero orphan records across all relational foreign key joins.
- **Arithmetic Consistency**: Confirmed that `SalesAmount` matches formula with $\le 7.28 \times 10^{-12}$ float delta, and `Profit` matches formula with $\le 3.64 \times 10^{-12}$ delta.
- **Timestamp Standardization**: Identified Unix microsecond artifact in `Returns.ReturnDate` and mapped returned orders to `OrderStatus == 'Returned'`.

### 3.2 Methodological Pitfall: The Analytical Unit
> ⚠️ **Order-Level Aggregation vs. Line-Item Level**:  
> In prior basic analyses, analysts frequently evaluated `OrderDetails` rows directly. However, an order in this store contains between **1 and 4 items** (average 2.51).  
> - **At the line-item level**: Discounts *reduce* average revenue per line ($\$13,663.42$ vs. $\$15,770.62$, Welch $t = -6.60, p = 5.34 \times 10^{-11}$).
> - **At the order level (AOV)**: Discounts stimulate customers to add more items to cart ($2.56$ items vs $1.20$ items), lifting Average Order Value by **$+89.11\%$**!  
> Evaluating at both levels resolves the commercial paradox: discounts decrease item price realization but unlock basket cross-selling.

---

## 📊 4. Exploratory Data Analysis & Visualizations

### 4.1 Order Value (AOV) Distribution & Boxplots
Discounted orders show substantially higher mean and dispersion, with heavy right-tail cart accumulation.

![AOV Distribution](reports/figures/01_aov_distribution.png)
![AOV Boxplots](reports/figures/02_aov_boxplots.png)

### 4.2 Basket Size Decomposition
Non-discounted orders consist overwhelmingly of single-item checkouts ($83.3\%$). In contrast, discounted orders drive multi-item carts ($77.2\%$ contain 2 to 4 items).

![Basket Size Comparison](reports/figures/03_basket_size_comparison.png)

### 4.3 Margin Compression & Risk Thresholds
Gross profit margin falls continuously from $38.7\%$ at zero discount to $19.4\%$ at $25\%$ discount. Crucially, **120 line items and 15 complete orders generated negative net profit** exclusively at the $20\%$ and $25\%$ discount tiers.

![Margin Compression](reports/figures/04_margin_compression_tier.png)

---

## 🧪 5. Statistical Hypothesis Testing & Effect Size

### 5.1 Assumption Testing
1. **Normality**: Skewness ($0.94$ and $1.34$) and D'Agostino tests reflect moderate positive skewness. In accordance with the **Central Limit Theorem (CLT)** ($n_1 = 4,230, n_2 = 156 \gg 30$), the sampling distribution of the sample mean is normal.
2. **Homoscedasticity**: Levene's test ($F = 38.00, p = 7.71 \times 10^{-10}$) strongly rejects equal variances ($s_1 = \$22,755.74$ vs. $s_2 = \$14,431.33$). **Welch's $t$-test is therefore strictly mandatory**.

### 5.2 Test Results
- **Welch's $t$-statistic**: $t = 13.8758$
- **Degrees of Freedom**: $\nu = 191.80$ (Welch-Satterthwaite adjustment)
- **$p$-value**: $p = 1.8665 \times 10^{-30} \ll 0.05$
- **Decision**: **Reject $H_0$** in favor of $H_1$.
- **Mean Difference**: $+\$16,751.46$ ($+89.11\%$)
- **95% Confidence Interval**: $[\$14,369.70, \$19,133.22]$
- **Standardized Effect Size**: Cohen's $d = 0.7440$, Hedges' $g = 0.7439$ (Medium-to-Large)
- **Non-Parametric Robustness**: Mann-Whitney $U = 480,496.5$, $p = 3.219 \times 10^{-22}$

---

## 🤖 6. Machine Learning Extension: Order Profitability Forecasting

### 6.1 Objective & Leakage Prevention
To empower real-time decision-making, we train machine learning models to predict realized order-level profit at checkout without target leakage (excluding direct cost and profit accounting formulas).

### 6.2 Chronological Time-Based Evaluation (80/20 Split)
- **Training Period**: `2024-01-01` to `2026-01-30` ($n = 3,508$)
- **Holdout Test Period**: `2026-01-30` to `2026-07-31` ($n = 878$)

### 6.3 Benchmark Results
| Model Architecture | 5-Fold TimeSeries CV $R^2$ | Test MAE ($) | Test RMSE ($) | Test $R^2$ |
| :--- | :--- | :--- | :--- | :--- |
| **Baseline (Mean Predictor)** | $0.0000$ | $\$7,537.94$ | $\$9,498.51$ | $-0.0000$ |
| **Ridge Regression ($\alpha=10.0$)** | $0.9068 \pm 0.009$ | $\$2,156.40$ | $\$2,842.85$ | $0.9104$ |
| **Random Forest Regressor** | $0.9102 \pm 0.008$ | $\$2,001.25$ | $\$2,781.10$ | $0.9142$ |
| **Gradient Boosting Regressor** | **$0.9145 \pm 0.007$** | **$\$1,992.70$** | **$\$2,714.07$** | **$0.9184$** |

![Model Diagnostics](reports/figures/05_model_diagnostics.png)

---

## 💡 7. Actionable Business Recommendations

1. **Gate Discounts Behind Cart Size Thresholds**: Because AOV expansion is powered by basket building, transition from flat discounts to threshold promotions (*"Save 10% on orders above $30,000"* or *"Buy 3 items, get 15% off"*).
2. **Cap Promotional Discount Depth at 15%**: Hard-stop promotions at $15\%$ to prevent margin collapse; discounts of $20-25\%$ triggered negative gross profit on lower-margin items.
3. **Deploy Real-Time Profit Scoring**: Implement the Gradient Boosting model in checkout to estimate expected order margin. Flag orders predicted to fall below $18\%$ margin and substitute with free shipping rather than percent markdowns.
4. **Conduct a Controlled A/B Experiment**: Validate observational findings by deploying a true randomized controlled trial (50% control full price vs. 50% treatment discount banner) to establish causal lift free from self-selection bias.

---

## 📂 8. Project Structure

```text
ecommerce-discount-analysis/
├── ecommerce_discount_impact_analysis.ipynb # 🌟 Comprehensive Master Portfolio Notebook (All-in-One)
│
├── 01_Data_Cleaning_and_Validation.ipynb    # Phase 1: Data Ingestion, Referential Integrity & Order Aggregation
├── 02_Exploratory_Data_Analysis.ipynb       # Phase 2: Distribution Modeling, Boxplots & Basket Decomposition
├── 03_Hypothesis_Testing_and_Effect_Size.ipynb # Phase 3: Assumption Diagnostics, Welch's t-test, Cohen's d & CI
├── 04_Machine_Learning_Profit_Prediction.ipynb # Phase 4: Leakage-Free Profit ML Pipeline & Time-Series CV
├── 05_Automated_Unit_Tests.ipynb            # Phase 5: Interactive Notebook Unit Test Suite (All 5 Passed)
│
├── notebooks/                               # Mirrored modular notebooks
│   ├── 01_Data_Cleaning_and_Validation.ipynb
│   ├── 02_Exploratory_Data_Analysis.ipynb
│   ├── 03_Hypothesis_Testing_and_Effect_Size.ipynb
│   ├── 04_Machine_Learning_Profit_Prediction.ipynb
│   └── 05_Automated_Unit_Tests.ipynb
├── src/                                     # Reusable Python Source Modules
│   ├── data_cleaning.py
│   ├── exploratory_analysis.py
│   ├── hypothesis_testing.py
│   └── train_model.py
├── reports/figures/                         # Generated High-Resolution Visual Figures (PNG)
│   ├── 01_aov_distribution.png
│   ├── 02_aov_boxplots.png
│   ├── 03_basket_size_comparison.png
│   ├── 04_margin_compression_tier.png
│   └── 05_model_diagnostics.png
├── data/
│   ├── raw/                                 # Raw CSV entities (Customers, Orders, OrderDetails, Products, Returns)
│   └── processed/                           # Aggregated order-level analytical units
├── tests/
│   └── test_analysis.py                     # Python unittest suite
├── requirements.txt                         # Package dependencies
├── README.md                                # Comprehensive documentation
└── .gitignore                               # Clean repository version control
```

---

## 🚀 9. Setup & Reproducibility Guide

### Installation
```bash
git clone https://github.com/your-username/ecommerce-discount-analysis.git
cd ecommerce-discount-analysis
pip install -r requirements.txt
```

### Running the Test Suite
```bash
python -m unittest tests/test_analysis.py
```

### Running the Master Notebook
```bash
jupyter notebook ecommerce_discount_impact_analysis.ipynb
```

---

## 📝 10. Portfolio & Resume Summary

**Bullet Point for Data Science Internship / Full-Time Resume:**
> * Engineered an end-to-end e-commerce promotional discount impact framework across 5,000 orders and 12,500 line items; established statistically significant AOV expansion (+89.1%, Welch's $t=13.88, p < 10^{-29}$, Cohen's $d=0.74$) driven by cart accumulation (2.56 vs 1.20 items/basket).
> * Uncovered critical gross margin compression from 38.7% to 19.4% and identified loss-making thresholds at $\ge 20\%$ discount depth; deployed a leakage-free Gradient Boosted profit forecasting pipeline ($R^2 = 0.918$, $\text{MAE} = \$1,993$) with time-based cross-validation.
