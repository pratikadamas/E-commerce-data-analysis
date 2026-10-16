-- ====================================================================================
-- E-COMMERCE DATA ANALYSIS & STATISTICAL BUSINESS INTELLIGENCE
-- Project: E-Commerce Promotional Discount Impact Analysis, AOV & Profit Forecasting
-- Database Engine: MySQL 8.0+
-- ====================================================================================

-- ====================================================================================
-- SECTION 1: DATABASE INITIALIZATION & SCHEMA DDL
-- ====================================================================================

CREATE DATABASE IF NOT EXISTS ecommerce;
USE ecommerce;

-- Customers table
CREATE TABLE IF NOT EXISTS Customers (
    CustomerID VARCHAR(10) PRIMARY KEY,
    CustomerName VARCHAR(100),
    Gender VARCHAR(20),
    Age INT,
    City VARCHAR(50),
    Region VARCHAR(30),
    SignupDate DATE
);

-- Products table
CREATE TABLE IF NOT EXISTS Products (
    ProductID VARCHAR(10) PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50),
    CostPrice DECIMAL(12, 2),
    SellingPrice DECIMAL(12, 2)
);

-- Orders table
CREATE TABLE IF NOT EXISTS Orders (
    OrderID VARCHAR(10) PRIMARY KEY,
    OrderDate DATE,
    CustomerID VARCHAR(10),
    PaymentMethod VARCHAR(30),
    OrderStatus VARCHAR(20),
    FOREIGN KEY (CustomerID)
        REFERENCES Customers (CustomerID)
);

-- OrderDetails table
CREATE TABLE IF NOT EXISTS OrderDetails (
    OrderDetailID VARCHAR(12) PRIMARY KEY,
    OrderID VARCHAR(10),
    ProductID VARCHAR(10),
    Quantity INT,
    UnitPrice DECIMAL(12, 2),
    DiscountPct DECIMAL(5, 2),
    SalesAmount DECIMAL(14, 2),
    Profit DECIMAL(14, 2),
    FOREIGN KEY (OrderID)
        REFERENCES Orders (OrderID),
    FOREIGN KEY (ProductID)
        REFERENCES Products (ProductID)
);

-- Returns table
CREATE TABLE IF NOT EXISTS Returns (
    ReturnID VARCHAR(10) PRIMARY KEY,
    OrderID VARCHAR(10),
    ReturnDate DATE,
    ReturnReason VARCHAR(50),
    FOREIGN KEY (OrderID)
        REFERENCES Orders (OrderID)
);

-- Check all created tables
SHOW TABLES;


-- ====================================================================================
-- SECTION 2: DATA HYGIENE, QUALITY AUDITS & INTEGRITY CHECKS
-- ====================================================================================

-- 2.1 Preview sample records across all entities
SELECT * FROM Customers LIMIT 10;
SELECT * FROM Products LIMIT 5;
SELECT * FROM Orders LIMIT 5;
SELECT * FROM OrderDetails LIMIT 5;
SELECT * FROM Returns LIMIT 5;

-- 2.2 Table record counts
SELECT COUNT(*) AS CustomerCount FROM Customers;
SELECT COUNT(*) AS ProductCount FROM Products;
SELECT COUNT(*) AS OrderCount FROM Orders;
SELECT COUNT(*) AS OrderDetailCount FROM OrderDetails;
SELECT COUNT(*) AS ReturnCount FROM Returns;

-- 2.3 Primary Key uniqueness / duplicate audit
SELECT CustomerID, COUNT(*) AS DuplicateCount
FROM Customers
GROUP BY CustomerID
HAVING COUNT(*) > 1;

SELECT ProductID, COUNT(*) AS DuplicateCount
FROM Products
GROUP BY ProductID
HAVING COUNT(*) > 1;

-- 2.4 NULL value audit across Customers entity
SELECT
    SUM(CustomerID IS NULL) AS CustomerID_Null,
    SUM(CustomerName IS NULL) AS CustomerName_Null,
    SUM(Gender IS NULL) AS Gender_Null,
    SUM(Age IS NULL) AS Age_Null,
    SUM(City IS NULL) AS City_Null,
    SUM(Region IS NULL) AS Region_Null,
    SUM(SignupDate IS NULL) AS SignupDate_Null
FROM Customers;

-- 2.5 Foreign Key referential integrity audits
-- Orphan orders without matching customer
SELECT o.OrderID, o.CustomerID
FROM Orders o
LEFT JOIN Customers c
    ON o.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;

