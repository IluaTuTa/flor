-- Revenue, orders and AOV by city (geo.city from GA4).
-- GA4 stores purchase value in the event's `value` parameter and
-- currency in `currency` (see ecommerce schema).

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date   DATE DEFAULT CURRENT_DATE();

WITH purchases AS (
  SELECT
    geo.country                                  AS country,
    COALESCE(NULLIF(geo.city, ''), '(not set)')  AS city,
    ecommerce.purchase_revenue                   AS revenue,
    ecommerce.transaction_id                     AS transaction_id,
    user_pseudo_id
  FROM `@project.@dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', start_date)
                          AND FORMAT_DATE('%Y%m%d', end_date)
    AND event_name = 'purchase'
    AND ecommerce.purchase_revenue IS NOT NULL
)
SELECT
  country,
  city,
  COUNT(DISTINCT transaction_id)              AS orders,
  COUNT(DISTINCT user_pseudo_id)              AS buyers,
  ROUND(SUM(revenue), 2)                      AS revenue,
  ROUND(SAFE_DIVIDE(SUM(revenue),
                    COUNT(DISTINCT transaction_id)), 2) AS aov
FROM purchases
WHERE country = 'Russia'
GROUP BY country, city
ORDER BY revenue DESC
LIMIT 50;
