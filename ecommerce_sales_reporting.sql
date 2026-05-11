-- PROJECT : E-Commerce Sales Performance & Inventory Reporting
--
-- BUSINESS PROBLEM
-- ----------------
-- An e-commerce retailer needed structured visibility into sales performance
-- across product categories, regional markets, and time periods. Inventory
-- stockouts were causing missed revenue but were not being tracked
-- systematically. Reporting relied on manual spreadsheet exports with no
-- single source of truth.
--
-- TECHNICAL CONTRIBUTION
-- ----------------------
-- Designed a normalised relational schema (customers, products, orders,
-- order_items, inventory). Populated tables with representative sample data
-- and wrote a suite of analytical SQL queries covering:
--   · Revenue segmentation by category, region, and month
--   · Customer cohort retention (first purchase to repeat)
--   · Top-performing SKUs and slow-movers
--   · Inventory depletion velocity and reorder alerts
--
-- OUTCOME
-- -------
-- Provided the foundation for a Tableau dashboard that
-- surfaced the top 3 revenue-driving categories and identified 8 SKUs with
-- stock levels below 14-day demand, enabling proactive reorder decisions.
-- =============================================================================


-- SECTION 1 : SCHEMA SETUP

DROP DATABASE IF EXISTS ecommerce_portfolio;
CREATE DATABASE ecommerce_portfolio CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_portfolio;

