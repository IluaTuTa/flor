-- Purchase funnel: first_open -> view_item -> add_to_cart -> begin_checkout -> purchase
-- Counts distinct users that reached each step within the given date range,
-- plus step-to-step conversion rate.
--
-- Placeholders (replace before running, or parametrize in the MCP client):
--   @project     e.g. "flor2u-prod"
--   @dataset     e.g. "analytics_123456789"
--   @start_date  e.g. DATE '2026-04-01'
--   @end_date    e.g. DATE '2026-04-18'

DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
DECLARE end_date   DATE DEFAULT CURRENT_DATE();

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    TIMESTAMP_MICROS(event_timestamp) AS ts
  FROM `@project.@dataset.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', start_date)
                          AND FORMAT_DATE('%Y%m%d', end_date)
    AND event_name IN ('first_open','view_item','add_to_cart','begin_checkout','purchase')
),
per_user AS (
  SELECT
    user_pseudo_id,
    MAX(event_name = 'first_open')      AS did_first_open,
    MAX(event_name = 'view_item')       AS did_view_item,
    MAX(event_name = 'add_to_cart')     AS did_add_to_cart,
    MAX(event_name = 'begin_checkout')  AS did_begin_checkout,
    MAX(event_name = 'purchase')        AS did_purchase
  FROM events
  GROUP BY user_pseudo_id
),
steps AS (
  SELECT 1 AS step_num, 'first_open'     AS step, COUNTIF(did_first_open)     AS users FROM per_user UNION ALL
  SELECT 2,             'view_item',             COUNTIF(did_view_item)              FROM per_user UNION ALL
  SELECT 3,             'add_to_cart',           COUNTIF(did_add_to_cart)            FROM per_user UNION ALL
  SELECT 4,             'begin_checkout',        COUNTIF(did_begin_checkout)         FROM per_user UNION ALL
  SELECT 5,             'purchase',              COUNTIF(did_purchase)               FROM per_user
)
SELECT
  step_num,
  step,
  users,
  SAFE_DIVIDE(users, FIRST_VALUE(users) OVER (ORDER BY step_num)) AS cr_from_first_open,
  SAFE_DIVIDE(users, LAG(users)         OVER (ORDER BY step_num)) AS cr_from_prev_step
FROM steps
ORDER BY step_num;
