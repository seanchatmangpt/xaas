# W984mf — ash_surface Playwright surface seal receipt

- Subject: `/Users/sac/ash_surface` @ HEAD `154385c82` (v26.10.7 CalVer bump, W650o), branch not touched, no commits. Tree had pre-existing dirty files (`.github/workflows/manufacture.yml`, `CHANGELOG.md`, `TESTING.md`, `ggen.toml`, `scripts/README.md`, untracked `doc/ docs/sjira/ fixture/ lib/ash_surface/a2a_bridge.ex test/aex_spark_dead_surface_court.exs test/ash_a2a_composition_*.exs ...`) — none in the digest-law or Playwright path.
- Verdict: **ALIVE** for the Playwright surface; **pre-existing PARTIAL on the tree** — 6 failures in `test/js/digest_cross_language_v3.test.mjs` from a stale committed digest fixture at HEAD, unrelated to and not masking the Playwright result.

## 1. Orient

- Repo has no `playwright.config.*`; the Playwright surface is `priv/static/ash_surface_playwright.mjs` (OBSERVE-only WAI-ARIA adapter, `options.playwright` seam) driven by `node:test` suites in `test/js/`, gated on a real Chromium launch.
- Documented run per `TESTING.md` ("Playwright surface" section) and CI recipe (`.github/workflows/ci.yml`): `npm install --no-save --package-lock=false playwright@1.63.0 && npx playwright install chromium` then `npm test`.

## 2. Real commands and output

```
cd /Users/sac/ash_surface
npm install --no-save --package-lock=false playwright@1.6
3.0 && npx playwright install chromium   # exit 0
npm test                                  # exit 1
```

`npm test` (full JS suite): tests 371, pass 365, fail 6, skipped 0.
All 6 failures in `test/js/digest_cross_language_v3.test.mjs`:

- "JavaScript agrees with the Elixir-generated corpus on every vector it can express"
- "no MUST vector is silently unaccounted: each is PASS, NOT_APPLICABLE(reason) or KNOWN_DIVERGENCE(reason)"
- "every pinned known divergence names a real vector, and every vector of them still diverges"
- "replay can fail: a scratch copy of the corpus with one edited vector is RED"
- "T1 contract: JS twin recomputes every Elixir surface digest from the contract JSON"
- "deep key-order permutation never moves any digest in any table"

All six share one root cause, e.g. from the log: `T1 contract ... / C1 read-only contract, UTF-8 profile keys + numeric boundaries: JS twin recomputed 532b4a1a15df76884525849e583fd8e5c58665808a57d3cff1836963c12900d9, Elixir froze db26ae108cb224a78bf4d8d6e43f1eda74c07609edbd91cf4c5daf0c27261c7b`

Playwright suites, run directly for focused witness:

```
node --test test/js/playwright_accessibility.test.mjs
  ✔ real Chromium produces an OBSERVE-only WAI-ARIA surface receipt (232ms)
  ✔ missing accessible target is evidence, not a CSS/XPath fallback (222ms)
  tests 2 / pass 2 / fail 0 / skipped 0   (real headless Chromium launch)
node --test test/js/boundary_refusals.test.mjs
  ✔ observeAccessibility refuses a browser the Playwright module does not provide
```

`skipped 0` confirms the runtime gate was admitted and the tests ran against real headless Chromium over data: URLs (loopback-only, no server boot), matching the TESTING.md contract.

## 3. Failure classification (disclosed)

Hypothesis: stale committed fixture vs. moved digest law — checked by running the Elixir-side guard that owns the fixture bytes:

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW984mf \
  mix test test/ash_surface/digest_parity_fixture_test.exs
  3/4 passed, 1 failed: "assert on_disk_bytes() == DigestParityFixtures.encode()"
```

The real-pipeline regeneration produces C1 elixirDigest `532b4a1a…` where the committed fixture pins `db26ae10…` — and the JS twin recomputes `532b4a1a…` too. So JS agrees with current Elixir; **the committed fixture bytes are stale at HEAD `154385c82`** (pre-existing, not lane-introduced; the digest-parity guard is designed to catch exactly this before the JS suite). This is a fixture-regeneration fix (test-artifact, not lib/), left for the coordinator — lane scope is the Playwright seal.

## 4. Cleanup

- `rm -rf /Users/sac/ash_surface/_build-laneW984mf` — done, verified gone (remaining `_build-laneW637b`, `_build-laneW939` are other lanes'; untouched).
- `npm install --no-save` added playwright@1.63.0 into `node_modules/` (gitignored) and Chromium into `~/Library/Caches/ms-playwright` — CI-recipe-standard, left in place.
- No git commands beyond read-only status/log inspection; no stash, no branch change, no commits anywhere.
- No rm denials.

## 5. Standing

- Playwright surface (checklist item 2): **ALIVE** — 2/2 accessibility courts + boundary refusals pass against real headless Chromium, 0 skips.
- Whole-tree `npm test`: PARTIAL — 365/371; 6 pre-existing fixture-staleness failures in `digest_cross_language_v3`, fix = regenerate `test/js/fixtures/digest_cross_language_fixtures.json` via `AshSurface.DigestParityFixtures.encode()` (test-artifact regen, disclosed for coordinator).