-- -----------------------------------------------------------------------------
CREATE TABLE regions (
    region_id   TINYINT      UNSIGNED NOT NULL AUTO_INCREMENT,
    region_name VARCHAR(50)  NOT NULL,
    PRIMARY KEY (region_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    full_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(120) NOT NULL UNIQUE,
    region_id      TINYINT UNSIGNED NOT NULL,
    registered_at  DATE         NOT NULL,
    PRIMARY KEY (customer_id),
    FOREIGN KEY (region_id) REFERENCES regions(region_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE categories (
    category_id   TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    category_name VARCHAR(60) NOT NULL,
    PRIMARY KEY (category_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE products (
    product_id     INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    sku            VARCHAR(20)  NOT NULL UNIQUE,
    product_name   VARCHAR(150) NOT NULL,
    category_id    TINYINT UNSIGNED NOT NULL,
    unit_price     DECIMAL(10,2) NOT NULL,
    cost_price     DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (product_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE inventory (
    product_id      INT UNSIGNED NOT NULL,
    stock_on_hand   INT          NOT NULL DEFAULT 0,
    reorder_point   INT          NOT NULL DEFAULT 20,
    last_updated    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (product_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id      INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id   INT UNSIGNED NOT NULL,
    order_date    DATE         NOT NULL,
    status        ENUM('completed','refunded','pending') NOT NULL DEFAULT 'completed',
    PRIMARY KEY (order_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_order_date (order_date)
);

-- -----------------------------------------------------------------------------
CREATE TABLE order_items (
    item_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id     INT UNSIGNED NOT NULL,
    product_id   INT UNSIGNED NOT NULL,
    quantity     SMALLINT     NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL,    -- price at time of sale
    PRIMARY KEY (item_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);


-- SECTION 2 : SAMPLE DATA

INSERT INTO regions (region_name) VALUES
    ('Sofia & Central'),
    ('Plovdiv & South'),
    ('Varna & Coast'),
    ('Ruse & North');

INSERT INTO categories (category_name) VALUES
    ('Electronics'),
    ('Home & Kitchen'),
    ('Sports & Outdoors'),
    ('Books & Stationery'),
    ('Beauty & Health');

INSERT INTO products (sku, product_name, category_id, unit_price, cost_price) VALUES
    ('ELEC-001', 'Wireless Earbuds Pro',         1,  49.99, 22.00),
    ('ELEC-002', 'USB-C Hub 7-in-1',             1,  34.99, 14.50),
    ('ELEC-003', 'Portable Power Bank 20K',      1,  29.99, 12.00),
    ('HOME-001', 'Stainless Steel Knife Set',    2,  39.99, 16.00),
    ('HOME-002', 'Non-Stick Cookware Set',       2,  89.99, 38.00),
    ('HOME-003', 'Bamboo Cutting Board',         2,  14.99,  5.50),
    ('SPRT-001', 'Resistance Bands Set',         3,  19.99,  7.00),
    ('SPRT-002', 'Yoga Mat Premium',             3,  24.99, 10.00),
    ('SPRT-003', 'Foam Roller Deep Tissue',      3,  18.99,  7.50),
    ('BOOK-001', 'Data Analysis with Python',    4,  29.99, 12.00),
    ('BOOK-002', 'SQL for Beginners',            4,  19.99,  8.00),
    ('BOOK-003', 'Business Statistics',          4,  24.99, 10.50),
    ('BEAU-001', 'Vitamin C Serum 30ml',         5,  22.99,  8.00),
    ('BEAU-002', 'Hyaluronic Moisturiser',       5,  18.99,  7.50),
    ('BEAU-003', 'SPF 50 Sunscreen 100ml',       5,  14.99,  5.50);

INSERT INTO inventory (product_id, stock_on_hand, reorder_point) VALUES
    (1,  45, 20), (2,  12, 25), (3,  68, 30),
    (4,  33, 15), (5,   8, 10), (6,  91, 20),
    (7,  55, 25), (8,  29, 20), (9,  17, 15),
    (10, 40, 20), (11, 14, 15), (12, 22, 15),
    (13, 60, 25), (14, 38, 20), (15, 76, 20);

INSERT INTO customers (full_name, email, region_id, registered_at) VALUES
    ('Ana Georgieva',    'ana.g@email.bg',     1, '2023-01-12'),
    ('Petar Ivanov',     'p.ivanov@mail.bg',   1, '2023-02-05'),
    ('Maria Todorova',   'mtodo@bgmail.com',   2, '2023-01-28'),
    ('Stefan Nikolov',   's.nikolov@net.bg',   2, '2023-03-15'),
    ('Elena Petrova',    'e.petrova@email.bg', 3, '2023-02-20'),
    ('Dimitar Stoyanov', 'dstoy@mail.com',     3, '2023-04-01'),
    ('Galina Hristova',  'g.hristo@bg.net',    4, '2023-01-08'),
    ('Nikolay Dimitrov', 'n.dim@bgmail.bg',    4, '2023-03-22'),
    ('Tsvetanka Koleva', 'tsveti@email.bg',    1, '2023-05-10'),
    ('Boyan Petrov',     'b.petrov@net.bg',    2, '2023-06-14');

-- Orders: Jan–Jun 2024
INSERT INTO orders (customer_id, order_date, status) VALUES
    (1,  '2024-01-05', 'completed'), (2,  '2024-01-12', 'completed'),
    (3,  '2024-01-18', 'completed'), (4,  '2024-01-25', 'completed'),
    (5,  '2024-02-03', 'completed'), (6,  '2024-02-11', 'refunded'),
    (7,  '2024-02-19', 'completed'), (8,  '2024-02-27', 'completed'),
    (9,  '2024-03-06', 'completed'), (10, '2024-03-14', 'completed'),
    (1,  '2024-03-22', 'completed'), (2,  '2024-03-30', 'completed'),
    (3,  '2024-04-07', 'completed'), (4,  '2024-04-15', 'refunded'),
    (5,  '2024-04-23', 'completed'), (6,  '2024-05-01', 'completed'),
    (7,  '2024-05-09', 'completed'), (8,  '2024-05-17', 'completed'),
    (9,  '2024-05-25', 'completed'), (10, '2024-06-02', 'completed'),
    (1,  '2024-06-10', 'completed'), (3,  '2024-06-18', 'completed'),
    (5,  '2024-06-26', 'completed'), (7,  '2024-06-30', 'completed');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1,  1,  2, 49.99), (1,  10, 1, 29.99),
    (2,  4,  1, 39.99), (2,  13, 2, 22.99),
    (3,  7,  3, 19.99), (3,  8,  1, 24.99),
    (4,  2,  1, 34.99), (4,  11, 2, 19.99),
    (5,  5,  1, 89.99), (5,  14, 1, 18.99),
    (6,  3,  2, 29.99), (6,  15, 3, 14.99),
    (7,  1,  1, 49.99), (7,  6,  4, 14.99),
    (8,  9,  2, 18.99), (8,  12, 1, 24.99),
    (9,  13, 3, 22.99), (9,  4,  2, 39.99),
    (10, 7,  2, 19.99), (10, 10, 1, 29.99),
    (11, 2,  2, 34.99), (11, 8,  1, 24.99),
    (12, 5,  1, 89.99), (12, 14, 2, 18.99),
    (13, 1,  1, 49.99), (13, 11, 3, 19.99),
    (14, 6,  5, 14.99), (14, 15, 2, 14.99),
    (15, 3,  1, 29.99), (15, 9,  1, 18.99),
    (16, 13, 2, 22.99), (16, 8,  2, 24.99),
    (17, 4,  1, 39.99), (17, 7,  3, 19.99),
    (18, 2,  1, 34.99), (18, 10, 2, 29.99),
    (19, 1,  3, 49.99), (19, 12, 1, 24.99),
    (20, 5,  1, 89.99), (20, 14, 1, 18.99),
    (21, 13, 4, 22.99), (21, 6,  3, 14.99),
    (22, 7,  2, 19.99), (22, 11, 1, 19.99),
    (23, 3,  2, 29.99), (23, 8,  1, 24.99),
    (24, 1,  1, 49.99), (24, 10, 1, 29.99);


-- SECTION 3 : ANALYTICAL QUERIES

-- Q1. Monthly revenue, order volume, and average order value (AOV)
--     Completed orders only.  Baseline trend view for the dashboard.

SELECT
    DATE_FORMAT(o.order_date, '%Y-%m')          AS month,
    COUNT(DISTINCT o.order_id)                  AS total_orders,
    SUM(oi.quantity * oi.unit_price)            AS gross_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price)
          / COUNT(DISTINCT o.order_id), 2)      AS avg_order_value
FROM orders          o
JOIN order_items     oi ON oi.order_id   = o.order_id
WHERE o.status = 'completed'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;


-- Q2. Revenue by product category with contribution %

SELECT
    c.category_name,
    COUNT(DISTINCT o.order_id)                                  AS orders,
    SUM(oi.quantity * oi.unit_price)                            AS category_revenue,
    SUM(oi.quantity * (oi.unit_price - p.cost_price))           AS gross_profit,
    ROUND(
        SUM(oi.quantity * oi.unit_price)
        / SUM(SUM(oi.quantity * oi.unit_price)) OVER () * 100
    , 1)                                                        AS revenue_pct
FROM categories  c
JOIN products    p  ON p.category_id = c.category_id
JOIN order_items oi ON oi.product_id  = p.product_id
JOIN orders      o  ON o.order_id     = oi.order_id
WHERE o.status = 'completed'
GROUP BY c.category_id, c.category_name
ORDER BY category_revenue DESC;


-- Q3. Top 10 SKUs by revenue with margin analysis

SELECT
    p.sku,
    p.product_name,
    c.category_name,
    SUM(oi.quantity)                                        AS units_sold,
    SUM(oi.quantity * oi.unit_price)                        AS total_revenue,
    SUM(oi.quantity * (oi.unit_price - p.cost_price))       AS gross_profit,
    ROUND(
        SUM(oi.quantity * (oi.unit_price - p.cost_price))
        / NULLIF(SUM(oi.quantity * oi.unit_price), 0) * 100
    , 1)                                                    AS margin_pct
FROM products    p
JOIN categories  c  ON c.category_id = p.category_id
JOIN order_items oi ON oi.product_id  = p.product_id
JOIN orders      o  ON o.order_id     = oi.order_id
WHERE o.status = 'completed'
GROUP BY p.product_id, p.sku, p.product_name, c.category_name
ORDER BY total_revenue DESC
LIMIT 10;


-- Q4. Revenue by region — for geographic heat-map / bar chart

SELECT
    r.region_name,
    COUNT(DISTINCT o.order_id)              AS total_orders,
    COUNT(DISTINCT o.customer_id)           AS unique_customers,
    SUM(oi.quantity * oi.unit_price)        AS total_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price)
          / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM regions     r
JOIN customers   cu ON cu.region_id  = r.region_id
JOIN orders      o  ON o.customer_id = cu.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE o.status = 'completed'
GROUP BY r.region_id, r.region_name
ORDER BY total_revenue DESC;


-- Q5. Repeat-purchase rate: customers with 2+ orders vs. total customers

WITH customer_orders AS (
    SELECT
        customer_id,
        COUNT(order_id)  AS order_count
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                                AS total_customers,
    SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)      AS repeat_customers,
    ROUND(
        SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)
        / COUNT(*) * 100
    , 1)                                                    AS repeat_rate_pct,
    ROUND(AVG(order_count), 2)                              AS avg_orders_per_customer
FROM customer_orders;


-- Q6. Customer lifetime value (CLV) ranking

SELECT
    cu.customer_id,
    cu.full_name,
    r.region_name,
    cu.registered_at                                AS first_registered,
    COUNT(DISTINCT o.order_id)                      AS total_orders,
    SUM(oi.quantity * oi.unit_price)                AS lifetime_revenue,
    MIN(o.order_date)                               AS first_order,
    MAX(o.order_date)                               AS last_order,
    DATEDIFF(MAX(o.order_date), MIN(o.order_date))  AS days_active
FROM customers   cu
JOIN regions     r  ON r.region_id   = cu.region_id
JOIN orders      o  ON o.customer_id = cu.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
WHERE o.status = 'completed'
GROUP BY cu.customer_id, cu.full_name, r.region_name, cu.registered_at
ORDER BY lifetime_revenue DESC;


-- Q7. Inventory depletion velocity and reorder alert
--     Calculates average daily sales over the last 90 days and flags items
--     where current stock is below 14 days of demand.

WITH daily_sales AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) / 90.0  AS avg_daily_units   -- last 90-day window
    FROM order_items oi
    JOIN orders      o  ON o.order_id = oi.order_id
    WHERE o.status      = 'completed'
      AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY oi.product_id
)
SELECT
    p.sku,
    p.product_name,
    c.category_name,
    i.stock_on_hand,
    i.reorder_point,
    ROUND(COALESCE(ds.avg_daily_units, 0), 2)   AS avg_daily_units,
    CASE
        WHEN COALESCE(ds.avg_daily_units, 0) = 0 THEN NULL
        ELSE ROUND(i.stock_on_hand / ds.avg_daily_units, 0)
    END                                          AS days_of_stock,
    CASE
        WHEN i.stock_on_hand <= i.reorder_point THEN '⚠ REORDER NOW'
        WHEN COALESCE(ds.avg_daily_units, 0) > 0
             AND (i.stock_on_hand / ds.avg_daily_units) <= 14
                                                THEN '⚡ LOW — MONITOR'
        ELSE 'OK'
    END                                          AS stock_status
FROM products   p
JOIN categories c  ON c.category_id = p.category_id
JOIN inventory  i  ON i.product_id  = p.product_id
LEFT JOIN daily_sales ds ON ds.product_id = p.product_id
ORDER BY
    CASE
        WHEN i.stock_on_hand <= i.reorder_point THEN 1
        WHEN COALESCE(ds.avg_daily_units,0) > 0
             AND (i.stock_on_hand / ds.avg_daily_units) <= 14 THEN 2
        ELSE 3
    END,
    i.stock_on_hand ASC;


-- Q8. Month-over-month revenue growth (window function)

WITH monthly_rev AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m')   AS month,
        SUM(oi.quantity * oi.unit_price)     AS revenue
    FROM orders      o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)      AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100
    , 1)                                    AS mom_growth_pct
FROM monthly_rev
ORDER BY month;


-- Q9. Refund rate by category (data quality / loss analysis)

SELECT
    c.category_name,
    COUNT(DISTINCT o.order_id)                              AS total_orders,
    SUM(CASE WHEN o.status='refunded' THEN 1 ELSE 0 END)   AS refunded_orders,
    ROUND(
        SUM(CASE WHEN o.status='refunded' THEN 1 ELSE 0 END)
        / COUNT(DISTINCT o.order_id) * 100
    , 1)                                                    AS refund_rate_pct,
    SUM(CASE WHEN o.status='refunded'
             THEN oi.quantity * oi.unit_price ELSE 0 END)   AS refunded_revenue
FROM categories  c
JOIN products    p  ON p.category_id = c.category_id
JOIN order_items oi ON oi.product_id  = p.product_id
JOIN orders      o  ON o.order_id     = oi.order_id
GROUP BY c.category_id, c.category_name
ORDER BY refund_rate_pct DESC;