-- Orphan order details without matching parent order
SELECT od.OrderDetailID, od.OrderID
FROM OrderDetails od
LEFT JOIN Orders o
    ON od.OrderID = o.OrderID
WHERE o.OrderID IS NULL;

-- Orphan order details without matching product catalog record
SELECT od.OrderDetailID, od.ProductID
FROM OrderDetails od
LEFT JOIN Products p
    ON od.ProductID = p.ProductID
WHERE p.ProductID IS NULL;

-- Orphan returns without matching parent order
SELECT r.ReturnID, r.OrderID
FROM Returns r
LEFT JOIN Orders o
    ON r.OrderID = o.OrderID
WHERE o.OrderID IS NULL;

-- 2.6 Basic business date boundary audit
SELECT
    MIN(OrderDate) AS FirstOrderDate,
    MAX(OrderDate) AS LastOrderDate,
    COUNT(DISTINCT CustomerID) AS UniqueCustomersActive
FROM Orders;


-- ====================================================================================
-- SECTION 3: BASELINE BUSINESS KPIS & DESCRIPTIVE METRICS
-- ====================================================================================

-- 3.1 Order Status distribution
SELECT
    OrderStatus,
    COUNT(*) AS TotalOrders,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Orders), 2) AS StatusPercentage
FROM Orders
GROUP BY OrderStatus
ORDER BY TotalOrders DESC;

-- 3.2 Total Delivered Orders count
SELECT COUNT(*) AS DeliveredOrdersCount
FROM Orders
WHERE OrderStatus = 'Delivered';

-- 3.3 Overall Realized Revenue (Delivered Orders)
SELECT 
    ROUND(SUM(od.SalesAmount), 2) AS TotalDeliveredRevenue
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered';

-- 3.4 Overall Realized Profit (Delivered Orders)
SELECT 
    ROUND(SUM(od.Profit), 2) AS TotalDeliveredProfit
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered';

-- 3.5 Realized Revenue, Profit, and Overall Profit Margin %
SELECT
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(SUM(od.Profit), 2) AS TotalProfit,
    ROUND((SUM(od.Profit) / SUM(od.SalesAmount)) * 100, 2) AS OverallProfitMarginPct
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered';

-- 3.6 Overall Average Order Value (AOV) across Delivered Orders
SELECT 
    ROUND(SUM(od.SalesAmount) / COUNT(DISTINCT o.OrderID), 2) AS AverageOrderValue
FROM Orders o
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered';

-- 3.7 Category-wise Revenue Breakdown
SELECT
    p.Category,
    ROUND(SUM(od.SalesAmount), 2) AS Revenue
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
JOIN Products p
    ON od.ProductID = p.ProductID
WHERE o.OrderStatus = 'Delivered'
GROUP BY p.Category
ORDER BY Revenue DESC;

-- 3.8 Category Revenue, Profit, and Profit Margin %
SELECT
    p.Category,
    ROUND(SUM(od.SalesAmount), 2) AS Revenue,
    ROUND(SUM(od.Profit), 2) AS Profit,
    ROUND(SUM(od.Profit) / SUM(od.SalesAmount) * 100, 2) AS ProfitMarginPct
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
JOIN Products p
    ON od.ProductID = p.ProductID
WHERE o.OrderStatus = 'Delivered'
GROUP BY p.Category
ORDER BY Revenue DESC;

-- 3.9 Monthly Sales Trend (Chronological)
SELECT
    YEAR(o.OrderDate) AS SalesYear,
    MONTH(o.OrderDate) AS SalesMonth,
    ROUND(SUM(od.SalesAmount), 2) AS MonthlyRevenue,
    ROUND(SUM(od.Profit), 2) AS MonthlyProfit
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY
    YEAR(o.OrderDate),
    MONTH(o.OrderDate)
ORDER BY
    SalesYear,
    SalesMonth;

-- 3.10 Region-wise Revenue & Profit Performance
SELECT 
    c.Region,
    COUNT(DISTINCT o.OrderID) AS OrderCount,
    ROUND(SUM(od.SalesAmount), 2) AS Revenue,
    ROUND(SUM(od.Profit), 2) AS Profit,
    ROUND((SUM(od.Profit) / SUM(od.SalesAmount)) * 100, 2) AS MarginPct
FROM Customers c
JOIN Orders o 
    ON c.CustomerID = o.CustomerID
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY c.Region
ORDER BY Revenue DESC;

