-- Weekly retention cohorts based on first_open.
-- Row = install cohort (week). Column = weeks since install. Cell = % of the
-- cohort that returned that week.

DECLARE weeks_back INT64 DEFAULT 12;

WITH first_open AS (
  SELECT
    user_pseudo_id,
    DATE_TRUNC(MIN(DATE(TIMESTAMP_MICROS(event_timestamp))), WEEK(MONDAY)) AS cohort_week
  FROM `@project.@dataset.events_*`
  WHERE event_name = 'first_open'
    AND _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL weeks_back WEEK))
  GROUP BY user_pseudo_id
),
activity AS (
  SELECT
    user_pseudo_id,
    DATE_TRUNC(DATE(TIMESTAMP_MICROS(event_timestamp)), WEEK(MONDAY)) AS active_week
  FROM `@project.@dataset.events_*`
  WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL weeks_back WEEK))
  GROUP BY user_pseudo_id, active_week
),
joined AS (
  SELECT
    f.cohort_week,
    DATE_DIFF(a.active_week, f.cohort_week, WEEK) AS week_number,
    f.user_pseudo_id
  FROM first_open f
  JOIN activity  a USING (user_pseudo_id)
  WHERE a.active_week >= f.cohort_week
)
SELECT
  cohort_week,
  COUNT(DISTINCT IF(week_number = 0, user_pseudo_id, NULL)) AS cohort_size,
  SAFE_DIVIDE(COUNT(DISTINCT IF(week_number = 1, user_pseudo_id, NULL)),
              COUNT(DISTINCT IF(week_number = 0, user_pseudo_id, NULL))) AS w1,
  SAFE_DIVIDE(COUNT(DISTINCT IF(week_number = 2, user_pseudo_id, NULL)),
              COUNT(DISTINCT IF(week_number = 0, user_pseudo_id, NULL))) AS w2,
  SAFE_DIVIDE(COUNT(DISTINCT IF(week_number = 4, user_pseudo_id, NULL)),
              COUNT(DISTINCT IF(week_number = 0, user_pseudo_id, NULL))) AS w4,
  SAFE_DIVIDE(COUNT(DISTINCT IF(week_number = 8, user_pseudo_id, NULL)),
              COUNT(DISTINCT IF(week_number = 0, user_pseudo_id, NULL))) AS w8
FROM joined
GROUP BY cohort_week
ORDER BY cohort_week DESC;
