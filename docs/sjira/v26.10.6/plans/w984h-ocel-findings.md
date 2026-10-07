# Lane W984h — OCEL typed-finding fixes — receipt

- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `49a719ab`
  (no commit made — write-only lane: 2 lib fixes + test extension + this receipt only).
- **Fixes applied** (both W983e typed findings):
  1. **Deterministic ordering** — `lib/xaas/ocel/case_view.ex`:
     - `EventObject` query now carries `Ash.Query.sort(id: :asc)` (stable DB-side order).
     - In-memory sort is now a total-order law:
       `Enum.sort_by(&{DateTime.to_unix(&1.occurred_at, :microsecond), &1.id})` —
       `(occurred_at, id)` ascending with an exact-microsecond DateTime compare
       (term order on `DateTime` structs is field-alphabetical, not chronological,
       which is why the unix-microsecond key is used).
  2. **Destroyability** — `lib/xaas/ocel/event.ex`: `defaults([:read, :destroy])`
     → `defaults([:read])`. Grep of lib+test for Ocel.Event destroy consumers found
     **zero callers** (only a regex literal in a surface test and this lane's own new
     court), so the drop (not policy-gate) disposition applies.
- **Files written**
  - `lib/xaas/ocel/case_view.ex` (tiebreak fix)
  - `lib/xaas/ocel/event.ex` (drop :destroy default)
  - `test/xaas/ocel/w983e_ocel_log_courts_test.exs` (appended court 5 + court 6;
    also added `require Ash.Query` — first run caught a missing-require compile
    error, fixed, re-run clean)
  - `docs/sjira/v26.10.6/plans/w984h-ocel-findings.md` (this receipt)
- **Commands** (`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984h`):
  - `mix compile` (fresh lane build root) → exit 0
  - `mix test test/xaas/ocel/` → **36 passed, 3 excluded** (run 1)
  - `mix test test/xaas/ocel/ --seed 13579` → **36 passed, 3 excluded** (run 2, ×2
    on the same fresh lane root; both green; 33 prior + 3 new tests)
- **Standing: ALIVE** (exact subject, observed execution, real tails above).

## Per-finding disposition

| # | W983e finding | disposition | evidence |
|---|---|---|---|
| 1 | tie order nondeterministic (`case_view.ex:51`) | FIXED | court 5: two events at identical usec timestamp derive in ascending-id order, identical across 2 real derives in one run, whole dir green ×2 seeds |
| 2 | `defaults([:read, :destroy])` on audit surface | FIXED (drop, not gate) | court 6: introspection asserts zero destroy actions; real `Ash.destroy` via `for_destroy(:destroy)` raises real refusal; row still readable; `(event_type, ocel_id)` identity still refuses duplicate re-record |

## Verification ladder
narrow (new courts) → dir census ×2 seeds on fresh lane build root
`_build-laneW984h` — **left for coordinator** (lane-lease law cleanup: the lane's
own `rm -rf` was permission-denied in this session; deletion is the coordinator's
integration step).

## Falsifiers (how to kill this receipt)
- Remove the id sort from the `EventObject` query or the `{occurred_at, id}`
  sort_by in `derive_for_object/2` → court 5 fails (tie order nondeterministic).
- Re-add `:destroy` (or any destroy action) to `Xaas.Ocel.Event` → court 6
  introspection test fails.
- Introduce a destroy consumer elsewhere without an explicit receipt → court 6's
  real-API destroy-refusal assert documents the contract this fix establishes.
