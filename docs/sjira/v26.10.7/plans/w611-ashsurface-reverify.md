# W611 — ash_surface installer-shadowing re-verify (WP-5, OS-13 consumer-side)

- Date: 2026-10-07
- Subject: `~/ash_surface` @ `b70da9e1c` (HEAD, branch state observed; tree has
  in-flight lane edits — read-only lane, nothing modified or committed)
- Baseline: 371/371 at `main@d55c576d1` (w901)

## 1. Grep — graphql-era + fixture-pack residue in `~/ash_surface/lib`

Patterns: `ash_graphql|absinthe|aex:fixtureOnly|fixture_only|xaas_library_pack` (case-insensitive), plus a broader `graphql|absinthe` sweep.

**Result: zero hits. 0 matching lines in all of `lib/`.**

Classification: nothing to classify — the W984ao graphql removal and W610's
marker cleanup left `lib/` clean. No live installer-shadowing emissions remain
in the Elixir source tree.

## 2. Suite — projected client vs current xaas surfaces

Entry: `npm test` (per TESTING.md / w981r), `node --test test/js/*.test.mjs`.

- First run (no browser): `tests 371 / pass 367 / fail 0 / skipped 4`. The 4
  skips were all `playwright_accessibility.test.mjs` cases with reason
  `playwright + chromium observation runtime not installed` — the hermetic
  mode TESTING.md documents.
- Installed the runtime per the documented CI recipe
  (`npm install --no-save --package-lock=false playwright@1.63.0` — first
  attempt hit an npm-cache ENOENT, retried clean with `--cache /tmp/w611-npm-cache`;
  `npx playwright install chromium` → Chrome Headless Shell 153.0.8010.12),
  then reran:

```
ℹ tests 371
ℹ pass 371
ℹ fail 0
ℹ skipped 0
ℹ duration_ms 4555.244417
```

**371/371 pass, 0 skipped, real headless Chromium — exactly the w901 baseline.**

Delta vs baseline: **none.** No failures to classify; the graphql removal
(W984ao) produced no regression and no count change in this suite. W984n's
prediction (entrypoint count unchanged, byte-stale on org_id zod) is
consistent with what was observed: counts unchanged, suite green — the
byte-staleness is a projection-freshness issue, not a test failure.

## 3. Regen verdict for 26.10.7

**YES — regen needed before 26.10.7 ships.** The suite passing on the current
projection proves behavioral compatibility, not byte freshness: the version
bump plus the graphql removal mean the committed projection is byte-stale
against current xaas surfaces (org_id zod per W984n). Verdict only — no regen
was performed in this lane; schedule the regen as its own admitted transition
(ggen sync / projection pipeline) before release.

## Standing

- lib cleanliness: **ALIVE** (zero residue hits, real grep output above)
- suite vs current surfaces: **ALIVE** (371/371, real Chromium, exact baseline match)
- 26.10.7 projection freshness: **UNKNOWN → regen required** (byte-stale per
  W984n prediction; not regenerated in-lane)
