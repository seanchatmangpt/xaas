# W901 — ash_surface validated against playwright

## Identity

- Repo: /Users/sac/ash_surface (canonical checkout, branch `main`, HEAD `d55c576d11a2213a666c44f135c96e2f6baf44d0`)
- No product/spec changes made; nothing committed (per lane contract).
- Session-introduced: `npm install --no-save --package-lock=false playwright@1.63.0` + `npx playwright install chromium` (gitignored node_modules only; package.json/package-lock untouched).

## Conventions read (repo's own path)

- Playwright surface = `priv/static/ash_surface_playwright.mjs` (shipped module) + `test/js/playwright_accessibility.test.mjs`, run by `node --test test/js/*.test.mjs` (`npm test`).
- CI path: `.github/workflows/ci.yml:70-71` — `npm install --no-save --package-lock=false playwright@1.63.0` then `npx playwright install --with-deps chromium`. Reproduced locally without `--with-deps` (macOS host, no system deps needed).
- The suite is hermetic (data: URLs, loopback-only; a suite self-audit test asserts no env-var reads and loopback-only URLs in test/js sources). No server boot, no port discipline (W822/W848 pattern) needed.
- No mix compile needed; Elixir side not exercised this lane.

## Real run

Baseline (before playwright install) — `npm test` under pinned node v26.10.0 (asdf), 2026-10-07:

```
ℹ tests 371
ℹ pass 367
ℹ fail 0
ℹ skipped 4
```

After CI-equivalent playwright install:

```
ℹ tests 371
ℹ pass 371
ℹ fail 0
ℹ skipped 0
ℹ duration_ms 3104.495292
```

Playwright-surface key lines (grep of second run):

- `✔ real Chromium produces an OBSERVE-only WAI-ARIA surface receipt (242.068875ms)` — real headless Chromium launch, 242 ms.
- `✔ observeAccessibility refuses a browser the Playwright module does not provide`
- `✔ T3 observation: JS twin recomputes every state digest and obs_ content id`
- `✔ suite audit: no environment-variable reads and loopback-only URLs in test/js sources`
- `✔ observation projection is pure, read-only, and never carries authority`

The 4 formerly-skipped tests live in `test/js/playwright_accessibility.test.mjs` (2 top-level `test(` declarations; skips were runtime-gated per the file's documented skip-if-runtime-absent gate). With the runtime installed, gate admits, skips → 0.

## Classification

- pass: 371/371 (both runs; baseline skips were environmental, not failures).
- fail: 0.
- environment: the 4 baseline skips — resolved by installing playwright@1.63.0 + chromium per the repo's own CI recipe; zero-config battery (no browsers) also green as designed.
- spec-side stale assertions: none; nothing fixed.
- product regressions: none (typed finding: none).

## Standing

"~/ash_surface validated against playwright" leg: **ALIVE** — observed execution on exact subject `main@d55c576d`, real Chromium launch, 371/371, exit 0.
Zero-config fallback standing (fresh clone, no browsers): 367 pass / 4 runtime-gated skips / 0 fail — documented, by-design behavior.
Replay: `cd /Users/sac/ash_surface && npm install --no-save --package-lock=false playwright@1.63.0 && npx playwright install chromium && npm test` (node v26.10.0 pinned).