-- 3.11 Top 10 Customers by Lifetime Value (Revenue)
SELECT
    c.CustomerID,
    c.CustomerName,
    c.City,
    c.Region,
    COUNT(DISTINCT o.OrderID) AS DeliveredOrders,
    ROUND(SUM(od.SalesAmount), 2) AS LifetimeRevenue,
    ROUND(SUM(od.Profit), 2) AS LifetimeProfit
FROM Customers c
JOIN Orders o
    ON c.CustomerID = o.CustomerID
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY c.CustomerID, c.CustomerName, c.City, c.Region
ORDER BY LifetimeRevenue DESC
LIMIT 10;

-- 3.12 Top 10 Best-Selling Products by Revenue
SELECT
    p.ProductID,
    p.ProductName,
    p.Category,
    SUM(od.Quantity) AS UnitsSold,
    ROUND(SUM(od.SalesAmount), 2) AS Revenue,
    ROUND(SUM(od.Profit), 2) AS Profit
FROM Products p
JOIN OrderDetails od
    ON p.ProductID = od.ProductID
JOIN Orders o
    ON od.OrderID = o.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY 
    p.ProductID,
    p.ProductName,
    p.Category
ORDER BY Revenue DESC
LIMIT 10;

-- 3.13 Payment Method Distribution
SELECT
    PaymentMethod,
    COUNT(*) AS TotalOrders,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Orders WHERE OrderStatus = 'Delivered'), 2) AS OrderPct
FROM Orders
WHERE OrderStatus = 'Delivered'
GROUP BY PaymentMethod
ORDER BY TotalOrders DESC;

-- 3.14 Return Reason Distribution
SELECT
    r.ReturnReason,
    COUNT(*) AS TotalReturns,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Returns), 2) AS ReasonPct
FROM Returns r
GROUP BY r.ReturnReason
ORDER BY TotalReturns DESC;

-- 3.15 Overall Store Return Rate %
SELECT
    COUNT(DISTINCT r.OrderID) AS ReturnedOrders,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    ROUND(COUNT(DISTINCT r.OrderID) * 100.0 / NULLIF(COUNT(DISTINCT o.OrderID), 0), 2) AS ReturnRatePct
FROM Orders o
LEFT JOIN Returns r
    ON o.OrderID = r.OrderID;


-- ====================================================================================
-- SECTION 4: CORE PROJECT RESEARCH - PROMOTIONAL DISCOUNT IMPACT & AOV ANALYSIS
-- ====================================================================================

-- 4.1 Order-Level Comparison: Discounted vs. Non-Discounted Orders (The Central Business Question)
-- Resolves the paradox: Do promotional discounts expand AOV and basket size while compressing margins?
WITH OrderLevelMetrics AS (
    SELECT 
        o.OrderID,
        o.CustomerID,
        MAX(od.DiscountPct) AS MaxDiscountPct,
        CASE 
            WHEN MAX(od.DiscountPct) > 0 THEN 'Discounted Order'
            ELSE 'Non-Discounted Order'
        END AS DiscountStatus,
        COUNT(od.OrderDetailID) AS DistinctItemsCount,
        SUM(od.Quantity) AS TotalUnitsSold,
        SUM(od.SalesAmount) AS OrderRevenue,
        SUM(od.Profit) AS OrderProfit
    FROM Orders o
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY o.OrderID, o.CustomerID
)
SELECT 
    DiscountStatus,
    COUNT(OrderID) AS TotalDeliveredOrders,
    ROUND(SUM(OrderRevenue), 2) AS TotalRevenue,
    ROUND(SUM(OrderProfit), 2) AS TotalProfit,
    ROUND(AVG(OrderRevenue), 2) AS AverageOrderValue_AOV,
    ROUND(AVG(OrderProfit), 2) AS AverageProfitPerOrder,
    ROUND(AVG(DistinctItemsCount), 2) AS AvgDistinctItemsPerOrder,
    ROUND(AVG(TotalUnitsSold), 2) AS AvgUnitsPerOrder,
    ROUND((SUM(OrderProfit) / SUM(OrderRevenue)) * 100, 2) AS RealizedGrossMarginPct
FROM OrderLevelMetrics
GROUP BY DiscountStatus;

-- 4.2 Promotional Discount Tier Deep-Dive (0%, 5%, 10%, 15%, 20%, 25%)
-- Evaluates transaction volume, margin compression, and profit realization across tiers
SELECT 
    od.DiscountPct,
    COUNT(DISTINCT od.OrderID) AS OrderCount,
    COUNT(od.OrderDetailID) AS LineItemCount,
    SUM(od.Quantity) AS TotalUnitsSold,
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(SUM(od.Profit), 2) AS TotalProfit,
    ROUND(AVG(od.SalesAmount), 2) AS AvgLineRevenue,
    ROUND((SUM(od.Profit) / NULLIF(SUM(od.SalesAmount), 0)) * 100, 2) AS GrossMarginPct
