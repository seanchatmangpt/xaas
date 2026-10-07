# W984cy3 — Ultracode family probe (coverage census + depth court)

Lane: W984cy3 · Campaign: xaas v26.10.6 · Subject: branch
`feat/playwright-surface`, working tree (uncommitted, shared checkout) ·
Date: 2026-10-07 · No commits made (lane law).

## Files written

- `test/xaas/ultracode/durable_close_court_test.exs` (new, 5 tests)
- `docs/sjira/v26.10.6/plans/w984cy3-ultracode-probe.md` (this receipt)

## Family census

The W984cj map's method (snake_case module-name content grep in `test/`) is
**method-flawed**: it misses every reference via CamelCase aliases, including
`alias Xaas.Ultracode.{...}` brace lists. Re-run the census with the bare
CamelCase simple name (word-bounded grep over `test/`):

- Map method (snake grep): 21 zero-hit modules — matches the map's count but
  is an artifact: e.g. `provider_registry`, `closure_controller`,
  `capability_resolver` (a dedicated `provider_registry_test.exs` and
  `closure_controller_test.exs` exist and reference the modules).
- Corrected method (CamelCase grep): **3 genuinely uncovered modules**:
  `DurableClose` (91 lines), `ProcessGroup` (54), `SubstitutionPolicy` (101).

File-path vs content grep distinction: filenames alone don't count; only
module-name content references, per the map's method shape.

## Court (1 depth court, best state-bearing candidate)

**Candidate: `Xaas.Ultracode.DurableClose`** — the lease-fenced Git
publication primitive (real Postgres Epoch lease row under a `FOR UPDATE`
row lock + real `git update-ref` CAS). Chosen over `ProcessGroup` (thin
`System.cmd` wrapper) and `SubstitutionPolicy` (compile-time TTL reader +
pure validation, no durable state).

Court file: `test/xaas/ultracode/durable_close_court_test.exs`

Court invariants and mutation rationale per test:

1. **Durability**: live lease publishes; `:ok` must mean bytes-on-disk —
   HEAD asserted via `git rev-parse HEAD`, reflog message asserted. Kills
   the mutant that returns `:ok` without running update-ref.
2. **Fence (no row)**: unknown token → `{:lease_lost, :no_lease, commit}`;
   HEAD unmoved. Kills skip-lease-lookup mutant.
3. **Fence (expired)**: `lease_expires_at` in the past →
3. **Fence (expired)**: `lease_expires_at` in the past →
   `{:lease_lost, :lease_expired, commit}`; HEAD unmoved. Kills the
   wrong-direction / dropped expiry comparison.
4. **Fence (state)**: epoch completed via the lawful `:complete` action →
   `{:lease_lost, {:lease_not_live, :completed}, commit}`; HEAD unmoved.
   Kills dropped-state-comparison mutant.
5. **Typed refusal**: nonexistent commit object →
   `{:refuse, :ref_update_failed, %{"unreferenced_commit" => ...}}`; HEAD
   unmoved. Kills swallow-git-failure-as-:ok mutant.

All tests: real Postgres Epoch rows via Ash (tenant-supplied — Epoch/Run are
tenant-`:enforce`d for writes; `:read_unscoped` is the global read), real
temp git repos on disk, real `System.cmd` git. Chicago-style; zero mocks.

## Verification (real output)

- Run 1 (`MIX_BUILD_ROOT=_build-laneW984cy3`, fresh full compile):
  `Result: 5 passed` (after two Ash-callsite repairs: changeset-form
  `Ash.Changeset.for_update` instead of ambiguous `Ash.update!/3` arity;
  tenant required for Epoch writes).
- Run 2 (`MIX_BUILD_ROOT=_build-laneW984cy3-r2`, fresh full compile):
  first attempt hit a **transient compile error** in
  `lib/xaas/semantics/graphlaw_wasm.ex:440` on the fresh root (not
  reproducible on immediate recompile; no test code involved — disclosed as
  a pre-existing build-race, not session-introduced). Retry:
  `Result: 5 passed`.

## Disposition of the rest (typed)

- `ProcessGroup` — real OS group kill, thin surface (`kill/1..3`,
  `alive?/1`), OS-interaction court candidate; not courting this lane
  (one court per lane task). Standing UNKNOWN.
- `SubstitutionPolicy` — compile-time TTL reader + pure `admit_receipt/1`
  validation; no durable state; courtable in a pure-property court;
  standing UNKNOWN.

## Standing

- `DurableClose` lease-fence invariants: **ALIVE** (5/5 ×2 fresh roots,
  real Postgres + real git).
- Ultracode family coverage census: **O-corrected** — map's 21-module list
  is a grep-method artifact; true uncovered set = {DurableClose (now
  covered by this court), ProcessGroup, SubstitutionPolicy}.

## Lane hygiene

Build roots `_build-laneW984cy3` and `_build-laneW984cy3-r2` left for
coordinator (lane-lease cleanup; `rm -rf` was permission-denied in this
lane).