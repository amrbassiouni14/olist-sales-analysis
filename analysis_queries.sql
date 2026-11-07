-- Olist E-Commerce Analysis: business questions answered with SQL (SQLite)
-- Techniques: JOINs, GROUP BY, CTEs, window functions (LAG, SUM OVER), CASE


-- Q1. How did monthly revenue change over time?
WITH monthly AS (
    SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
           COUNT(DISTINCT o.order_id)                     AS orders,
           ROUND(SUM(i.price), 2)                         AS revenue
    FROM orders o
    JOIN order_items i ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT month,
       orders,
       revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;


-- Q2. Which 10 product categories bring the most revenue?
SELECT p.category,
       COUNT(DISTINCT i.order_id)                                AS orders,
       ROUND(SUM(i.price), 2)                                    AS revenue,
       ROUND(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER (), 1) AS revenue_share_pct
FROM order_items i
JOIN orders   o ON i.order_id   = o.order_id
JOIN products p ON i.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY p.category
ORDER BY revenue DESC
LIMIT 10;


-- Q3. Do late deliveries lower customer review scores?
WITH deliveries AS (
    SELECT o.order_id,
           julianday(date(o.order_delivered_customer_date))
         - julianday(date(o.order_estimated_delivery_date)) AS days_late,
           r.review_score
    FROM orders o
    JOIN reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT CASE
           WHEN days_late <= 0  THEN '1. On time'
           WHEN days_late <= 7  THEN '2. 1-7 days late'
           WHEN days_late <= 14 THEN '3. 8-14 days late'
           ELSE                      '4. 15+ days late'
       END                                        AS delivery_status,
       COUNT(*)                                   AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders,
       ROUND(AVG(review_score), 2)                AS avg_review_score,
       ROUND(100.0 * AVG(review_score <= 2), 1)   AS pct_bad_reviews
FROM deliveries
GROUP BY delivery_status
ORDER BY delivery_status;


-- Q4. How many customers come back and buy again?
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS n_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT CASE
           WHEN n_orders = 1 THEN '1 order'
           WHEN n_orders = 2 THEN '2 orders'
           ELSE '3+ orders'
       END                                                 AS customer_group,
       COUNT(*)                                            AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct_of_customers
FROM customer_orders
GROUP BY customer_group
ORDER BY customer_group;


-- Q5. Which payment methods do customers use most?
SELECT payment_type,
       COUNT(DISTINCT order_id)                         AS orders,
       ROUND(100.0 * COUNT(DISTINCT order_id)
             / (SELECT COUNT(DISTINCT order_id) FROM payments), 1) AS pct_of_orders,
       ROUND(SUM(payment_value), 2)                     AS total_value,
       ROUND(AVG(payment_installments), 1)              AS avg_installments
FROM payments
WHERE payment_type <> 'not_defined'
GROUP BY payment_type
ORDER BY orders DESC;
