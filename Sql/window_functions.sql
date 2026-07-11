-- 1. Rank Customers by Lifetime Value (LTV)

WITH CustomerLTV AS (
    SELECT 
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS lifetime_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT 
    c.customer_id,
    c.customer_name,
    ROUND(ltv.lifetime_value, 2) AS lifetime_value,
    RANK() OVER (ORDER BY ltv.lifetime_value DESC) AS ltv_rank,
    DENSE_RANK() OVER (ORDER BY ltv.lifetime_value DESC) AS ltv_dense_rank
FROM CustomerLTV ltv
JOIN customers c ON ltv.customer_id = c.customer_id
ORDER BY ltv_rank;


-- 2. Running Totals and Moving Averages

WITH DailyRevenue AS (
    SELECT 
        DATE(o.order_date) AS order_date,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS daily_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE(o.order_date)
)
SELECT 
    order_date,
    ROUND(daily_revenue, 2) AS daily_revenue,
    
    -- Cumulative running total of revenue over time
    ROUND(SUM(daily_revenue) OVER (
        ORDER BY order_date
    ), 2) AS running_total_revenue,
    
    -- 7-Day Moving Average (current row + previous 6 rows)
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY order_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS 7_day_moving_avg
FROM DailyRevenue
ORDER BY order_date;

-- 3. Multi-Step Aggregations: Month-over-Month (MoM) Growth Rate

WITH MonthlyRevenue AS (
    -- Step 1: Calculate total revenue per month
    SELECT 
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS current_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY order_month
),
RevenueWithLag AS (
    -- Step 2: Use LAG() to get the previous month's revenue
    SELECT 
        order_month,
        current_revenue,
        LAG(current_revenue) OVER (ORDER BY order_month) AS previous_month_revenue
    FROM MonthlyRevenue
)
-- Step 3: Calculate the growth rate percentage
SELECT 
    order_month,
    ROUND(current_revenue, 2) AS current_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        ((current_revenue - previous_month_revenue) / previous_month_revenue) * 100, 
    2) AS mom_growth_rate_percentage
FROM RevenueWithLag
ORDER BY order_month;

-- ==============================================================================
-- 1. Days Between Consecutive Orders & "At Risk" Flag
-- ==============================================================================
WITH OrderGaps AS (
    SELECT 
        customer_id, 
        DATE(order_date) AS order_date,
        DATE(LAG(order_date) OVER (
            PARTITION BY customer_id 
            ORDER BY order_date
        )) AS previous_order_date
    FROM orders
),
GapCalculations AS (
    SELECT 
        customer_id, 
        order_date, 
        previous_order_date,
        DATEDIFF(order_date, previous_order_date) AS days_gap
    FROM OrderGaps
),
CustomerAverages AS (
    SELECT 
        customer_id, 
        AVG(days_gap) AS avg_days_gap
    FROM GapCalculations
    WHERE days_gap IS NOT NULL
    GROUP BY customer_id
)
SELECT 
    gc.customer_id, 
    gc.order_date, 
    gc.previous_order_date, 
    gc.days_gap,
    CASE 
        WHEN ca.avg_days_gap > 30 THEN 'At Risk' 
        ELSE 'Healthy' 
    END AS risk_status
FROM GapCalculations gc
JOIN CustomerAverages ca ON gc.customer_id = ca.customer_id
ORDER BY gc.customer_id, gc.order_date;

-- ==============================================================================
-- 2. Customer Segmentation by Monthly Revenue (Multi-Level CTE)
-- ==============================================================================
WITH MonthlyRevenuePerCustomer AS (
    SELECT 
        o.customer_id,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id, order_month
),
CategorizedCustomers AS (
    SELECT 
        customer_id,
        order_month,
        CASE 
            WHEN monthly_revenue > 10000 THEN 'High'
            WHEN monthly_revenue >= 5000 THEN 'Medium'
            ELSE 'Low' 
        END AS spend_category
    FROM MonthlyRevenuePerCustomer
)
SELECT 
    order_month,
    spend_category,
    COUNT(customer_id) AS customer_count