FROM OrderDetails od
JOIN Orders o 
    ON od.OrderID = o.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY od.DiscountPct
ORDER BY od.DiscountPct ASC;

-- 4.3 Margin Dilution & Negative Profit Audit (Loss-Making Transactions)
-- Identifies transactions where steep promotional discounting (20%-25%) caused net loss (Profit < 0)
SELECT 
    o.OrderID,
    o.OrderDate,
    p.ProductID,
    p.ProductName,
    p.Category,
    od.Quantity,
    p.CostPrice,
    p.SellingPrice,
    od.UnitPrice,
    od.DiscountPct,
    od.SalesAmount,
    od.Profit AS RealizedLoss
FROM OrderDetails od
JOIN Orders o 
    ON od.OrderID = o.OrderID
JOIN Products p 
    ON od.ProductID = p.ProductID
WHERE o.OrderStatus = 'Delivered'
  AND od.Profit < 0
ORDER BY od.Profit ASC;

-- 4.4 Basket Size Dynamics: Single-Item vs. Multi-Item Orders by Discount Status
-- Demonstrates how promotional discounts stimulate multi-item basket cross-selling
WITH OrderBasketSummary AS (
    SELECT 
        o.OrderID,
        CASE 
            WHEN MAX(od.DiscountPct) > 0 THEN 'Discounted'
            ELSE 'Non-Discounted'
        END AS DiscountType,
        COUNT(od.OrderDetailID) AS ItemsInBasket
    FROM Orders o
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY o.OrderID
)
SELECT 
    DiscountType,
    ItemsInBasket,
    COUNT(OrderID) AS OrderCount,
    ROUND(COUNT(OrderID) * 100.0 / SUM(COUNT(OrderID)) OVER (PARTITION BY DiscountType), 2) AS PctWithinGroup
FROM OrderBasketSummary
GROUP BY DiscountType, ItemsInBasket
ORDER BY DiscountType, ItemsInBasket;

-- 4.5 Category-Level Discount Sensitivity & Margin Comparison
-- Compares revenue and profit margin between discounted and full-price orders across categories
SELECT 
    p.Category,
    CASE 
        WHEN od.DiscountPct > 0 THEN 'Discounted' 
        ELSE 'Full Price' 
    END AS PricingType,
    COUNT(od.OrderDetailID) AS LineItemCount,
    SUM(od.Quantity) AS UnitsSold,
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(SUM(od.Profit), 2) AS TotalProfit,
    ROUND((SUM(od.Profit) / NULLIF(SUM(od.SalesAmount), 0)) * 100, 2) AS ProfitMarginPct
FROM OrderDetails od
JOIN Orders o 
    ON od.OrderID = o.OrderID
JOIN Products p 
    ON od.ProductID = p.ProductID
WHERE o.OrderStatus = 'Delivered'
GROUP BY p.Category, PricingType
ORDER BY p.Category, PricingType;


-- ====================================================================================
-- SECTION 5: CUSTOMER ANALYTICS, SEGMENTATION & RETENTION (RFM)
-- ====================================================================================

-- 5.1 RFM Customer Segmentation (Recency, Frequency, Monetary)
-- Classifies customer base into actionable behavioral tiers using NTILE window functions
WITH CustomerMetrics AS (
    SELECT 
        c.CustomerID,
        c.CustomerName,
        c.City,
        c.Region,
        DATEDIFF(
            (SELECT MAX(OrderDate) FROM Orders WHERE OrderStatus = 'Delivered'), 
            MAX(o.OrderDate)
        ) AS RecencyDays,
        COUNT(DISTINCT o.OrderID) AS FrequencyOrders,
        ROUND(SUM(od.SalesAmount), 2) AS MonetarySpend
    FROM Customers c
    JOIN Orders o 
        ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY c.CustomerID, c.CustomerName, c.City, c.Region
),
RFMScores AS (
    SELECT 
        CustomerID,
        CustomerName,
        City,
        Region,
        RecencyDays,
        FrequencyOrders,
        MonetarySpend,
        NTILE(5) OVER (ORDER BY RecencyDays DESC) AS R_Score,  -- 5 = Most Recent
        NTILE(5) OVER (ORDER BY FrequencyOrders ASC) AS F_Score, -- 5 = Highest Frequency
        NTILE(5) OVER (ORDER BY MonetarySpend ASC) AS M_Score   -- 5 = Highest Monetary Spend
    FROM CustomerMetrics
)
SELECT 
    CustomerID,
    CustomerName,
    City,
    Region,
    RecencyDays,
    FrequencyOrders,
    MonetarySpend,
    R_Score,
    F_Score,
    M_Score,
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions / VIP'
        WHEN F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 4 AND F_Score <= 2 THEN 'Recent New Customers'
        WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At-Risk High Value'
        WHEN R_Score <= 2 AND F_Score <= 2 THEN 'Hibernating / Churned'
        ELSE 'Potential Loyalist'
    END AS CustomerSegment
