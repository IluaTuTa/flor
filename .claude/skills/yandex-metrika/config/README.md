# Configuring the yandex-metrika skill

## Token

The scripts need an OAuth token with `metrika:read`. Resolution order:

1. `YANDEX_METRIKA_TOKEN` in the process environment
2. `config/.env` (this directory)
3. the repo-root `.env`

For this project the repo-root `.env` already provides
`YANDEX_METRIKA_TOKEN` and `YANDEX_METRIKA_COUNTER_ID`, so no extra setup is
needed. To scope a token to the skill only, copy `.env.example` here:

```bash
cp config/.env.example config/.env
# then edit config/.env
```

## Getting a token

1. Create an app at https://oauth.yandex.ru/client/new with the
   **Yandex Metrika `metrika:read`** scope.
2. Redirect URI: `https://oauth.yandex.ru/verification_code`
3. Open (replace `<CLIENT_ID>`):
   `https://oauth.yandex.ru/authorize?response_type=token&client_id=<CLIENT_ID>`
4. Copy the `access_token` from the redirect URL and export it:
   ```bash
   export YANDEX_METRIKA_TOKEN="y0__..."
   ```

## Network (Claude Code sandbox)

`api-metrika.yandex.net` and `oauth.yandex.ru` must be in the sandbox egress
allowlist (`.claude/settings.json` → `sandbox.network.allowedDomains`). The
allowlist is read at session start, so **restart Claude Code** after changing it.