FROM CategorizedCustomers
GROUP BY order_month, spend_category
ORDER BY order_month, spend_category;

-- ==============================================================================
-- 3. Quartiles Based on Lifetime Value (NTILE)
-- ==============================================================================
WITH CustomerLTV AS (
    SELECT 
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS total_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
),
CustomerQuartiles AS (
    SELECT 
        customer_id,
        ROUND(total_value, 2) AS total_value,
        NTILE(4) OVER (ORDER BY total_value DESC) AS quartile
    FROM CustomerLTV
)
SELECT 
    customer_id,
    total_value,
    quartile,
    CASE quartile
        WHEN 1 THEN 'Platinum'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Silver'
        WHEN 4 THEN 'Bronze'
    END AS quartile_label
FROM CustomerQuartiles
ORDER BY quartile, total_value DESC;

-- ==============================================================================
-- 4. Year-over-Year (YoY) Monthly Revenue Comparison
-- ==============================================================================
WITH MonthlySales AS (
    SELECT 
        YEAR(o.order_date) AS sales_year, 
        MONTH(o.order_date) AS sales_month,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS revenue
    FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY sales_year, sales_month
),
YoY_Comparison AS (
    SELECT 
        sales_year, 
        sales_month, 
        revenue,
        LAG(revenue) OVER (
            PARTITION BY sales_month 
            ORDER BY sales_year
        ) AS prev_year_revenue
    FROM MonthlySales
)
SELECT 
    sales_year AS year, 
    sales_month AS month, 
    ROUND(revenue, 2) AS revenue, 
    ROUND(IFNULL(prev_year_revenue, 0), 2) AS prev_year_revenue,
    CASE 
        WHEN prev_year_revenue IS NULL OR prev_year_revenue = 0 THEN 'N/A'
        ELSE CONCAT(ROUND(((revenue - prev_year_revenue) / prev_year_revenue) * 100, 2), '%') 
    END AS yoy_growth_percent
FROM YoY_Comparison
ORDER BY sales_month, sales_year;

-- ==============================================================================
-- 5. First and Last Purchased Category (Category Shift Flag)
-- ==============================================================================
-- Uses ROW_NUMBER to safely isolate the absolute first and absolute last item purchased
WITH OrderedItems AS (
    SELECT 
        o.customer_id,
        p.category,
        o.order_date,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.order_date ASC, oi.item_id ASC
        ) AS first_item_rank,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.order_date DESC, oi.item_id DESC
        ) AS last_item_rank
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
),
FirstLastCategories AS (
    SELECT 
        customer_id,
        MAX(CASE WHEN first_item_rank = 1 THEN category END) AS first_category,
        MAX(CASE WHEN last_item_rank = 1 THEN category END) AS most_recent_category
    FROM OrderedItems
    GROUP BY customer_id
)
SELECT 
    customer_id,
    first_category,
    most_recent_category,
    CASE 
        WHEN first_category != most_recent_category THEN 'Yes' 
        ELSE 'No' 
    END AS category_shift
FROM FirstLastCategories
ORDER BY customer_id;

-- ==============================================================================
-- 6. Cumulative Revenue & Percentage (Pareto Analysis)
-- ==============================================================================
WITH CustomerRevenue AS (
    SELECT 
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
),
CumulativeCalculation AS (
    SELECT 
        customer_id,
        revenue,
        -- Running total sorted by top spenders
        SUM(revenue) OVER (
            ORDER BY revenue DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,
        -- Grand total across the entire business
        SUM(revenue) OVER () AS grand_total_revenue
    FROM CustomerRevenue
)
SELECT 
    customer_id,
    ROUND(revenue, 2) AS revenue,
    ROUND(cumulative_revenue, 2) AS cumulative_revenue,
    ROUND((cumulative_revenue / grand_total_revenue) * 100, 2) AS cumulative_percent
FROM CumulativeCalculation
ORDER BY revenue DESC;


