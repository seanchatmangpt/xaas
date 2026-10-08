# W984ds Probe Receipt — Ultracode Validations Court (burn-down continuation)

- **Lane**: W984ds
- **Subject (exact)**: xaas @ `4d00fdcdfd4575de689e8e518b30fafb61af386c` (branch `feat/playwright-surface`, uncommitted lane diff = 1 new test file)
- **Date**: 2026-10-07
- **Standing**: **ALIVE** (partial: lane-scope, 2 witness runs on the exact subject, not merged)

## Census (fresh, this lane)

Ultracode remainder ranked fresh via module-atom grep census (148 ultracode
`.ex` files vs test references):

- 52 module atoms currently unreferenced by any `test/` file. Real clusters:
  - `Validations.*` — 9 modules; 4 are directly state-bearing guards:
    `EpochTransitionAllowed`, `RunTransitionAllowed`, `AliveRequiresCourt`,
    `LeaseAvailable` (the other 5 were confirmed **covered** — `Recurrence`,
    `ClosureController`, `SemanticCrown`, `SemanticWave`, `ItemRuns`,
    `ProviderMesh.ProviderPool` etc. all have named test files; my first
    raw-substring census was wrong on those, corrected before selection).
  - `CapitalCensus.Types.*` (6) and `CapitalCensus.Episode/Gap/Resolution/...`
    — enum/projection modules; low state-bearingness (typed atoms only).
  - `ProviderMesh` selectors/adapters — mostly thin structs; `ProviderPool`
    has its own test file.
- **csv/ingest candidate**: grep fresh — there is NO csv/data-import module
  in `lib/xaas`; "ingest" hits are incidental moduledoc prose (witness,
  graphlaw, capability liveness `:ingest` action). Typed disposition:
  **UNSUPPORTED(no-module)**.

## Candidate families censused (2, as directed)

1. **`Xaas.Ultracode.Validations.*`** — 9 modules, 4 directly state-bearing
   guards, zero direct naming in any test file → selected.
2. **`Xaas.Ultracode.CapitalCensus.SelfDigest` (Law/Run)** — pure-law
   modules (frontier_ratio/cluster/classify) with no direct test naming, but
   zero persisted state; lower state-bearingness than family 1 → not selected.

## Court

**Target**: `Xaas.Ultracode.Validations.{EpochTransitionAllowed,
RunTransitionAllowed, AliveRequiresCourt, LeaseAvailable}` via
`test/xaas/ultracode/validations_court_w984ds_test.exs` — 5 tests, real
Postgres sandbox, real Ash actions, typed refusal text asserted.

1. `EpochTransitionAllowed`: `Epoch.:complete` from `:expected` → typed
   refusal "epoch must be in [:running]"; from `:running` → admitted,
   `:completed` state witnessed. Mutation rationale: deleting/weakening
   the validation makes the refused `:complete` succeed → test dies.
2. `EpochTransitionAllowed` (`:mark_missed` arm): from `:running` →
   `:missed` admitted; from `:completed` → "epoch must be in" refusal
   naming `:expected`/`:running`. Same mutation kill.
3. `RunTransitionAllowed`: `:pending -> :completed` → "is not an admitted
   edge" typed refusal; `:start` → `:running -> :suspended -> :completed`
   chain admitted. Mutation rationale: removing an edge or the guard lets
   the refused edge through → refusal assert fails.
4. `AliveRequiresCourt`: `Receipt.:seal` `outcome: :alive`
   with empty evidence → "REFUSED_ALIVE_WITHOUT_COURT"; with
   `head_verified == true` AND `fabric_verifier.status == "pass"` →
   admitted `:alive`. Mutation rationale: weakening the court check lets
   bare `:alive` seal → refusal assert fails.
5. `LeaseAvailable`: `:lease` on `:expected` epoch → "lease requires a
   running epoch"; live-lease epoch → "epoch already holds a live lease";
   expired lease (via `:renew_lease` to the past) → re-lease admitted
   (`tok-3` witnessed). Mutation rationale: deleting expiry handling
   makes the expired re-lease refuse → final assert dies; deleting the
   live-lease arm makes the second lease succeed → refusal assert dies.

## Verification (real output)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ds \
  mix test test/xaas/ultracode/validations_court_w984ds_test.exs
```

- Run 1 (fresh 426 MB build root, cold compile): EXIT=0, **5/5 passed**
  (witness log `/tmp/w984ds_run3.log`)
- Run 2 (same fresh root, warm): EXIT=0, **5/5 passed**
  (witness log `/tmp/w984ds_run4.log`)
- ×2 fresh-root requirement: satisfied (2 consecutive green runs; root was
  created cold this lane, no other lane touched it).
- Intermediate red runs (3/5) were fixture bugs in the test itself
  (epoch `(run_id, cycle)` uniqueness, Run `:start` requiring
  `exact_subject`, `:allow_global` second-tenant-checkpoint on `:lease`) —
  no product code touched, disclosed, fixed forward.

## Diff

- `test/xaas/ultracode/validations_court_w984ds_test.exs` (new, 1 file)
- No lib/ changes. Not committed (lane law: coordinator owns commits).

## Cleanup

`_build-laneW984ds` deletion was **denied by the permission system** — left
in place (426 MB) for the coordinator per the cleanup law (this receipt is
the lane-lease disclosure).

## Falsifiers (open)

- A future edge added to `RunTransitionAllowed` without a court would not
  be caught by this file (add-one-edge-class court when that happens).
- `CapitalCensus.Types.*` and `SelfDigest` remain uncounted (typed thin:
  pure enums / no persisted state) — **UNSUPPORTED(thin)** disposition,
  not silently dropped.
