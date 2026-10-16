create database ecommerce;
use ecommerce;

-- customers table
CREATE TABLE Customers (
    CustomerID VARCHAR(10) PRIMARY KEY,
    CustomerName VARCHAR(100),
    Gender VARCHAR(20),
    Age INT,
    City VARCHAR(50),
    Region VARCHAR(30),
    SignupDate DATE
);

-- products table
CREATE TABLE Products (
    ProductID VARCHAR(10) PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50),
    CostPrice DECIMAL(12 , 2 ),
    SellingPrice DECIMAL(12 , 2 )
);

-- Orders Table
CREATE TABLE Orders (
    OrderID VARCHAR(10) PRIMARY KEY,
    OrderDate DATE,
    CustomerID VARCHAR(10),
    PaymentMethod VARCHAR(30),
    OrderStatus VARCHAR(20),
    FOREIGN KEY (CustomerID)
        REFERENCES Customers (CustomerID)
);

-- OrderDetails
CREATE TABLE OrderDetails
(
    OrderDetailID VARCHAR(12) PRIMARY KEY,
    OrderID VARCHAR(10),
    ProductID VARCHAR(10),
    Quantity INT,
    UnitPrice DECIMAL(12,2),
    DiscountPct DECIMAL(5,2),
    SalesAmount DECIMAL(14,2),
    Profit DECIMAL(14,2),
    
    FOREIGN KEY (OrderID)
REFERENCES Orders (OrderID),
FOREIGN KEY (ProductID)
REFERENCES Products (ProductID)
);

-- Returns
CREATE TABLE Returns
(
ReturnID VARCHAR(10) PRIMARY KEY,
OrderID VARCHAR(10),
ReturnDate DATE,
ReturnReason VARCHAR(50),
FOREIGN KEY (OrderID)
REFERENCES Orders (OrderID)
);

-- check table
show tables;

-- show all data in the table
select * from customers limit 10;
select * from orderdetails limit 5;
select * from orders limit 5;
select * from products limit 5;
select * from returns limit 5;


-- row count 
select count(*) from customers;
select count(*) from orderdetails;
select count(*) from orders;
select count(*) from products;
select count(*) from returns;

-- check duplicates
select customerid, count(*) as DuplicateCount
from Customers
group by customerid
having count(*)>1;

select productid, count(*) as DuplicateCount
from products
group by productid
having count(*)>1;

-- check null values

select
SUM(CustomerID IS NULL) AS CustomerID_Null,
SUM(CustomerName IS NULL) AS CustomerName_Null,
SUM(Gender IS NULL) AS Gender_Null,
SUM(Age IS NULL) AS Age_Null,
SUM(City IS NULL) AS City_Null,
SUM(Region IS NULL) AS Region_Null,
SUM(SignupDate IS NULL) AS SignupDate_Null
FROM Customers;

-- Foreign Key Validation
select o.orderid,o.customerid
from orders o
left join customers c
on o.customerid = c.customerid
where c.customerid is null;

-- orderdetails validation
SELECT od.OrderID
FROM OrderDetails od
LEFT JOIN Orders o
ON od.OrderID = o.OrderID
WHERE o. OrderID IS NULL;

-- product validation
SELECT od.ProductID
FROM OrderDetails od
LEFT JOIN Products p
ON od.ProductID = p.ProductID
WHERE p.ProductID IS NULL;

-- Basic Business Data Check
SELECT
MIN(OrderDate) AS FirstOrderDate,
MAX(OrderDate) AS LastOrderDate,
COUNT(DISTINCT CustomerID) AS UniqueCustomers
FROM Orders;


-- Order Status Analysis
 select
orderstatus, count(*) as TotalOrders
from orders
group by orderstatus;

-- Delivered Orders
SELECT COUNT(*) AS Deliveredorders
FROM orders
WHERE orderstatus = 'delivered';


-- Total Revenue
select
    sum(od.salesAmount) as TotalRevenue
from orders o
join orderdetails od
    on o.orderid = od.orderid