FROM RFMScores
ORDER BY MonetarySpend DESC;

-- 5.2 Customer Retention: Single-Time vs. Repeat Buyers Analysis
-- Evaluates customer lifetime value and store repeat purchase rate
WITH CustomerPurchaseCounts AS (
    SELECT 
        c.CustomerID,
        COUNT(DISTINCT o.OrderID) AS TotalDeliveredOrders,
        SUM(od.SalesAmount) AS TotalCustomerSpend
    FROM Customers c
    JOIN Orders o 
        ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY c.CustomerID
)
SELECT 
    CASE 
        WHEN TotalDeliveredOrders = 1 THEN '1 Order (One-Time Buyer)'
        WHEN TotalDeliveredOrders BETWEEN 2 AND 4 THEN '2-4 Orders (Repeat Buyer)'
        ELSE '5+ Orders (Frequent Buyer)'
    END AS BuyerSegment,
    COUNT(CustomerID) AS TotalCustomers,
    ROUND(COUNT(CustomerID) * 100.0 / (SELECT COUNT(*) FROM CustomerPurchaseCounts), 2) AS CustomerPct,
    ROUND(SUM(TotalCustomerSpend), 2) AS TotalRevenueGenerated,
    ROUND(SUM(TotalCustomerSpend) * 100.0 / (SELECT SUM(TotalCustomerSpend) FROM CustomerPurchaseCounts), 2) AS RevenuePct,
    ROUND(AVG(TotalCustomerSpend), 2) AS AvgSpendPerCustomer
FROM CustomerPurchaseCounts
GROUP BY 
    CASE 
        WHEN TotalDeliveredOrders = 1 THEN '1 Order (One-Time Buyer)'
        WHEN TotalDeliveredOrders BETWEEN 2 AND 4 THEN '2-4 Orders (Repeat Buyer)'
        ELSE '5+ Orders (Frequent Buyer)'
    END
ORDER BY TotalRevenueGenerated DESC;

-- 5.3 Customer Demographics Value Analysis (Age Groups & Gender Split)
-- Identifies highest-spending and highest-margin demographic segments
SELECT 
    CASE 
        WHEN c.Age < 25 THEN '18-24 (Gen Z)'
        WHEN c.Age BETWEEN 25 AND 34 THEN '25-34 (Young Professionals)'
        WHEN c.Age BETWEEN 35 AND 49 THEN '35-49 (Mid-Career)'
        ELSE '50+ (Seniors)'
    END AS AgeGroup,
    c.Gender,
    COUNT(DISTINCT c.CustomerID) AS CustomerCount,
    COUNT(DISTINCT o.OrderID) AS DeliveredOrders,
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(SUM(od.Profit), 2) AS TotalProfit,
    ROUND(SUM(od.SalesAmount) / COUNT(DISTINCT o.OrderID), 2) AS DemographicAOV,
    ROUND((SUM(od.Profit) / SUM(od.SalesAmount)) * 100, 2) AS ProfitMarginPct
FROM Customers c
JOIN Orders o 
    ON c.CustomerID = o.CustomerID
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY 
    CASE 
        WHEN c.Age < 25 THEN '18-24 (Gen Z)'
        WHEN c.Age BETWEEN 25 AND 34 THEN '25-34 (Young Professionals)'
        WHEN c.Age BETWEEN 35 AND 49 THEN '35-49 (Mid-Career)'
        ELSE '50+ (Seniors)'
    END,
    c.Gender
ORDER BY TotalRevenue DESC;

-- 5.4 Top Metro Cities by Revenue, Volume & Average Order Value
SELECT 
    c.City,
    c.Region,
    COUNT(DISTINCT c.CustomerID) AS UniqueCustomers,
    COUNT(DISTINCT o.OrderID) AS DeliveredOrders,
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(SUM(od.Profit), 2) AS TotalProfit,
    ROUND(SUM(od.SalesAmount) / COUNT(DISTINCT o.OrderID), 2) AS CityAOV,
    ROUND((SUM(od.Profit) / SUM(od.SalesAmount)) * 100, 2) AS ProfitMarginPct
