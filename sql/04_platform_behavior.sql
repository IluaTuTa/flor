-- iOS vs Android breakdown: users, sessions, purchases, revenue, CR,
-- broken down by platform and app_version. Useful for spotting regressions
-- after releases.

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY);
DECLARE end_date   DATE DEFAULT CURRENT_DATE();

WITH base AS (
  SELECT
    platform,
    app_info.version AS app_version,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    event_name,
    ecommerce.purchase_revenue AS revenue
  FROM `@project.@dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', start_date)
                          AND FORMAT_DATE('%Y%m%d', end_date)
)
SELECT
  platform,
  app_version,
  COUNT(DISTINCT user_pseudo_id)                                  AS users,
  COUNT(DISTINCT CONCAT(user_pseudo_id, CAST(session_id AS STRING))) AS sessions,
  COUNTIF(event_name = 'view_item')                                AS view_item_events,
  COUNTIF(event_name = 'add_to_cart')                              AS add_to_cart_events,
  COUNTIF(event_name = 'purchase')                                 AS purchases,
  ROUND(SUM(IF(event_name = 'purchase', revenue, 0)), 2)           AS revenue,
  SAFE_DIVIDE(COUNTIF(event_name = 'purchase'),
              COUNT(DISTINCT user_pseudo_id))                      AS purchase_cr
FROM base
WHERE platform IN ('IOS','ANDROID')
GROUP BY platform, app_version
ORDER BY platform, users DESC;
