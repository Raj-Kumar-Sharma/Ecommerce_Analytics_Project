-- 1. Total revenue per category

SELECT 
    p.category, 
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))), 2) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;


-- 2. Top 10 customers by total order value

SELECT 
    c.customer_id, 
    c.customer_name, 
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))), 2) AS total_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_order_value DESC
LIMIT 10;

-- 3. Month-wise order count for the last 12 months

SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS order_month, 
    COUNT(DISTINCT order_id) AS total_orders
FROM orders
WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY order_month
ORDER BY order_month ASC;

-- 4. Customers who placed orders but never had an item delivered

SELECT 
    c.customer_id, 
    c.customer_name, 
    COUNT(o.order_id) AS total_orders_placed
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING SUM(CASE WHEN o.status = 'DELIVERED' THEN 1 ELSE 0 END) = 0;

-- 5. Products with more returns than purchases

SELECT 
    p.product_id, 
    p.product_name,
    SUM(CASE WHEN oi.quantity > 0 THEN oi.quantity ELSE 0 END) AS total_purchased,
    ABS(SUM(CASE WHEN oi.quantity < 0 THEN oi.quantity ELSE 0 END)) AS total_returned
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
HAVING SUM(oi.quantity) < 0;

-- 6. Return rate per category

SELECT 
    p.category,
    ABS(SUM(CASE WHEN oi.quantity < 0 THEN oi.quantity ELSE 0 END)) AS returned_items,
    SUM(CASE WHEN oi.quantity > 0 THEN oi.quantity ELSE 0 END) AS purchased_items,
    ROUND(
        (ABS(SUM(CASE WHEN oi.quantity < 0 THEN oi.quantity ELSE 0 END)) / 
        NULLIF(SUM(CASE WHEN oi.quantity > 0 THEN oi.quantity ELSE 0 END), 0)) * 100, 
    2) AS return_rate_percentage
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY return_rate_percentage DESC;


-- 7. Total revenue per customer, per category, per month

SELECT 
    c.customer_id,
    p.category,
    DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))), 2) AS total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY c.customer_id, p.category, order_month
ORDER BY c.customer_id, order_month, total_revenue DESC;


-- 8. Top products by quantity sold and revenue

SELECT 
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS net_quantity_sold,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))), 2) AS total_revenue
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_revenue DESC, net_quantity_sold DESC
LIMIT 10;

-- 9. Average Order Value (AOV) by customer segment

WITH OrderTotals AS (
    SELECT 
        o.order_id,
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - (oi.discount_percent / 100))) AS order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.customer_id
)
SELECT 
    c.customer_type AS customer_segment,
    COUNT(DISTINCT ot.order_id) AS total_orders,
    ROUND(AVG(ot.order_value), 2) AS avg_order_value
FROM customers c
JOIN OrderTotals ot ON c.customer_id = ot.customer_id
GROUP BY c.customer_type
ORDER BY avg_order_value DESC;