where o.orderstatus = 'delivered';


-- Total Profit
select 
    sum(od.profit) as Totalprofit
from orders o
join orderdetails od
    on o.orderid = od.orderid
where o.orderstatus = 'delivered';


-- Revenue + Profit Together
SELECT
    SUM(od.SalesAmount) AS TotalRevenue,
    SUM(od.Profit) AS TotalProfit
FROM Orders o
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered';

-- Average Order Value
SELECT 
    SUM(od.SalesAmount) / COUNT(DISTINCT o.OrderID) AS AverageOrderValue
FROM Orders o
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered';



-- Category-wise Revenue
select
p.category, sum(od.SalesAmount) as Revenue
from orders o
join orderdetails od
on o.orderid = od.orderid
join products p
on od.productid = p.productid
where o.orderstatus = 'delivered'
group by p.category
order by revenue desc;




-- Category Revenue + Profit
SELECT
p.Category,
SUM(od.SalesAmount) AS Revenue,
SUM(od.Profit) AS Profit,
SUM(od.Profit) / SUM(od.SalesAmount) * 100 AS ProfitMarginPct
FROM Orders o
JOIN OrderDetails od
ON o.OrderID = od. OrderID
JOIN Products p
ON od.ProductID = p.ProductID
WHERE o.OrderStatus = 'Delivered'
GROUP BY P.Category
ORDER BY Revenue DESC;



-- Monthly Sales Trend
SELECT
YEAR(o.OrderDate) AS SalesYear,
MONTH(o.OrderDate) AS SalesMonth,
SUM(od.SalesAmount) AS Revenue
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


-- Region-wise Revenue
SELECT 
    c.Region,
    SUM(od.SalesAmount) AS Revenue,
    SUM(od.Profit) AS Profit
FROM Customers c
JOIN Orders o 
    ON c.CustomerID = o.CustomerID
JOIN OrderDetails od 
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY c.Region
ORDER BY Revenue DESC;



-- Top 10 Customers
SELECT
    c.CustomerID,
    c.CustomerName,
    SUM(od.SalesAmount) AS Revenue,
    SUM(od.Profit) AS Profit
FROM Customers c
JOIN Orders o
    ON c.CustomerID = o.CustomerID
JOIN OrderDetails od
    ON o.OrderID = od.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY c.CustomerID, c.CustomerName
ORDER BY Revenue DESC
LIMIT 10;



-- Top 10 products
SELECT
    p.ProductID,
    p.ProductName,
    p.Category,
    SUM(od.Quantity) AS UnitsSold,
    SUM(od.SalesAmount) AS Revenue,
    SUM(od.Profit) AS Profit
FROM Products p
JOIN OrderDetails od
    ON p.ProductID = od.ProductID
JOIN Orders o
    ON od.OrderID = o.OrderID
WHERE o.OrderStatus = 'Delivered'
GROUP BY 
    p.ProductID,
    p.ProductName,
    p.Category;
    
    
 
 
 
 -- Payment Method Analysis
SELECT
    PaymentMethod,
    COUNT(*) AS TotalOrders
FROM Orders
WHERE OrderStatus = 'Delivered'
GROUP BY PaymentMethod
ORDER BY TotalOrders DESC;

 
 -- Return Analysis
SELECT
r.ReturnReason,
COUNT(*) AS TotalReturns
FROM Returns r
GROUP BY r. ReturnReason
ORDER BY TotalReturns DESC;




-- Return Rate (Fixed)
SELECT
    COUNT(DISTINCT r.OrderID) AS ReturnedOrders,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    -- Multiply by 100.0 first to handle decimals, and use NULLIF to prevent division by zero
    COUNT(DISTINCT r.OrderID) * 100.0 / 
        NULLIF(COUNT(DISTINCT o.OrderID), 0) AS ReturnRatePct
FROM Orders o
LEFT JOIN Returns r
    ON o.OrderID = r.OrderID;
    
    
    
















 
 
 
 
 
 
 
 
 
 
 
 
 













































































































































