FROM Customers c
JOIN Orders o 
    ON c.CustomerID = o.CustomerID
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY c.City, c.Region
ORDER BY TotalRevenue DESC;


-- ====================================================================================
-- SECTION 6: ADVANCED PRODUCT CATALOG & CROSS-SELLING (MARKET BASKET)
-- ====================================================================================

-- 6.1 Top 5 Best-Selling Products within Each Category (Window Function: DENSE_RANK)
WITH RankedProducts AS (
    SELECT 
        p.Category,
        p.ProductID,
        p.ProductName,
        SUM(od.Quantity) AS UnitsSold,
        ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
        ROUND(SUM(od.Profit), 2) AS TotalProfit,
        DENSE_RANK() OVER (
            PARTITION BY p.Category 
            ORDER BY SUM(od.SalesAmount) DESC
        ) AS CategoryRank
    FROM Products p
    JOIN OrderDetails od 
        ON p.ProductID = od.ProductID
    JOIN Orders o 
        ON od.OrderID = o.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY p.Category, p.ProductID, p.ProductName
)
SELECT 
    Category,
    CategoryRank,
    ProductID,
    ProductName,
    UnitsSold,
    TotalRevenue,
    TotalProfit
FROM RankedProducts
WHERE CategoryRank <= 5
ORDER BY Category, CategoryRank;

-- 6.2 Product SKU Return Rate & Defect Risk Analysis
-- Uncovers SKUs with disproportionately high return rates
WITH ProductOrderStats AS (
    SELECT 
        p.ProductID,
        p.ProductName,
        p.Category,
        COUNT(DISTINCT o.OrderID) AS TotalTimesOrdered,
        SUM(od.Quantity) AS TotalUnitsOrdered
    FROM Products p
    JOIN OrderDetails od 
        ON p.ProductID = od.ProductID
    JOIN Orders o 
        ON od.OrderID = o.OrderID
    GROUP BY p.ProductID, p.ProductName, p.Category
),
ProductReturnStats AS (
    SELECT 
        od.ProductID,
        COUNT(DISTINCT r.OrderID) AS TimesReturned,
        SUM(od.Quantity) AS ReturnedUnits
    FROM Returns r
    JOIN Orders o 
        ON r.OrderID = o.OrderID
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    GROUP BY od.ProductID
)
SELECT 
    pos.ProductID,
    pos.ProductName,
    pos.Category,
    pos.TotalTimesOrdered,
    COALESCE(prs.TimesReturned, 0) AS TimesReturned,
    ROUND(
        COALESCE(prs.TimesReturned, 0) * 100.0 / NULLIF(pos.TotalTimesOrdered, 0), 
        2
    ) AS ReturnRatePct
FROM ProductOrderStats pos
LEFT JOIN ProductReturnStats prs 
    ON pos.ProductID = prs.ProductID
ORDER BY ReturnRatePct DESC, pos.TotalTimesOrdered DESC;

-- 6.3 Market Basket Analysis: Cross-Category Affinity in Multi-Item Orders
-- Discovers which product categories are most frequently co-purchased together in the same cart
SELECT 
    od1.Category AS Category_A,
    od2.Category AS Category_B,
    COUNT(DISTINCT od1.OrderID) AS CoPurchaseFrequency
FROM (
    SELECT od.OrderID, p.Category, p.ProductID
    FROM OrderDetails od
    JOIN Products p ON od.ProductID = p.ProductID
    JOIN Orders o ON od.OrderID = o.OrderID
    WHERE o.OrderStatus = 'Delivered'
) od1
JOIN (
    SELECT od.OrderID, p.Category, p.ProductID
    FROM OrderDetails od
    JOIN Products p ON od.ProductID = p.ProductID
    JOIN Orders o ON od.OrderID = o.OrderID
    WHERE o.OrderStatus = 'Delivered'
) od2
    ON od1.OrderID = od2.OrderID
   AND od1.Category < od2.Category
GROUP BY od1.Category, od2.Category
ORDER BY CoPurchaseFrequency DESC;


-- ====================================================================================
-- SECTION 7: TIME-SERIES, MOM GROWTH & SEASONALITY (WINDOW FUNCTIONS)
-- ====================================================================================

