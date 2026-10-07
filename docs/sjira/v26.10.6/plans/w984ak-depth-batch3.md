# W984ak — Depth Batch 3 (a2a Agent / temporal_memory Observation / igniter RefusalCode)

Lane W984ak, xaas v26.10.6 campaign. Repo `/Users/sac/xaas`; branch
`feat/playwright-surface` (uncommitted campaign tree; no commit per dispatch).
Written only: 3 new test files under `test/xaas/` + this receipt. Pinned
asdf toolchain 1.20.2-otp-28, `MIX_ENV=test`.

## Surface selection (read-first; W984aa receipt absence disclosed)

The dispatched overlap check was "W984aa's receipt" — no
`w984aa*` file exists under `docs/sjira/v26.10.6/plans/` (verified by
directory listing; nearest neighbors `w984a-corpus-deepening-3.md` and
`w984ac-cycle-advance.md` are different lanes). Overlap avoidance therefore
fell back to the receipts that do exist plus a live coverage survey:
W980i (accounts org_membership destroy / marketplace provider pre-approve /
generation projection_record admission) and W984a (eu_ai_act
DatasetAdmission gates) are avoided; GraphQL surfaces, the sensitive
resources (`Xaas.Ledger.*`, `Xaas.Accounts.*`), and this session's already
deepened families (witness CertifiedReceipt, ocel Event, security Finding,
coupling, graphlaw Capability, library HoldRequest, conference, a2a Task)
are excluded. Chosen families and their uncovered slices:

1. **`Xaas.A2a.Agent`** — `test/xaas/a2a_resources_deepening_test.exs`
   courts Agent only at create + card projection; the a2-a4 courts are
   Task. Uncourted: `unique_name` identity typed refusal, the W984l
   deny-by-default policy floor (authorized create/destroy refuse
   Forbidden, reads stay open), the `:update` accept-list contract, and
   attribute defaults.
2. **`Xaas.TemporalMemory.Observation`** —
   `test/xaas/temporal_memory/observation_test.exs` courts single-hop
   supersede, hash divergence, and the supersedes_id requirement. Uncourted:
   multi-generation supersede chain, dangling `supersedes_id` (admits,
   best-effort audit pointer), `valid_to` round-trip, the policy floor,
   double supersede pointer overwrite.
3. **`Xaas.Igniter.RefusalCode`** —
   `test/xaas/igniter/igniter_catalog_test.exs` courts the Catalog ingest
   path; `test/xaas/igniter_deepening_test.exs` courts RefusalCode only at
   a create/read round-trip and the open-vocabulary pin. Uncourted:
   code-as-writable-primary-key, duplicate-code typed refusal, the W982u
   policy floor (create/update/destroy), update accept-list, defaults +
   verbatim legacy-form code storage.

## Files + per-file counts

| file | tests | result |
|---|---|---|
| `test/xaas/a2a/agent_identity_policy_depth_test.exs` | 5 | 5/5 both runs |
| `test/xaas/temporal_memory/observation_supersede_chain_depth_test.exs` | 5 | 5/5 both runs |
| `test/xaas/igniter/refusal_code_policy_depth_test.exs` | 5 | 5/5 both runs |

Combined 15/15, two runs on two different fresh roots (run 2 cold
compile). Run 1: `MIX_BUILD_ROOT=_build-laneW984ak`, seed 160085,
`Result: 15 passed`, exit 0. Run 2:
`MIX_BUILD_ROOT=_build-laneW984ak-r2`, seed 422007, `Result: 15 passed`,
exit 0.

## Real contract facts witnessed (worth retaining)

- `Xaas.A2a.Agent` and `Xaas.Igniter.RefusalCode` have NO `:id` attribute:
  their writable string (`name` / `code`) IS the primary key; `Ash.get!/2`
  addresses rows by that key. The first draft wrongly assumed a uuid pk —
  the courts now assert the real keying.
