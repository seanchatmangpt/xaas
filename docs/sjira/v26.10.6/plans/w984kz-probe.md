# W984kz — e2e documentation truth-pass (post-W984fw)

Date: 2026-10-08 · Lane: W984kz · Branch: `feat/playwright-surface` · NO commit (coordinator owns transitions) · docs-only, no build root.

## Subject

`/Users/sac/xaas` working tree at `feat/playwright-surface` (uncommitted lane
diffs present; coordinator owns all git state). Baseline authority: receipt
`docs/sjira/v26.10.6/plans/w984fw-seed-writer.md` (Playwright pipeline pinned
to `MIX_ENV=dev` / `xaas_dev`; W650h23 foreign-writer root cause).

## Claims audited (grep sweep across `docs/` minus `docs/archive/` + `docs/sjira/`)

- `docs/claude/diataxis/reference/actuation-and-semantics.md` — DevSeeds env
  gate section (w983f): module/court/kill claims re-verified against
  `lib/xaas/dev_seeds.ex:267-282` (`refute_non_dev_target!/0`, `e2e: true`
  opt-in, sandbox-owner probe) — accurate. Stale by omission: no statement of
  where the e2e boot seed now lands. FIXED (see below).
- `docs/case-studies/next-read/README.md` — Playwright coverage + seed
  claims (`priv/repo/seeds.exs` → `Xaas.DevSeeds.run()`,
  `e2e/next-read-ml.spec.cjs`): accurate; no MIX_ENV/DB claims. No edit.
- `docs/claude/diataxis/explanation/ash-is-the-xaas.md`,
  `errc-innovation-grid.md`, `how-to/fix-ash-admin-and-use-ggen-for-codegen.md`,
  `docs/cro/*`, `docs/ci/CI-ARCHITECTURE.md`: point-in-time receipts/case
  claims (dated, SHA-pinned); no boot-command or DB-targeting claims made
  stale by W984fw. No edit (dated artifacts are not living docs).
- `docs/cro/artifacts/agent-obliviousness-demo.md` boot mirror
  (`node ./e2e/global-setup.cjs --catalog`) still matches the BOOT command's
  first step. No edit.
- **Stale claims found OUTSIDE docs/, in code comments that state DB
  targeting (the exact claim class this lane was sent to truth-pass):**
  - `e2e/seed-library.exs` — "deliberately writes the fixture chain to the
    test database the Playwright webServer serves from" — FALSE post-W984fw
    (writes `xaas_dev`). FIXED.
  - `lib/xaas/dev_seeds.ex` (~:259-263 guard comment) — same
    "test database the e2e webServer serves" claim. FIXED.

## Changes (4 files, fix-forward)

1. `e2e/seed-library.exs` — stale "test database" comment replaced with the
   pinned-dev statement + dated Verified note citing W984fw.
2. `lib/xaas/dev_seeds.ex` — guard doc-comment corrected: `e2e: true`
   opt-in is now a dormant fallback (seed runs in `:dev` env), normal e2e
   path targets `xaas_dev`. Comment-only change.
3. `docs/claude/diataxis/reference/actuation-and-semantics.md` — DevSeeds
   env gate section: added "Verified 2026-10-08 (post-W984fw)" bullet
   documenting the pinned-dev pipeline (config BOOT + both seed scripts) and
   the guard's remaining `:test` fallbacks, citing
   `w984fw-seed-writer.md`.
4. `e2e/README.md` — NEW. The e2e/ documentation surface was absent; created
   with: boot pipeline order (webServer-before-globalSetup, catalog →
   pinned-dev `mix run` → readiness probe), DB-targeting table, DevSeeds
   env-guard interplay (W983f/W984bs/W984fw), PW_PORT lane-lease rules,
   falsifier status (W984fw ALIVE at config layer; **full e2e re-run OWED —
   coordinator**).

## Verification (real outputs)

- `elixir -e 'Code.string_to_quoted!(...)'` on both edited Elixir files →
  `EX_SYNTAX_OK` (comment-only diffs).
- grep evidence quoted above; no executable MIX_ENV wiring touched.
- Mock gate N/A (no test code touched); no mix compile run (docs-only lane,
  no build root per lane instructions).
- No commit, no stash, no branch change.

## Standing

- Documentation-truth pass: ALIVE (all stale claims corrected; new README
  matches the on-disk config exactly as read this session).
- Falsifier inherited unchanged from W984fw: `MIX_ENV=test PW_PORT=4199
  npx playwright test e2e/next-read-ml.spec.cjs` → 0 new committed rows in
  `xaas_test` (`inserted_at > boot time`). Execution OWED — coordinator.
- Comment-only edits to `.ex`/`.exs` files: zero behavioral delta.