-- 7.1 Month-over-Month (MoM) Revenue & Profit Growth Rate (Window Function: LAG)
WITH MonthlySales AS (
    SELECT 
        DATE_FORMAT(o.OrderDate, '%Y-%m') AS YearMonth,
        ROUND(SUM(od.SalesAmount), 2) AS MonthlyRevenue,
        ROUND(SUM(od.Profit), 2) AS MonthlyProfit,
        COUNT(DISTINCT o.OrderID) AS MonthlyOrders
    FROM Orders o
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY DATE_FORMAT(o.OrderDate, '%Y-%m')
)
SELECT 
    YearMonth,
    MonthlyOrders,
    MonthlyRevenue,
    LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth) AS PrevMonthRevenue,
    ROUND(
        MonthlyRevenue - LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth), 
        2
    ) AS MoM_AbsoluteRevenueChange,
    ROUND(
        (MonthlyRevenue - LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth)) * 100.0 / 
        NULLIF(LAG(MonthlyRevenue, 1) OVER (ORDER BY YearMonth), 0), 
        2
    ) AS MoM_RevenueGrowthPct,
    MonthlyProfit,
    ROUND(
        (MonthlyProfit - LAG(MonthlyProfit, 1) OVER (ORDER BY YearMonth)) * 100.0 / 
        NULLIF(LAG(MonthlyProfit, 1) OVER (ORDER BY YearMonth), 0), 
        2
    ) AS MoM_ProfitGrowthPct
FROM MonthlySales
ORDER BY YearMonth;

