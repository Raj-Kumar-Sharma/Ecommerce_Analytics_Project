-- ==============================================================================
-- E-Commerce Analytics: Step 6 - Cohort & Retention Analysis
-- ==============================================================================


-- ==============================================================================
-- 1. Monthly Cohort Retention Analysis
-- Groups customers by their first purchase month and tracks their repeat purchases
-- ==============================================================================
WITH CustomerCohorts AS (
    -- Step 1: Find the first purchase month for each customer
    SELECT 
        customer_id,
        DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM orders
    GROUP BY customer_id
),
OrderMonths AS (
    -- Step 2: Extract the month for every order a customer placed
    SELECT 
        o.customer_id,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month,
        c.cohort_month
    FROM orders o
    JOIN CustomerCohorts c ON o.customer_id = c.customer_id
),
CohortActivity AS (
    -- Step 3: Calculate the month offset (0 = first month, 1 = next month, etc.)
    SELECT 
        cohort_month,
        TIMESTAMPDIFF(MONTH, cohort_month, order_month) AS month_index,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM OrderMonths
    GROUP BY cohort_month, month_index
),
CohortSize AS (
    -- Step 4: Get the initial size of each cohort (Month 0)
    SELECT 
        cohort_month,
        active_customers AS initial_size
    FROM CohortActivity
    WHERE month_index = 0
)
-- Step 5: Calculate retention rate percentages
SELECT 
    ca.cohort_month,
    cs.initial_size,
    ca.month_index,
    ca.active_customers,
    ROUND((ca.active_customers / cs.initial_size) * 100, 2) AS retention_rate_percentage
FROM CohortActivity ca
JOIN CohortSize cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.month_index;


-- ==============================================================================
-- 2. Churned vs Repeat Customer Identification
-- Identifies if a customer is one-time, active repeat, or churned repeat
-- ==============================================================================
WITH CustomerActivity AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        COUNT(o.order_id) AS total_orders,
        MAX(o.order_date) AS last_order_date,
        -- Calculate days since their last order compared to the most recent order in the entire database
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS days_since_last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT 
    customer_id,
    customer_name,
    total_orders,
    DATE(last_order_date) AS last_order_date,
    days_since_last_order,
    CASE 
        WHEN total_orders = 1 THEN 'One-Time Buyer (Churned)'
        WHEN total_orders > 1 AND days_since_last_order > 180 THEN 'Repeat Buyer (Churned - Inactive > 6 months)'
        WHEN total_orders > 1 AND days_since_last_order <= 180 THEN 'Active Repeat Buyer'
        ELSE 'Unknown'
    END AS customer_status
FROM CustomerActivity
ORDER BY days_since_last_order ASC;


-- ==============================================================================
-- 3. Overall Customer Base Composition
-- Aggregates the customer statuses to show total base composition
-- ==============================================================================
WITH CustomerStatus AS (
    SELECT 
        c.customer_id,
        COUNT(o.order_id) AS total_orders,
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS days_since_last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
)
SELECT 
    CASE 
        WHEN total_orders = 1 THEN 'One-Time Buyer (Churned)'
        WHEN total_orders > 1 AND days_since_last_order > 180 THEN 'Repeat Buyer (Churned - Inactive > 6 months)'
        WHEN total_orders > 1 AND days_since_last_order <= 180 THEN 'Active Repeat Buyer'
    END AS status_category,
    COUNT(customer_id) AS total_customers,
    ROUND(COUNT(customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM orders) * 100, 2) AS percentage_of_base
FROM CustomerStatus
GROUP BY status_category
ORDER BY total_customers DESC;