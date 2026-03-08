WITH platform_revenue AS (
    -- Step 1: Calculate total revenue and order count per platform
    SELECT
        o.platform,
        COUNT(DISTINCT o.order_id)          AS total_orders,
        COUNT(DISTINCT o.customer_email)    AS unique_customers,
        ROUND(SUM(oi.line_revenue), 2)      AS gross_revenue,
        ROUND(SUM(oi.discount_amt * oi.qty), 2) AS total_discounts,
        ROUND(AVG(oi.line_revenue), 2)      AS avg_line_revenue

    FROM `ignira-analytics.staging.stg_orders` o
    JOIN `ignira-analytics.staging.stg_order_items` oi
        ON o.order_id = oi.order_id

    WHERE o.order_status NOT IN ('Cancelled')   -- exclude cancelled orders
    GROUP BY o.platform
),

platform_refunds AS (
    -- Step 2: Calculate refund totals per platform
    SELECT
        o.platform,
        COUNT(r.refund_id)              AS total_refund_count,
        ROUND(SUM(r.refund_amount), 2)  AS total_refunded

    FROM `ignira-analytics.staging.stg_refunds` r
    JOIN `ignira-analytics.staging.stg_orders` o
        ON r.order_id = o.order_id

    GROUP BY o.platform
),

platform_order_status AS (
    -- Step 3: Count cancelled and completed orders per platform
    SELECT
        platform,
        COUNTIF(order_status = 'Cancelled')  AS cancelled_orders,
        COUNTIF(order_status = 'Completed')  AS completed_orders,
        COUNTIF(order_status = 'Refunded')   AS refunded_orders,
        COUNT(*)                             AS total_orders_all_status
    FROM `ignira-analytics.staging.stg_orders` o
    GROUP BY platform
)

-- Final output: combine all metrics
SELECT
    r.platform,

    -- Volume metrics
    r.total_orders,
    r.unique_customers,
    s.cancelled_orders,
    s.refunded_orders,
    ROUND(s.cancelled_orders / s.total_orders_all_status * 100, 1)
                                            AS cancellation_rate_pct,

    -- Revenue metrics
    r.gross_revenue,
    r.total_discounts,
    ROUND(r.gross_revenue - r.total_discounts, 2)
                                            AS net_revenue_after_discounts,

    -- Refund metrics
    f.total_refunded,
    ROUND(f.total_refunded / r.gross_revenue * 100, 2)
                                            AS refund_rate_pct,

    -- Net revenue after refunds (what we actually keep)
    ROUND(r.gross_revenue - f.total_refunded, 2)
                                            AS revenue_after_refunds,

    -- Revenue per customer
    ROUND(r.gross_revenue / r.unique_customers, 2)
                                            AS revenue_per_customer

FROM platform_revenue r
JOIN platform_refunds f      ON r.platform = f.platform
JOIN platform_order_status s ON r.platform = s.platform

ORDER BY r.gross_revenue DESC;
