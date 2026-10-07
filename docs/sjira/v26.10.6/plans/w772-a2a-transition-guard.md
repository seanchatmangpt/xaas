# W772 — A2A Task Forward-Only Transition Guard (Lane Receipt)

- **Lane**: W772, campaign v26.10.6, repo `/Users/sac/xaas`
  (canonical checkout, branch `feat/playwright-surface`, HEAD `a0723bf6`).
- **Subject**:
  - `lib/xaas/a2a/task.ex` — +1 line: `validate(Xaas.A2a.Validations.ForwardOnlyTransition)` on `:update`.
  - new `lib/xaas/a2a/validations/forward_only_transition.ex` — the guard (house idiom mirror of
    `Xaas.Ultracode.Validations.RunTransitionAllowed`: explicit allow-list, typed
    `Ash.Error.Changes.InvalidChanges` refusal).
  - `test/xaas/a2a_resources_deepening_test.exs` — a3 rewritten from "honest absence" to
    "assert the actual machine" (it pinned the exact gap this lane repairs, so it had to
    move with the behavior); new courts a3b, a3c. Moduledoc (a) updated to match.
    No other files touched. Not committed (lane contract: coordinator owns commits).
- **Build isolation**: `MIX_BUILD_ROOT=_build-laneW772`, `MIX_ENV=test`,
  `PATH=$HOME/.asdf/shims:$PATH` (pinned toolchain elixir 1.20.2-otp-28).

## Edge choice (documented, conservative)

Consumer evidence for `Xaas.A2a.Task.status` is THIN: the only status writers in the tree
are tests (catalog_test, deepening test; `Catalog` has no status writer). So the
conservative rule is chosen and documented in the validation's moduledoc:

- Self-transitions `{s, s}` allowed (an artifacts-only `:update` must not be refused).
- Forward edges per the A2A semantics the existing `one_of` set implies:
  `submitted -> working/input_required/completed/failed`;
  `working -> input_required/completed/failed`;
  `input_required -> working/completed/failed`.
- **Terminal-is-terminal**: `:completed` / `:failed` absorb — NO edge leaves them.
  (`:cancelled` is not in the `one_of` set; refused upstream by membership.)

## Falsifier

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW772 \
  mix test test/xaas/a2a_resources_deepening_test.exs
```

Last real runs (real tails):

```
Result: 11 passed          (deepening file, with guard)
Result: 6 passed           (test/xaas/a2a/ catalog tests, with guard)
Result: 24 passed, 9 excluded  (test/xaas_web/a2a/ + a2a_v1_wire_deepening_test.exs, with guard)
```

## Mutation run (guard dropped via in-place sed, then restored)

```
Result: 9/11 passed
```

The 2 kills are a3 and a3b: a3's
`assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{}]}}` on
`completed -> submitted`, and a3b's per-status refusal loop out of `:failed`. Guard
restored → 11 passed again (same run reproduced).

## Pre-existing defect found and fixed en route (same test file, same subject)

W751's a3 had a real Elixir-scoping bug: `for next <- walk do task = task |> update! end`
does not leak the rebind out of the comprehension — the walk never advanced; every step
was `:submitted -> :submitted` (self-transition). W751's court therefore never actually
exercised `completed -> submitted` as claimed. a3 now uses `Enum.reduce` so the walk is
real. This is why W751's "absence" pin and this lane's guard could both "pass" — and why
the mutation run killed a3 only after the scoping fix.

## Standing

- **ALIVE** for the asserted behavior (typed refusal of non-admitted edges; forward walk
  and self/artifacts-only update still lawful) on the exact subject above.
- Task file diff is 1 line; guard is a real `Ash.Resource.Validation` (no mocks, real ETS
  store, real actions).

## Open / not repaired by this lane

- W751's UNSUPPORTED(referential-integrity) gap (`agent_id` has no FK) remains as pinned.
- `_build-laneW772` could not be deleted (lane `rm -rf` denied by permission system) —
  left for the coordinator per the cleanup law.