-- 7.2 Cumulative (Running Total) Revenue & Profit Across Time (Window Function: SUM OVER)
WITH MonthlyTotals AS (
    SELECT 
        DATE_FORMAT(o.OrderDate, '%Y-%m') AS SalesMonth,
        ROUND(SUM(od.SalesAmount), 2) AS Revenue,
        ROUND(SUM(od.Profit), 2) AS Profit
    FROM Orders o
    JOIN OrderDetails od 
        ON o.OrderID = od.OrderID
    WHERE o.OrderStatus = 'Delivered'
    GROUP BY DATE_FORMAT(o.OrderDate, '%Y-%m')
)
SELECT 
    SalesMonth,
    Revenue,
    Profit,
    ROUND(SUM(Revenue) OVER (ORDER BY SalesMonth ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS CumulativeRevenue,
    ROUND(SUM(Profit) OVER (ORDER BY SalesMonth ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS CumulativeProfit
FROM MonthlyTotals
ORDER BY SalesMonth;

-- 7.3 Day-of-the-Week Purchasing Patterns & Peak Volume Days
SELECT 
    DAYNAME(o.OrderDate) AS DayOfWeek,
    DAYOFWEEK(o.OrderDate) AS DayIndex, -- 1=Sunday, 2=Monday, ..., 7=Saturday
    COUNT(DISTINCT o.OrderID) AS TotalDeliveredOrders,
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(AVG(od.SalesAmount), 2) AS AvgLineRevenue,
    ROUND(SUM(od.SalesAmount) / COUNT(DISTINCT o.OrderID), 2) AS DayAOV
FROM Orders o
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY DAYNAME(o.OrderDate), DAYOFWEEK(o.OrderDate)
ORDER BY DayIndex;

-- 7.4 Quarterly Business Performance & Profit Margins
SELECT 
    YEAR(o.OrderDate) AS SalesYear,
    QUARTER(o.OrderDate) AS SalesQuarter,
    COUNT(DISTINCT o.OrderID) AS TotalDeliveredOrders,
    ROUND(SUM(od.SalesAmount), 2) AS TotalRevenue,
    ROUND(SUM(od.Profit), 2) AS TotalProfit,
    ROUND((SUM(od.Profit) / SUM(od.SalesAmount)) * 100, 2) AS ProfitMarginPct
FROM Orders o
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY YEAR(o.OrderDate), QUARTER(o.OrderDate)
ORDER BY SalesYear, SalesQuarter;


-- ====================================================================================
-- SECTION 8: OPERATIONS, FULFILLMENT & PAYMENT METHOD RISK
-- ====================================================================================

-- 8.1 Regional Order Fulfillment Funnel (Delivered vs Cancelled vs Returned)
SELECT 
    c.Region,
    COUNT(o.OrderID) AS TotalOrdersPlaced,
    SUM(CASE WHEN o.OrderStatus = 'Delivered' THEN 1 ELSE 0 END) AS DeliveredOrders,
    SUM(CASE WHEN o.OrderStatus = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledOrders,
    SUM(CASE WHEN o.OrderStatus = 'Returned' THEN 1 ELSE 0 END) AS ReturnedOrders,
    ROUND(SUM(CASE WHEN o.OrderStatus = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.OrderID), 2) AS CancellationRatePct,
    ROUND(SUM(CASE WHEN o.OrderStatus = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.OrderID), 2) AS ReturnRatePct
FROM Customers c
JOIN Orders o 
    ON c.CustomerID = o.CustomerID
GROUP BY c.Region
ORDER BY TotalOrdersPlaced DESC;

-- 8.2 Payment Channel Risk & Cancellation/Return Sensitivity
-- Compares return and cancellation risks between Cash on Delivery (COD) and Digital Channels
SELECT 
    o.PaymentMethod,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(CASE WHEN o.OrderStatus = 'Delivered' THEN 1 ELSE 0 END) AS DeliveredOrders,
    SUM(CASE WHEN o.OrderStatus = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledOrders,
    SUM(CASE WHEN o.OrderStatus = 'Returned' THEN 1 ELSE 0 END) AS ReturnedOrders,
    ROUND(SUM(CASE WHEN o.OrderStatus = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.OrderID), 2) AS CancellationRatePct,
    ROUND(SUM(CASE WHEN o.OrderStatus = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.OrderID), 2) AS ReturnRatePct,
    ROUND(SUM(CASE WHEN o.OrderStatus = 'Delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(o.OrderID), 2) AS DeliverySuccessRatePct
FROM Orders o
GROUP BY o.PaymentMethod
ORDER BY TotalOrders DESC;

-- 8.3 Return Reason Distribution Across Product Categories
SELECT 
    p.Category,
    r.ReturnReason,
    COUNT(r.ReturnID) AS TotalReturnCount,
    ROUND(COUNT(r.ReturnID) * 100.0 / SUM(COUNT(r.ReturnID)) OVER (PARTITION BY p.Category), 2) AS PctWithinCategory
FROM Returns r
JOIN Orders o 
    ON r.OrderID = o.OrderID
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
JOIN Products p 
    ON od.ProductID = p.ProductID
GROUP BY p.Category, r.ReturnReason
ORDER BY p.Category, TotalReturnCount DESC;


-- ====================================================================================
-- SECTION 9: REUSABLE ANALYTICAL VIEW (FOR BI DASHBOARDS & ML PIPELINE)
-- ====================================================================================

-- 9.1 Create Master Analytical View: Order-Level Summary
-- Pre-aggregates lines to the order-level analytical unit matching the project's ML & EDA pipeline
CREATE OR REPLACE VIEW vw_order_analytics_master AS
SELECT 
    o.OrderID,
    o.OrderDate,
    YEAR(o.OrderDate) AS OrderYear,
    MONTH(o.OrderDate) AS OrderMonth,
    DAYNAME(o.OrderDate) AS OrderDayOfWeek,
    o.CustomerID,
    c.CustomerName,
    c.Gender,
    c.Age,
    c.City,
    c.Region,
    o.PaymentMethod,
    o.OrderStatus,
    COUNT(od.OrderDetailID) AS CartItemCount,
    SUM(od.Quantity) AS TotalUnitsSold,
    MAX(od.DiscountPct) AS MaxDiscountPct,
    ROUND(AVG(od.DiscountPct), 2) AS AvgDiscountPct,
    CASE 
        WHEN MAX(od.DiscountPct) > 0 THEN 1 
        ELSE 0 
    END AS HasDiscountFlag,
    ROUND(SUM(od.UnitPrice * od.Quantity), 2) AS GrossSalesAmount,
    ROUND(SUM(od.SalesAmount), 2) AS RealizedOrderRevenue,
    ROUND(SUM(od.Profit), 2) AS RealizedOrderProfit,
    ROUND((SUM(od.Profit) / NULLIF(SUM(od.SalesAmount), 0)) * 100, 2) AS OrderProfitMarginPct,
    CASE 
        WHEN r.ReturnID IS NOT NULL THEN 1 
        ELSE 0 
    END AS IsReturnedFlag,
    r.ReturnReason
FROM Orders o
JOIN Customers c 
    ON o.CustomerID = c.CustomerID
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
LEFT JOIN Returns r 
    ON o.OrderID = r.OrderID
GROUP BY 
    o.OrderID,
    o.OrderDate,
    o.CustomerID,
    c.CustomerName,
    c.Gender,
    c.Age,
    c.City,
    c.Region,
    o.PaymentMethod,
    o.OrderStatus,
    r.ReturnID,
    r.ReturnReason;

-- 9.2 Sample check on Master Analytical View
SELECT * FROM vw_order_analytics_master LIMIT 10;
