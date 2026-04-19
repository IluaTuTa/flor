-- Today's live events from the intraday streaming table.
-- Use this query as the very first smoke-test after enabling the export.

SELECT
  event_name,
  COUNT(*)                         AS events,
  COUNT(DISTINCT user_pseudo_id)   AS users,
  MIN(TIMESTAMP_MICROS(event_timestamp)) AS first_seen,
  MAX(TIMESTAMP_MICROS(event_timestamp)) AS last_seen
FROM `@project.@dataset.events_intraday_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
GROUP BY event_name
ORDER BY events DESC;