- `Observation`'s policy admits authorized `:observe`/`:supersede`
  (explicit action bypasses) but refuses authorized `:mark_superseded_by`
  (Forbidden). `Observation` declares no `:destroy` action at all — a
  destroy attempt is a typed `Ash.Error.Invalid.NoPrimaryAction`
  (structurally immutable by construction), not a Forbidden.
- `MarkPriorSuperseded` tolerates a dangling `supersedes_id`: the
  correction admits and persists; the audit pointer is best-effort by
  design (typed success, not a refusal).
- Double supersede of one prior overwrites `superseded_by_id` with the
  second correction (last-writer-wins pointer), first correction kept as
  a distinct row.
- Supersede does not touch the prior row's `valid_to`/`fact`/hash.

## Mutation rationale per file

1. a2a Agent: deleting the `identity(:unique_name)` (or its
   `pre_check_with: Ash.DataLayer.Ets`) makes the duplicate-create court
   fail with a second admitted row instead of a typed Invalid; deleting
   the `policy always() forbid_if(always())` floor flips the authorized
   create/destroy courts from Forbidden to success; removing
   `:skills`/`:transport_bindings` from the `:update` accept list fails
   the round-trip court.
2. temporal_memory: removing the `bypass action(:supersede)` fails the
   authorized-supersede admission assertion; removing the floor
   (`policy always()` after the bypasses) flips the authorized
   `:mark_superseded_by` court from Forbidden to success; removing
   `validate(present(:supersedes_id))` is already courted upstream (W980i
   sibling file), this file's chain/dangling/overwrite courts fail if
   `MarkPriorSuperseded` stops writing the prior pointer.
3. igniter RefusalCode: deleting `identity(:unique_code,
   pre_check_with: Ash.DataLayer.Ets)` flips the duplicate-code court to
   an admitted second row; deleting the W982u policy floor flips both
   authorized refusal courts to success; removing `:retryable` from the
   `:update` accept list fails the mutation court.

## Verification (real commands, real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ak \
  mix test test/xaas/a2a/agent_identity_policy_depth_test.exs \
           test/xaas/temporal_memory/observation_supersede_chain_depth_test.exs \
           test/xaas/igniter/refusal_code_policy_depth_test.exs
# run 1: seed 160085 — Result: 15 passed, exit 0
# run 2: seed 422007, MIX_BUILD_ROOT=_build-laneW984ak-r2 (fresh root,
#         cold compile) — Result: 15 passed, exit 0
```

Mock gate: grep of the three files → only the literal prose "no mocks";
zero `Mock`/`patch(` usage. Chicago: real sandboxed Postgres rows
(temporal_memory) and real private-ETS stores via real Ash actions with
real row-state assertions; typed refusals asserted
(`Ash.Error.Forbidden`, `Ash.Error.Invalid`, nested
`Ash.Error.Invalid.NoPrimaryAction`).

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  15/15 on both runs, real commands + real exits.
- Build roots: `rm -rf` is permission-denied in this lane session (same
  fallback as W980i/W984a). `_build-laneW984ak` and `_build-laneW984ak-r2`
  are **LEFT FOR COORDINATOR** per the fanout cleanup law.
- Repair history witnessed: run 1 of the first draft failed 15/15→compile
  error (missing `require Ash.Query` in the temporal_memory file), second
  attempt 9/15 (assumed uuid pks on the two ETS resources and assumed
  Forbidden on authorized observe — all three assumptions corrected
  against real outputs, courts rewritten to the real contracts), third
  attempt 14/15 (destroy on Observation is NoPrimaryAction, not
  Forbidden), final 15/15 stable. No lib/ edits at any point; every repair
  was to the test's model, not the subject.
- Not done (typed): GraphQL surfaces excluded per operator directive (the
  W984l graphql blocks on all three resources were NOT courted and remain
  courted elsewhere/no — they are simply outside this lane's contract);
  no line flips; no lib/ or corpus edits.
