# X1b — Playwright Runner Audit (v26.10.5)

Lane X1b, read-only audit + this plan file. Repo `/Users/sac/xaas`, branch `feat/playwright-surface`, v26.10.5. Evidence from real commands, 2026-10-06.

## Current state (cited)

- **Config** — `/Users/sac/xaas/playwright.config.cjs`:
  - `testDir: "./e2e"`, `timeout: 30_000`
  - `webServer: { command: "mix phx.server", port: 4000, reuseExistingServer: true, timeout: 120_000 }`
  - `use.baseURL = process.env.PLAYWRIGHT_BASE_URL || "http://localhost:4000"`
- **package.json** — `"type": "module"`; `scripts.test:e2e = "playwright test"`; devDeps `@playwright/test ^1.62.1`, typescript, vitest, `@amiceli/vitest-cucumber`.
- **Installed version**: `@playwright/test` **1.63.0** (`package-lock.json` pins 1.63.0; satisfies `^1.62.1`). No skew.
- **Browsers**: `~/Library/Caches/ms-playwright/` contains `chromium-1243`, `chromium_headless_shell-1243`, `ffmpeg-1011`, each with `INSTALLATION_COMPLETE`. `node_modules/playwright-core/browsers.json` expects `chromium:1243` / `chromium-headless-shell:1243` — **exact revision match**; arm64 binaries present at `~/Library/Caches/ms-playwright/chromium-1243/chrome-mac-arm64/`. No install needed.
- **Live check**: `npx playwright test --list` (whole testDir) → **Total: 0 tests in 0 files**. On the 5 healthy files only → **Total: 23 tests in 5 files** (smoke 1, next-read-ml 6, full_surface 4, marketplace 4, wd-fa-cs2 1).
- **Server**: `curl http://localhost:4000/` → `000` (nothing listening). `webServer` will auto-start it.
- **CI**: no workflow runs the full `e2e/` dir. Only `stogaf-wd-cs2-court.yml` and `wd-cs2-exact-head.yml` run the single spec `e2e/wd-fa-cs2.spec.cjs` with their own server on port 4002 (`PLAYWRIGHT_BASE_URL: http://localhost:4002`) after `npx playwright install --with-deps chromium`.

## BLOCKER: ESM/CJS mismatch ("0 tests in 0 files")

`package.json` has `"type": "module"`, so `e2e/*.spec.js` files are parsed as ESM. Both CJS-style `.spec.js` files throw at load:

```
ReferenceError: require is not defined in ES module scope, you can use import instead
  at ash-admin-destroy.spec.js:2      const { test, expect } = require("@playwright/test");
  at ash-admin-state-change.spec.js:2
Listing tests: Total: 0 tests in 0 files
```

The healthy files avoid it: `.cjs` extension (smoke, next-read-ml, wd-fa-cs2) or `.spec.ts` with `import` (full_surface, marketplace). This is why the full-suite listing today is 0 tests — the load error in the two `.js` files aborts collection for the entire testDir.

**Required fix (pick one):**
1. **Preferred, minimal**: rename both files to `.cjs` (content unchanged):
   - `e2e/ash-admin-destroy.spec.js` → `e2e/ash-admin-destroy.spec.cjs`
   - `e2e/ash-admin-state-change.spec.js` → `e2e/ash-collectible...` — correct target: `e2e/ash-admin-state-change.spec.cjs`
2. Or convert both to ESM: `import { test, expect } from "@playwright/test";`
3. Or drop `"type": "module"` from package.json — wider blast radius (vitest/tsconfig), not preferred.

## Secondary findings

- **Port-override hazard**: with `PLAYWRIGHT_BASE_URL=http://localhost:4002`, `webServer` still waits on port 4000 and tests hit 4002 — fine in CI (it provisions 4002 itself) but a confusing local failure. Keep the override unset locally.
- **Toolchain discipline**: memory + CLAUDE.md warn plain `mix` resolves to Homebrew Elixir 1.19.5, shadowing asdf 1.20.2-otp-28; a non-pinned compile corrupts `_build`. Every `mix` invocation in the runbook must use `PATH=$HOME/.asdf/shims:$PATH`.
- **Version skew note**: `^1.62.1` declared vs 1.63.0 installed is consistent with caret semantics; no action.
- `erl_crash.dump` in repo root (Oct 5 23:25) — symptom of the toolchain-corruption class above; run all mix commands under the pinned shims.

## Runbook — full suite green at v26.10.5

```bash
cd /Users/sac/xaas

# 1. Required config fix (blocker) — ESM/CJS mismatch
git mv e2e/ash-admin-destroy.spec.js      e2e/ash-admin-destroy.spec.cjs
git mv e2e/ash-admin-state-change.spec.js e2e/ash-admin-state-change.spec.cjs
# (alternative: convert both files to ESM import syntax)

# 2. Run the full suite (webServer auto-starts phx.server on :4000;
#    reuseExistingServer: true means an already-running server is reused)
PATH=$HOME/.asdf/shims:$PATH npx playwright test

#    Equivalent npm script:
PATH=$HOME/.asdf/shims:$PATH npm run test:e2e

#    If you prefer a pre-warmed server instead of webServer auto-start:
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev INTERNAL_API_TOKEN=<token> mix phx.server &
# wait for :4000 to accept connections, then:
PATH=$HOME/.asdf/shims:$PATH npx playwright test
```

## Expected outcome

- After the renames: `npx playwright test --list` should report all 7 files / 27+ tests instead of **0 tests in 0 files**.
- Full run: all 23 healthy-file tests + 2 renamed ash-admin specs green, assuming the `mix phx.server` (dev, port 4000) boots within the 120s webServer timeout under the pinned toolchain. If server boot fails (e.g. DB down — Postgres `xaas_dev` on localhost:5432 must be up), webServer timeout 120s surfaces it as a config error; fix server boot first.
- CI: no change required for existing wd-cs2 courts; a full-suite CI job would need to mirror step 2 (pinned BEAM toolchain + Postgres + `npx playwright install --with-deps chromium`) — gap noted, not blocking local green.