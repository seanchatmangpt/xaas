# W848 Receipt — BOOT probe header quoting fix (closes W842-F1)

- **Lane**: W848, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6` (canonical checkout, uncommitted working tree).
- **Task**: W842 finding F1 — the tokened boot-readiness probe in
  `playwright.config.cjs:67` built `AUTH="-H Authorization: Bearer $INTERNAL_API_TOKEN"`
  and expanded `$AUTH` unquoted in the curl command; word-splitting made curl parse
  `-H Authorization:` as a header REMOVAL, so the tokened probe 401'd forever.
- **Date**: 2026-10-07

## Fix (one line, `playwright.config.cjs:67`)

Before:

```
... AUTH=""; [ -n "$INTERNAL_API_TOKEN" ] && AUTH="-H Authorization: Bearer $INTERNAL_API_TOKEN"; ... -m 5 $AUTH "$PROBE_URL"); ...
```

After (smallest robust form — variable eliminated entirely; POSIX-portable, no bash
arrays needed since playwright runs the command via `/bin/sh`):

```
... for i in $(seq 1 180); do CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 ${INTERNAL_API_TOKEN:+-H "Authorization: Bearer $INTERNAL_API_TOKEN"} "$PROBE_URL"); if [ "$CODE" = "200" ] ...
```

The quoted header lives inside the `${var:+word}` alternate word, so it stays one field
per POSIX quote-removal rules. Tokenless runs expand to nothing (probe hits `/` with no
header, unchanged).

## Falsifier (real execution, PW_PORT=4128, MIX_ENV=test, token `dev-e2e-token`)

1. **Before (bug reproduced live)**: ran the exact pre-fix BOOT string manually with a
   token; server booted; tokened `curl -H Authorization: Bearer dev-e2e-token
   http://localhost:4128/internal-api/health` → **200**, while the loop's unquoted form
   → **401** `{"error":"unauthorized","detail":"missing or invalid Bearer token"}`.
   Confirms W842-F1 exactly. Beam killed, port 4128 verified clear.
2. **After, tokened, real config path**: `INTERNAL_API_TOKEN=dev-e2e-token PW_PORT=4128
   MIX_ENV=test npx playwright test e2e/smoke.spec.cjs --reporter=line --workers=1` →
   **1 passed (52.8s)**, zero `readiness probe never returned 200` lines — the fixed
   BOOT probe reached 200 inside the real webServer command. Then a manual boot of the
   extracted fixed BOOT with token: probe
   `curl -m 5 -H "Authorization: Bearer dev-e2e-token" .../internal-api/health` →
   **200**, body `{"status":"ok","checks":{...repo ok, ash_domain:* ok...}}`.
3. **After, tokenless**: boot without `INTERNAL_API_TOKEN` → probe `/` → **200**;
   `/internal-api/health` fail-closes to **503** as designed (why the tokenless probe
   uses `/`).

Boot tail (tokened, /tmp/xaas-e2e-server.log — normal PromEx/Grafana nxdomain warnings,
no probe failure):

```
05:40:20.652 [warning] PromEx.DashboardUploader failed to upload ... :unkown (nxdomain)
... (repeated PromEx/Grafana warnings only)
```

Tokenless boot out: `[global-setup] ... catalog written (13 packs)` + seed OK lines,
0 probe-failure lines.

## Cleanup state

- Every boot's beam killed at close; `lsof -iTCP:4128 -sTCP:LISTEN` empty after each
  run ("4128 clear"). No orphan beam.
- No lane build root created (used the existing `_build/test`; nothing new to delete).
- Files touched: `playwright.config.cjs` (line 67 only) + this receipt. Nothing committed.

## Verdict

**Standing: ALIVE** — tokened probe 200 through the real config webServer path (spec
passed, no late probe failure), tokenless probe 200, tokenless health fail-closed 503,
clean shutdowns verified. W842-F1 closed.
