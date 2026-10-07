# W326 — ash_surface DoD 3 C′/C″ fixtures (receipt)

Subject: `/Users/sac/ash_surface` @ branch `feat/playwright-surface` (canonical checkout, NO commit made — lane contract).
Date: 2026-10-06

## Scope check (first move)

`grep`/`ls` over `test/` found `standing_test.exs`, `health_test.exs`, `health_deep_test.exs` —
no standing-evidence *adversarial* fixture and no 200/503 HTTP *mapping* fixture existed.
Both were written new.

## Files created (contract: two test files + this receipt; zero lib/ changes)

- `/Users/sac/ash_surface/test/ash_surface/standing_evidence_adversarial_test.exs` (C′)
- `/Users/sac/ash_surface/test/ash_surface/health_http_mapping_test.exs` (C″)
- `/Users/sac/xaas/docs/sjira/v26.10.6/plans/w326-ash-surface-c-fixtures.md` (this receipt)

## C′ — standing-evidence adversarial (7 tests)

Real constructors only (`AshSurface.Observation.create/3`, `AshSurface.Standing`), no doubles.
Pins: bare `:REFUSED` refused at the constructor boundary with the exact message;
`:UNKNOWN` refused (post-dispatch outcome, never a standing); off-vocabulary corpus
(`:BOGUS`, `:ALIVE_UPGRADED`, `"ALIVE"`, `"REFUSED_NO_AUTHORITY"`, `42`, `nil`, `%{}`, `[]`)
all refused with the exact ArgumentError; valid `REFUSED_*` evidence admitted and carried
verbatim; synthetic never-emitted `REFUSED_W326_*` admitted by prefix law; no silent
widening of `:PARTIAL_ALIVE`; `validate!/1` identity over all 5 base standings.

## C″ — health 200/503 HTTP mapping (5 tests)

`ash_surface` is a library with no endpoint of its own; the mapping pinned is the one
documented verbatim in `AshSurface.Health`'s moduledoc for hosting apps. The test defines
a REAL Plug router (`Plug.Router` + a real `Ash.Resource` manifest → real
`AshSurface.from_manifest/2` surface) and sends real requests via `Plug.Test.conn/2` through
`Router.call/2`. Courts: healthy `check/0` → 200 (`status: "ok"`, OBSERVE, 3 ok checks);
healthy `check_surface/2` → 200; `:digest_drift` → 503 (digest_integrity error);
`:missing_runtime` → 503 (real nonexistent runtime_path); non-surface subject → 503 with the
typed `REFUSED_INVALID_SUBJECT` / `surface_struct_required` refusal. No skips; the HTTP
surface exists as the documented wrap, so none was needed.

## Commands + real output

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/ash_surface/_build-laneW326 \
  mix test test/ash_surface/standing_evidence_adversarial_test.exs test/ash_surface/health_http_mapping_test.exs
```

Iteration 1: 11/12 (REFUSED_INVALID_SUBJECT refusal map carries snake_case
`authority_boundary`, assertion expected camelCase) → fixed assertion → iteration 2:

```
Finished in 0.5 seconds (0.5s async, 0.02s sync)
Result: 12 passed
```

Known non-failing warning: Inspect-protocol consolidation notice for the test-local
`Milestone` resource (same shape as existing test-local resources in `health_deep_test.exs`).

## Standing verdicts

- **C′ standing-evidence adversarial: ALIVE** — 7/7 green on the exact subject above.
- **C″ health 200/503 HTTP mapping: ALIVE** — 5/5 green over the real Plug request path.
- **DoD 3 (ash_surface C′/C″): closed** per fixtures on this subject; no lib/ changes made (P1-4 boundary held).

## Hygiene

Lane build root `/Users/sac/ash_surface/_build-laneW326` deleted at integration (lane build
roots are leases, not assets). No commit made (lane contract: coordinator owns commits).
