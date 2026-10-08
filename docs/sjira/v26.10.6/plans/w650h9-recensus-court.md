# W650h9 — Re-census burn-down court (CS2 contract family)

Lane W650h9, xaas v26.10.6, branch `feat/playwright-surface` @ 45844db6. No commit (per lane
contract; files left in working tree for coordinator integration).

## Scope decision

`w650h8-recensus.md` is not on disk (searched all of `docs/sjira/v26.10.6/` — zero matches for
"recensus" or `w650h*`). Fallback per lane brief: verified coverage directly from the tree.
The re-census list is headed by `CS2.FleetContract` + `ILSRepo.FixtureAdapter`; FixtureAdapter
is doctrine-exempt (W984cw3). Verified with `grep -rln` over `test/`:

- `Xaas.CS2.FleetContract` (`lib/xaas/cs2/fleet_contract.ex`): **0 test references** — uncovered.
- `Xaas.CS2.GeneratedFleetContract` (`lib/xaas/cs2/generated_fleet_contract.ex`): **0 test
  references** (the predicate `accepts?` has zero refs anywhere in `test/`) — uncovered.

Both are state-bearing (representation boundary / admission predicate), neither claimed by a
running lane (dp3 cursor, dq typescript-manifest, dq2 autofde, dr gov-types — none CS2). Chosen
as the lane's 2 modules.

## Surface analyses

### Xaas.CS2.FleetContract (`lib/xaas/cs2/fleet_contract.ex`)

Representation boundary: packages admitted CS2 evidence for engineer-facing consumers; it
never creates runtime authority. Surfaces:

- `subject/0` → `"https://chatman.ai/cs2#RFC-CS2-001"`; `contract/0` → `"cs2-fleet-contract/26.9.27"`.
- `engineer_workflow/1` (map head): recursively stringifies the packet (`strings/1`), gates on
  `subject == "https://chatman.ai/cs2#RFC-CS2-001"`; admitted →
  `{:ok, %{kind: "cs2.engineer_workflow", contract, subject, source (default
  "semantic_jira"), evidence, authority: "NONE"}}`; foreign subject →
  `{:error, {:unsupported_cs2_subject, subject}}`.
- Non-map head → `{:error, {:unsupported_cs2_packet, packet}}` (typed refusal, no raise).

### Xaas.CS2.GeneratedFleetContract (`lib/xaas/cs2/generated_fleet_contract.ex`)

Data-only canonical consumer projection for RFC-CS2-001. `contract/0` is the generated
admission binding (subject "RFC-CS2-001", campaign "CS2-CHICAGO", producer
"seanchatmangpt/ggen", pack "cs2-fleet-contract", consumer "xaas", upstream_consumer
"ash_a2a", work_id "CS2-WRK-013", authority_ceiling :construct, three requires_* flags true)
and `accepts?/1` is the gate: subject == "RFC-CS2-001" AND work_id in ["CS2-WRK-013",
"CS2-WRK-012"], atom- or string-keyed, non-map → false.

## Courts landed

- `test/xaas/cs2/fleet_contract_test.exs` — 5 tests.
- `test/xaas/cs2/generated_fleet_contract_test.exs` — 5 tests.

Every test carries a mutation rationale: subject-gate→always-true, authority "NONE"→"FULL",
`strings/1` normalization drop, source-default fold, non-map heads deleted (raise vs typed
refusal), `and`→`or` in `accepts?`, CS2-WRK-012 twin removal, contract-shape drift.

## Verification

Exact command executed (real output `Result: 10 passed, 0 failures`):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h9 \
  mix test test/xaas/cs2/fleet_contract_test.exs test/xaas/cs2/generated_fleet_contract_test.exs
```

Warnings in the log are pre-existing runtime noise (Grafana/PromEx nxdomain,
autofde-not-on-PATH, AshA2A legacy_compat profile) plus pre-existing compile warnings in
`lib/mix/tasks/xaas.airo.compile_shacl.ex` and `lib/xaas/operations/refusal_ledger_export.ex`
— none session-introduced; this lane touched no `lib/` code.

## Standing

- Both courts: **ALIVE** (observed execution on the exact subject, real exit, command above).
- Typed refusals verified as-real (`{:error, {:unsupported_cs2_subject, _}}`,
  `{:error, {:unsupported_cs2_packet, _}}`, `accepts?/1` false paths) — no mocks, per
  Chicago discipline.
- `Xaas.Library.ILSRepo.FixtureAdapter`: skipped per doctrine exception (W984cw3).
- Coordinator note: `w650h8-recensus.md` is absent from disk; land it before further
  burn-down waves cite its 176-module list.

## Lane hygiene

Files written: the 2 test files above + this receipt. No `lib/` changes. Lane build root
`_build-laneW650h9` deleted at integration (see session log). No commit made.
