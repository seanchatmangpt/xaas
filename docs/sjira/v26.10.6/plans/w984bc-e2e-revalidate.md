# W984bc — e2e internal-api revalidation post-graphql-removal

Lane W984bc, xaas v26.10.6, checkout `/Users/sac/xaas`, branch `feat/playwright-surface`,
HEAD at run time `4d59c680` (mid-removal tree; W984ao/W984ap landed earlier on the branch).

## Method

Fresh playwright boot, tokened, per W980l method:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bc \
  PW_PORT=4147 INTERNAL_API_TOKEN=w984bc-token \
  npx playwright test e2e/internal-api.spec.cjs
```

Precompiled first (`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bc mix compile`,
exit 0, "Generated xaas app") to avoid the W980l first-attempt 180s readiness-probe
expiry. Compile under the pinned asdf toolchain; no archive/scratch fallback needed —
the mid-removal tree compiles clean.

## Real run output (tail)

```
Running 4 tests using 1 worker

  ✓  1 e2e/internal-api.spec.cjs:36:3 › /internal-api token gate › refuses /internal-api/health without a token (fail-closed, typed body) (41ms)
  ✓  2 e2e/internal-api.spec.cjs:59:3 › /internal-api token gate › refuses /internal-api/ocel_summary with an invalid token (401, typed body) (11ms)
  ✓  3 e2e/internal-api.spec.cjs:85:3 › /internal-api token gate › serves real health data with the env token (20ms)
  ✓  4 e2e/internal-api.spec.cjs:114:3 › /internal-api token gate › serves real OCEL summary data with the env token (18ms)

  4 passed (55.4s)
PW_EXIT=0
```

4/4 as contracted (W980l/W984ap: dual typed floors, W836 warming_up grace via the
tokened health path, OCEL summary). Internal-api surface untouched by the
graphql removal, now witnessed by execution not just read.

## Environment note (pre-existing, not removal-regression)

Global-setup library seed (`e2e/seed-library.exs`) refused under `MIX_ENV=test`:

```
** (Mix) REFUSED(dev_seeds, env=test) -- dev seeds must never target a test/prod
database ... (cleaned by W982r)
[global-setup] library seed did not report W823_SEED_OK (continuing)
```

Classification: **pre-existing guard behavior**, not a removal regression and not a
flake — the seed guard (W982r class) fires on env alone, unrelated to router/graphql;
setup continued and all 4 tests passed. Differs from W980l's run (W823_SEED_OK then)
via seed-path/env-guard drift on the tree, not the e2e spec. Recorded for the
coordinator; no action taken in this lane.

## Standing

**ALIVE** — tokened fresh-boot e2e passes 4/4 on exact HEAD `4d59c680` of
`feat/playwright-surface`, post-graphql-removal. Falsifier: any internal-api spec
failure attributable to the router edit — not observed.

## Cleanup

`_build-laneW984bc` deletion was permission-denied in this lane; left in place for
coordinator cleanup (same as W980l). No commits made, per lane instruction.
