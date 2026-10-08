# W984dk — Operations provenance burn-down slice (castle approval + route_castle trio)

Campaign: xaas v26.10.6 · Lane W984dk · Coverage burn-down, Operations family
(provenance slice W984cw4 does not claim). Base at lane start: `f3911592`;
lane HEAD witnessed at receipt time: `52764939` (other lanes committing on the
shared checkout; this lane touched only its own two files).

## Census (CamelCase-aware, real grep over `test/` at lane start)

Operations lib modules: 25 top-level + changes/checks/types/validations/
project_measure subdirs. Modules with **0 test references** (CamelCase-aware
grep): `ApprovalCastleVerbSchedule`, `ApprovalCausalAnatomy`, `AutofdePlannerMatch`,
`AutofdePlannerCatalog`, `AutofdePlannerCacheStats`, `AutofdePlannerCacheHotset`,
`RouteCastleDeploy`, `RouteCastleSchedule`, `RouteCastleSunset`.

Exclusions honored:
- `AuthorityLedgerExport` — W603, already courted
  (`test/xaas/operations/authority_ledger_export_test.exs`) — skipped per task.
- `ApprovalCausalAnatomy` — W604b2 metadata leg; left to W984cw4's slice.
- `AutofdePlanner*` (4 modules) — partially referenced by
  `system_authority_service_scope_test.exs`; left to W984cw4's slice.

## This lane's slice: 4 modules courted

- `Xaas.Operations.ApprovalCastleVerbSchedule` — prior coverage was name-only
  (subject list in `system_authority_service_scope_test.exs`); no create/
  approve/validation behavior ever executed in a court.
- `Xaas.Operations.RouteCastleDeploy` / `RouteCastleSchedule` /
  `RouteCastleSunset` — zero test references; read-only deny-floor surfaces.

## Court

`test/xaas/operations/castle_approval_route_surface_test.exs` — 5 Chicago
tests, real Ash actions over real sandboxed Postgres (`Ecto.Adapters.SQL.Sandbox`),
assert on persisted state; typed refusals as real Ash error values; no mocks.

1. maker-checker happy path: `:create` + `:approve` as `internal_api` system
   actor; persisted `approved_by` verified by re-read. Mutation rationale:
   dropping the distinct-approver rule admits self-approval → (2) fails.
2. self-approval refused typed (`Ash.Error.Invalid`, field `:approved_by`,
   "cannot approve their own"), row unchanged. Mutation: remove
   `ApprovalCastleVerbScheduleRequiresApprover` from `:approve` → fails.
3. empty approver refused typed ("is required"), row unchanged. Same mutation
   class as (2).
4. route_castle trio: `Repo.insert_all`-minted rows read back through real Ash
   `:read` (anonymous). Mutation: drop the `bypass action_type(:read)` → fails.
5. deny floor: no create/update actions exist (changeset-construction
   ArgumentError), and minted rows survive with `approved_by` unchanged.
   Mutation: add `:create` to `defaults` on any trio member or relax
   `policy always() do forbid_if(always()) end` → fails.

## Verification ladder (real output)

- Iterate run (warm lane root): `mix test test/xaas/operations/castle_approval_route_surface_test.exs`
  → `5 passed` (after fixing `Ash.Changeset.for_update` record-vs-module
  argument error found in the first run: 1/5 passed, 4 failed, all the same
  root cause).
- Fresh root run 1 (`rm -rf _build-laneW984dk` first): `Result: 5 passed`, exit 0.
- Fresh root run 2 (root deleted again): `Result: 5 passed`, exit 0.
  (First attempt of run 2 was killed at the background-task time limit
  mid-compile; retried on a fresh root to completion — disclosed, not hidden.)
- Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2, `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW984dk` (deleted at integration, per lane-lease law).

## Standing

- **Court (this slice): ALIVE** — 5/5 green on two independent fresh build
  roots against the shared checkout.
- **Operations census burn-down**: 29 → 25 uncovered by this lane's count
  (4 modules courted); remaining uncovered residue (`AutofdePlannerMatch`,
  `AutofdePlannerCatalog`, `AutofdePlannerCacheStats`, `AutofdePlannerCacheHotset`,
  `ApprovalCausalAnatomy`) is W984cw4's slice — standing UNKNOWN here, not
  claimed.
- No commit made (per lane contract); files are staged-by-others territory:
  `test/xaas/operations/castle_approval_route_surface_test.exs` (new),
  `docs/sjira/v26.10.6/plans/w984dk-provenance.md` (this receipt).

## Falsifiers (already embedded as per-test mutation rationale above)

Any of the 5 courts fails on a descendant head ⇒ regression in the
maker-checker validation or the route_castle deny floor.
