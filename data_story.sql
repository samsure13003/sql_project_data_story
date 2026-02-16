create database user_events;
use user_events;
select * from user_events limit 200;

-- Retrieve all unique event categories from user activity
SELECT DISTINCT event_type
FROM user_events;

-- define sales funnel and different stages
WITH funnel_stages AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS stage_1_views,
        COUNT(DISTINCT CASE WHEN event_type='add_to_cart' THEN user_id END) AS stage_2_carts,
        COUNT(DISTINCT CASE WHEN event_type='checkout_start' THEN user_id END) AS stage_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type='payment_info' THEN user_id END) AS stage_4_payments,
        COUNT(DISTINCT CASE WHEN event_type='purchase' THEN user_id END) AS stage_5_purchase
    FROM user_events
    WHERE event_date >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
)
select * from funnel_stages;

-- conversion rates through the funnel
WITH funnel_stages AS (
    SELECT
        COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS stage_1_views,
        COUNT(DISTINCT CASE WHEN event_type='add_to_cart' THEN user_id END) AS stage_2_carts,
        COUNT(DISTINCT CASE WHEN event_type='checkout_start' THEN user_id END) AS stage_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type='payment_info' THEN user_id END) AS stage_4_payments,
        COUNT(DISTINCT CASE WHEN event_type='purchase' THEN user_id END) AS stage_5_purchase
    FROM user_events
    WHERE event_date >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
)

SELECT
    stage_1_views,
    stage_2_carts,
    ROUND(stage_2_carts * 100 / NULLIF(stage_1_views,0)) AS view_to_cart_rate,
    
    stage_3_checkout,
    ROUND(stage_3_checkout * 100 / NULLIF(stage_2_carts,0)) AS cart_to_checkout_rate,
    
    stage_4_payments,
    ROUND(stage_4_payments * 100 / NULLIF(stage_3_checkout,0)) AS checkout_to_payments_rate,
    
    stage_5_purchase,
    ROUND(stage_5_purchase * 100 / NULLIF(stage_4_payments,0)) AS payments_to_purchase_rate,
    
    ROUND(stage_5_purchase * 100 / NULLIF(stage_1_views,0)) AS overall_conversion_rate

FROM funnel_stages;

-- funnel by source
WITH source_funnel AS (
    SELECT
        traffic_source,
        COUNT(DISTINCT CASE WHEN event_type='page_view' THEN user_id END) AS views,
        COUNT(DISTINCT CASE WHEN event_type='add_to_cart' THEN user_id END) AS carts,
        COUNT(DISTINCT CASE WHEN event_type='purchase' THEN user_id END) AS purchases
    FROM user_events
    WHERE event_date >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    GROUP BY traffic_source
)
SELECT
    traffic_source,
    views,
    carts,
    purchases,
    ROUND(carts * 100 / NULLIF(views,0)) AS view_to_cart_rate,
    ROUND(purchases * 100 / NULLIF(carts,0)) AS cart_to_purchase_rate,
    ROUND(purchases * 100 / NULLIF(views,0)) AS overall_conversion_rate

FROM source_funnel
ORDER BY overall_conversion_rate DESC;

-- time to conversion analysis
WITH user_journey AS (
    SELECT
        user_id,
        MIN(CASE WHEN event_type='page_view' THEN event_date END) AS view_time,
        MIN(CASE WHEN event_type='add_to_cart' THEN event_date END) AS cart_time,
        MIN(CASE WHEN event_type='purchase' THEN event_date END) AS purchase_time
    FROM user_events
    WHERE event_date >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    GROUP BY user_id
    having MIN(CASE WHEN event_type='purchase' THEN event_date END) is not null
)
SELECT
    COUNT(*) AS converted_users,
    AVG(TIMESTAMPDIFF(MINUTE, view_time, cart_time)) AS avg_view_to_cart_minutes,
    AVG(TIMESTAMPDIFF(MINUTE, cart_time, purchase_time)) AS avg_cart_to_purchase_minutes,
    AVG(TIMESTAMPDIFF(MINUTE, view_time, purchase_time)) AS avg_view_to_purchase_minutes
FROM user_journey
WHERE view_time IS NOT NULL
AND cart_time IS NOT NULL
AND purchase_time IS NOT NULL;

WITH funnel_revenue AS (
    SELECT
        COUNT(CASE WHEN event_type='page_view' THEN user_id END) AS total_visitors,
        COUNT(CASE WHEN event_type='purchase' THEN user_id END) AS total_buyers,
        SUM(CASE WHEN event_type='purchase' THEN amount END) AS total_revenue,
        COUNT(CASE WHEN event_type='purchase' THEN 1 END) AS total_orders
        
    FROM user_events
    WHERE event_date >= TIMESTAMP(DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
)

select
	total_visitors,
	total_buyers,
	total_revenue,
	total_orders,
    total_revenue / total_visitors as revenue_per_visitor,
    total_revenue / total_buyers as revenue_per_buyer,
    total_revenue / total_orders as revenue_per_order
from funnel_revenue;

