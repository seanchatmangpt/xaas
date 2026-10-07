# W903 — ash_surface playwright surface documented

## Identity

- Repo: /Users/sac/ash_surface (canonical checkout, branch `main`, HEAD `d55c576d11a2213a666c44f135c96e2f6baf44d0`).
- Scope: docs-only. Nothing committed (per lane contract); diff left in working tree.

## Consequence

- Added "### Playwright surface" subsection to `/Users/sac/ash_surface/TESTING.md`
  (inserted before "## 2. What Chicago-style means here"), 12 lines, facts only:
  - suite shape: hermetic without a browser (runtime-gated, 4 skips when
    Playwright absent); data: URLs, loopback-only, no server boot when present.
  - run commands: `npm test`; CI recipe
    `npm install --no-save --package-lock=false playwright@1.63.0 && npx playwright install chromium`
    (from `.github/workflows/ci.yml`).
  - witnessed run: 371/371, 0 skipped, real headless Chromium at
    `main@d55c576d1`, citing W901 receipt
    (`~/xaas/docs/sjira/v26.10.6/plans/w901-ash-surface-playwright.md`).

## Verification

- Read-back confirmed via Edit success + file state tracked; note sits inside
  the section that documents `npm test` posture (TESTING.md section 1, before
  the Chicago-style section).
- No code, test, or CI changes; no build root created; no commits.

## Standing

- Docs lane: **ALIVE** — note present on disk at exact subject `main@d55c576d`
  (working tree, uncommitted per lane contract). Facts sourced from the W901
  ALIVE receipt; no new claims introduced.
