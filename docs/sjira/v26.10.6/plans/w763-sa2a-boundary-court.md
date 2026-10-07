# W763 — SA2A computation-boundary court (receipt)

- **Subject**: `/Users/sac/xaas` @ `a0723bf61a1c6058bdcd2d0202c9519840182a5e`
  (branch `feat/playwright-surface`)
- **Deliverable**: `test/xaas/sa2a_computation_boundary_test.exs` (new, 20 tests, uncommitted per lane contract)
- **Doctrine under court**: `docs/claude/diataxis/reference/sa2a-computation-boundary.md` (W714-verified)
- **Lane**: W763, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW763`, no mocks.

## μ / diff

Hand-written test file (irreducible residue; no generator path exists for test
files in this repo). No other file touched. `git status --porcelain` on the
subject tree: `?? test/xaas/sa2a_computation_boundary_test.exs`.

## Commands / exits (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW763 \
    mix test test/xaas/sa2a_computation_boundary_test.exs
  ....................
  Finished in 5.6 seconds (0.00s async, 5.6s sync)
  Result: 20 passed

$ ... mix test test/xaas/sa2a_computation_boundary_test.exs --seed 7
  Result: 20 passed

$ ... mix test test/xaas/sa2a_computation_boundary_test.exs --seed 1
  Finished in 2.7 seconds
  Result: 20 passed
```

## Verification ladder

1. **narrow**: `mix test test/xaas/sa2a_computation_boundary_test.exs` — 20/20
   at seeds default, 7, 1 (determinism ×3).
2. **mock gate** (repo discipline):
   `scan_mock_usage(["test/xaas/sa2a_computation_boundary_test.exs"])` → `[]`.
3. **construction court (a)**: real `new/1` constructors over the real
   `Registry.public_iri?/1` gate; typed refusals asserted with their exact
   shapes: `:non_public_capability_iri`, `{:unsupported_runtime, "TENSORRT"}`,
   `:computation_claim_cannot_authorize_actuation`,
   `{:computation_claim_standing_refused, "ADMITTED"}`.
4. **exactly-one-data-part rule**: real `Route.tuple/1` task hop over the
   committed fixture `test/fixtures/sa2a_route/sa2a_task.json`; 0 →
   `{:missing_field, "subject"}`, 1 → tuple projected, 2 →
   `{:refused, {:ambiguous_tuple_carrier, 2}}` (exact shapes asserted).
5. **candidate-cannot-authorize (b)** — the court's central finding.
6. **order_formal/2 (c)**: filter semantics on mixed formal/informal sets —
   foreign high-score ref never returned; duplicate formal refs refused
   (`:formal_candidate_refs_must_be_unique`); unadvised formal refs appended
   unchanged (`["c2", "c1", "c3"]` from formal `["c1","c2","c3"]` with only
   c2 advised).
7. **conserve/3 (d)**: intact fixture route → `:ok`; full per-field mutation
   table at the task hop (all 7 fields, exact `field:` naming asserted);
   two-field test proves the ordering contract (mutated `subject` at order hop
   + valid-value-mutated `consequence_class` at task hop → `field: "subject"`
   named, the earlier field in `Route.fields/0` order).
8. **determinism (e)**: artifact/claim/advice hashes and conserve/digest
   verdicts equal across repeat calls and across seeds.

## (b) measured reality — the honest boundary

Probed 2026-10-07 against this exact subject with `Xaas.Actuation.run/4`
(`Xaas.Marketplace.Provider`, `:actuate_status`, real sandboxed row):

- A real `%ComputationClaim{}` carried as the `authority:` opt →
  `{:ok, %{status: :succeeded, replay?: false}}` — **the actuation SUCCEEDS**.
- A claim-shaped plain map → same. The kernel's `admit_authority/2`
  (`lib/xaas/actuation.ex:576-582`) checks only that `authority` is a
  nonempty map when `authorize?: false`; a struct is a map, so the claim
  passes and `json_safe/1` serializes it.
- The provider row changed (`status == :active`).

**Standing: the doctrine sentence "a ComputationClaim is always CANDIDATE and
cannot authorize actuation" is enforced at claim construction
(`ComputationClaim.new/1`) and at the admitted route (`Xaas.Sa2a.Executor`),
NOT at the `authority:` channel of `Xaas.Actuation.run/4`.** The court asserts
this measured reality (`assert {:ok, %{status: :succeeded, replay?: false}}`)
and does not fabricate a refusal. Typed gap recorded below.

## Typed gaps / refusals

1. **GAP (authority-channel)**: `Xaas.Actuation.Kernel.admit_authority/2`
   accepts any nonempty map (including a `ComputationClaim` struct) as
   authority evidence. Repair shape: refuse authority evidence whose kind is a
   computation-surface struct/map (e.g. `ComputationClaim`/`PlanningAdvice`)
   with a typed refusal at `admit_authority/2`, or require a typed
   authority-evidence schema. Suggested order: follow-up work order
   (`XAAS-W763-G1`).
   `lib/xaas/actuation.ex:576`.
2. **FINDING (mislabeled refusal)**: `ComputationClaim.new/1` reports an
   out-of-vocabulary `evidence_class` under
   `{:computation_claim_standing_refused, class}` because the else-clause
   binary catch-all matches before an evidence-class clause can; the label
   "standing_refused" is wrong for an evidence-class failure.
   `lib/xaas/semantics/computation.ex:170-171`. Suggested order `XAAS-W763-G2`.
3. **No fabrication**: the court deliberately asserts the measured
   succeeded-shape rather than an invented refusal; a future repair of gap 1
   will flip the tagged test `@tag :w763_measured_gap` to assert
   `{:error, _}`. Tagged test lives in
   `test/xaas/sa2a_computation_boundary_test.exs`.

## Falsifiers

- Gap 1 falsifier: after a kernel repair, the tagged test flips to refusing —
  if `run/4` still succeeds with a claim as authority, the gap is alive.
- Mutation falsifier for (d): the full 7-field mutation table
  (all refused with the exact field named) is the non-vacuity proof for
  `conserve/3`'s field-naming contract.
- Determinism falsifier: seeds default/7/1 all 20/20.

## Standing

- Computation surface (construction/validation/hash/determinism): **ALIVE**
  (observed execution on this subject).
- `order_formal/2` filter semantics: **ALIVE**.
- `Route.conserve/3` first-differing-field + exactly-one-data-part: **ALIVE**
  (mutation-table non-vacuity).
- Candidate-cannot-authorize at the `run/4` authority channel: **BLOCKED**
  (gap `XAAS-W763-G1`; boundary holds only at construction and route layers).

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW763 \
  mix test test/xaas/sa2a_computation_boundary_test.exs   # expect 20 passed
```

Build root `_build-laneW763` deletion was denied by the permission system;
left for the coordinator per lane contract. Probe scratch dir
`probe_w763/` fully removed. `HEAD a0723bf6` unchanged; nothing committed.
