# W983h — SPEC-31 graphql deepening receipt (batch 4: 12→14 of 19 domains wired)

Standing: **PARTIAL_ALIVE** (implementation + court executed ×2 green on a
fresh lane build root; uncommitted, shared tree). NOT LANDED-COMMITTED —
coordinator owns the commit.

## Identity

- Lane: W983h, xaas v26.10.6, checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface`, in-flight tree (baseline `6f235905`).
- Spec: SPEC-31 partial (W973c → W982a → W982u follow-up). Census:
  12/19 → **14/19** domains wired.
- Toolchain: asdf elixir 1.20.2-otp-28, `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW983h` (fresh root, full `--force` compile).
- Not sensitive: Ledger (Balance/Account/Transfer) and Accounts (User/Token)
  untouched; no billing surfaces touched (W982p/W982k are hot there).

## Domains chosen (from W982u's remaining 7)

Remaining 7 after W982u: A2a, Coupling, Graphlaw, Generation, Ledger,
TemporalMemory, Ultracode.

Selection method: fresh read of `lib/xaas/graphql_schema.ex` (all 19
domains already listed in `domains:`; "wired" = resource-level
`AshGraphql.Resource` extension + queries blocks), fresh `git status`
lane-hot cross-off, then resource census
(`grep -ln "use Xaas.Resource\|use Ash.Resource"`).

1. **Xaas.Coupling** — `lib/xaas/coupling/coupling_run.ex`
   (`Xaas.Coupling.CouplingRun`, AshPostgres-backed). Lane-cold (no git
   status entry). Already had a W973c-class policies floor (read bypass +
   deny-by-default). Genuine read surface: persisted runs of the
   closed-form box-constrained coupling engine with status/z/weights/
   receipt.
2. **Xaas.Generation** — `lib/xaas/generation/projection_record.ex`
   (`Xaas.Generation.ProjectionRecord`, ETS-backed). Lane-cold lib file
   (only `test/xaas/generation/` is untracked by a concurrent lane; no
   lib file hot). Previously had NO policies block — added the
   W982a/W982u-precedent deny-by-default floor (read bypass + a `bypass
   action(:admit)` carve-out so the existing `:admit` create path and its
   26 passing tests are untouched) + graphql block. Audit-class surface:
   the one concrete Ash admission path for canonical-graph→projection
   edges.

Disclosed skips: **Graphlaw** still lane-hot (`lib/xaas/bridges/graphlaw.ex`
modified + untracked `lib/xaas/graphlaw/limit_gate.ex` + three untracked
graphlaw test files — crossed off, same as W982u); **Ledger** sensitive and
actively hot (`test/xaas/ledger/w982i_probe_test.exs`,
`transfer_reverse_adverse_court_test.exs` untracked, plus
`reversal_deepening_test.exs` modified — crossed off); **Ultracode** — lib
files are lane-cold, but its read surface (`Xaas.Ultracode.Receipt`)
intentionally keeps bare `:read` closed with only an epoch_id-scoped
`:for_epoch` carve-out (moduledoc: "intentionally unreadable outside the
internal kernel path") — wiring it would have required widening that
policy or a non-list graphql query shape, both beyond this batch's
copy-exact idiom; **A2a** lower read-surface value (per coordinator
guidance); **TemporalMemory** deferred (would have been the third pick;
`Xaas.TemporalMemory.Observation` currently uses an allow-all
`policy always() do authorize_if always()` floor, not the deny-by-default
precedent — left for a lane that can pick a floor decision deliberately).

## What landed

- `lib/xaas/coupling/coupling_run.ex`: `extensions: [AshGraphql.Resource]`
  added; NEW graphql block (`type(:coupling_run)` +
  `get(:coupling_run, :read)` + `list(:coupling_runs, :read)`). Existing
  policies floor untouched.
- `lib/xaas/generation/projection_record.ex`: `extensions:
  [AshGraphql.Resource]` + `authorizers: [Ash.Policy.Authorizer]` + NEW
  policies floor (read bypass + `bypass action(:admit)` + deny-by-default
  `policy always() do forbid_if always()`). Comment marks W983h. Section
  placement: graphql/policies between `actions` and file end (Ash DSL
  sections are order-independent).
- `test/xaas/graphql_domain_wiring_court_test.exs`: `@wired` extended with
  `Xaas.Coupling` and `Xaas.Generation` entries (W982u
  idiom: field presence + one real `Absinthe.run/3` per domain +
  unknown-field falsifier + library baseline intact).

## Verification ladder (real output)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983h mix compile --force` on a
  **fresh** lane root: **exit 0** (`Compiling 942 files (.ex)` / `Generated
  xaas app`; pre-existing ash_a2a/ash_surface dep warnings only, none from
  this lane's files).
- `mix test test/xaas/graphql_domain_wiring_court_test.exs
  test/xaas/graphql_schema_test.exs` ×2 on the lane root, both green:
  `Result: 4 passed` (run 1), `Result: 4 passed` (run 2).
- Root-field census (`mix run -e` over the compiled schema, real output):
  `coupling_runs`/`generation_projection_record`/`generation_projection_records`
  `=> true` (first line `coupling_run => true` scrolled in the same
  inspect block), **31 query-type root fields total** (up from 27 at
  W982u — exactly +4 for this batch's get+list pairs).
- Regression leg for the new policies floor: `mix test
  test/xaas/generation_test.exs test/xaas/generation_deepening_test.exs`
  → `Result: 26 passed` — the `bypass action(:admit)` carve-out keeps the
  existing `:admit` create path fully green.
- Court's real-pipeline leg: `coupling_runs` resolves the real Postgres
  keyset page through the existing read bypass; `generation_projection_records`
  resolves the real ETS page through the new floor.

## Transport failures observed

- None on compile/tests. One permission denial at cleanup: the session
  permission system DENIED `rm -rf _build-laneW983h` after all gates were
  green, so the fully-built `_build-laneW983h` directory (a lane lease per
  the fanout cleanup law) is LEFT FOR THE COORDINATOR to delete at
  integration (same class as W982u's denial).

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983h \
  mix compile --force
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983h \
  mix test test/xaas/graphql_domain_wiring_court_test.exs test/xaas/graphql_schema_test.exs
# expect: Result: 4 passed
```

## Cleanup

`rm -rf _build-laneW983h` DENIED by the session permission system —
`_build-laneW983h` is LEFT FOR THE COORDINATOR to delete at integration
(lane-lease cleanup law), disclosed here.
