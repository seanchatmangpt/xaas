# W982u — SPEC-31 graphql deepening receipt (batch 3: 10→12 of 19 domains wired)

Standing: **PARTIAL_ALIVE** (implementation + court executed ×2 green on the
shared test build root; uncommitted, shared tree). NOT LANDED-COMMITTED —
coordinator owns the commit.

## Identity

- Lane: W982u, xaas v26.10.6, checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface`, in-flight tree (baseline `6f235905`).
- Spec: SPEC-31 partial (W973c → W982a follow-up). Census: 10/19 → **12/19**
  domains wired.
- Toolchain: asdf elixir 1.20.2-otp-28, `MIX_ENV=test`.
- Not sensitive: Ledger (Balance/Account/Transfer) and Accounts (User/Token)
  untouched.

## Domains chosen (from W982a's remaining 9)

Remaining 9 after W982a: A2a, Coupling, Graphlaw, Generation, Igniter, Ledger,
TemporalMemory, Ultracode, Witness.

Selection method: `grep -ln "use Ash.Resource\|use Xaas.Resource"` over the
candidate dirs + git-status lane-hot cross-off.

1. **Xaas.Witness** — `lib/xaas/witness/certified_receipt.ex`
   (`Xaas.Witness.CertifiedReceipt`, AshPostgres-backed). The audit/receipt
   surface of the absent set: immutable signature-bearing certified receipts
   over subjects, with an existing write-once policies floor (read bypass +
   deny-by-default `policy always() do forbid_if always()`). Non-sensitive;
   lane-cold (only a docs file `w920-obs-witness-tie.md` is fresh, no lib
   file).
2. **Xaas.Igniter** — `lib/xaas/igniter/refusal_code.ex`
   (`Xaas.Igniter.RefusalCode`, ETS-backed). The typed-refusal vocabulary —
   an audit/log-class surface by nature. Previously had NO policies block;
   added the W982a-precedent deny-by-default floor (read bypass + `policy
   always() do forbid_if always()`).

Disclosed skips: Graphlaw/Generation/Ultracode are lane-hot (fresh
`lib/xaas/bridges/graphlaw.ex` edit, untracked `lib/xaas/graphlaw/limit_gate.ex`,
`test/xaas/generation/`, `test/xaas/ultracode/...` from concurrent lanes) —
crossed off this batch; TemporalMemory's only resource-adjacent file
(`temporal_memory/changes.ex`) is a `Ash.Resource.Change` module, not a
resource; A2a/Coupling/Ledger skipped (Ledger sensitive-by-design; A2a/
Coupling lower read-surface value than audit-class surfaces).

## What landed

- `lib/xaas/witness/certified_receipt.ex`: `extensions: [AshGraphql.Resource]`
  added; NEW graphql block (`type(:witness_certified_receipt)` +
  `get(:witness_certified_receipt, :read)` + `list(:witness_certified_receipts,
  :read)`). Existing policies floor untouched.
- `lib/xaas/igniter/refusal_code.ex`: `extensions: [AshGraphql.Resource]` +
  `authorizers: [Ash.Policy.Authorizer]` + NEW policies floor + graphql block
  (`type(:igniter_refusal_code)` + get/list). Comment marks W982u.
  Section placement: inserted between `identities` and `actions` (Ash DSL
  sections are order-independent).
- `test/xaas/graphql_domain_wiring_court_test.exs`: `@wired` extended with
  `Xaas.Witness` and `Xaas.Igniter` entries (W973c/W982a idiom: field
  presence + one real `Absinthe.run/3` per domain + unknown-field falsifier +
  library baseline intact).

## Verification ladder (real output)

- `MIX_ENV=test mix compile` on the shared `_build/test` root: **exit 0**
  (`Compiling 18 files (.ex)` / `Generated xaas app`; only pre-existing
  ash_affidavit warnings, none from this lane).
- `mix test test/xaas/graphql_domain_wiring_court_test.exs
  test/xaas/graphql_schema_test.exs` ×2, both green: `Result: 4 passed`
  (run 1), `Result: 4 passed` (run 2).
- Root-field census (`mix run -e` over the compiled schema, real output):
  `witness_certified_receipt`, `witness_certified_receipts`,
  `igniter_refusal_code`, `igniter_refusal_codes` all present; 27 query-type
  root fields total. Wired census 10/19 → **12/19**.
- Court's real-pipeline leg: `witness_certified_receipts` resolves the real
  Postgres keyset page through the existing read bypass;
  `igniter_refusal_codes` resolves the real ETS page through the new floor.

## Transport failures observed

- **ENOSPC mid-lane**: the first compile on a fresh
  `MIX_BUILD_ROOT=_build-laneW982u` died with `no space left on device`
  writing zoi beams; disk was already full before this lane started. The
  follow-up `rm -rf _build-laneW982u` cleanup
  was DENIED by the session permission system, so the partial
  `_build-laneW982u` directory (a lane lease per the fanout cleanup law)
  is LEFT FOR THE COORDINATOR to delete at integration, along with
  W982a's leftover `_build-laneW982a` if still present on disk.
- Compile was rerouted to the shared default `_build/test` root
  (`MIX_ENV=test`, pinned asdf toolchain — the sanctioned no-dev-compile
  path); all gates then green on it.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix test test/xaas/graphql_domain_wiring_court_test.exs test/xaas/graphql_schema_test.exs
# expect: Result: 4 passed
```

## Cleanup

`rm -rf _build-laneW982u` DENIED by the session permission system — the
partial `_build-laneW982u` is LEFT FOR THE COORDINATOR to delete at
integration (lane-lease cleanup law), disclosed here.
