# Flor2u — Claude Code project notes

## Yandex Metrika API

### Configuration
- **Base URL:** `https://api-metrika.yandex.net`
- **Auth header:** `Authorization: OAuth $YANDEX_METRIKA_TOKEN`
- **Counter ID:** `32273834` (stored in `.env` as `YANDEX_METRIKA_COUNTER_ID`)
- **Token env var:** `YANDEX_METRIKA_TOKEN`

If the token is missing, walk the user through:
1. https://oauth.yandex.ru/client/new — create app with `metrika:read`
2. Redirect URI: `https://oauth.yandex.ru/verification_code`
3. Open `https://oauth.yandex.ru/authorize?response_type=token&client_id=<CLIENT_ID>`
4. `export YANDEX_METRIKA_TOKEN="..."`

### Main report endpoint
```
GET /stat/v1/data
  ?id=COUNTER_ID
  &metrics=...
  &dimensions=...
  &date1=YYYY-MM-DD&date2=YYYY-MM-DD
  &filters=...
  &sort=...&limit=...
```
Always append `filters=ym:s:isRobot=='No'` (combine with `AND` if other filters are present).

### Metrics
- Base: `ym:s:visits`, `ym:s:users`, `ym:s:pageviews`
- Quality: `ym:s:bounceRate`, `ym:s:pageDepth`, `ym:s:avgVisitDurationSeconds`
- Goals: `ym:s:goal<ID>reaches`, `ym:s:goal<ID>conversionRate`, `ym:s:goal<ID>revenue`
  (look up goal IDs via `/management/v1/counter/{id}/goals`)

### Dimensions
- Sources: `ym:s:trafficSource`, `ym:s:sourceEngine`, `ym:s:searchPhrase`
- UTM: `ym:s:lastsignUTMSource`, `ym:s:lastsignUTMMedium`, `ym:s:lastsignUTMCampaign`
- Geo: `ym:s:regionCountry`, `ym:s:regionCity`
- Devices: `ym:s:deviceCategory`, `ym:s:browser`, `ym:s:operatingSystem`
- Pages: `ym:s:startURL`, `ym:s:endURL`
- Time: `ym:s:date`, `ym:s:hour`, `ym:s:dayOfWeek`

### Other endpoints
- `/stat/v1/data/bytime` — time series
- `/stat/v1/data/comparison` — compare two periods (`date1_a/date2_a` vs `date1_b/date2_b`)
- `/management/v1/counters` — list counters
- `/management/v1/counter/{id}/goals` — goals

### Filter operators
`==`, `!=`, `=@` (contains), `=~` (regex). Examples:
- `ym:s:trafficSource=='organic'`
- `ym:s:deviceCategory=='mobile'`
- `ym:s:startURL=@'/catalog/'`

### Working rules
1. Cache responses in `cache/metrika/` as TSV; do not re-fetch the same period.
2. Never cache when `date2 == today`.
3. Use header `Accept: application/x-yandex-tabular-stream-values` to save context.
4. Default attribution: `lastsign`. For Direct campaigns offer `last_yandex_direct_click`.
5. If the user does not specify a period, ask — suggest the last 30 days.
6. API limit ≈ 100 req/hour. Read `X-RateLimit-Remaining` from responses.
7. Max 10 metrics and 10 dimensions per request.
