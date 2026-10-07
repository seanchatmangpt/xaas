# W704 — Quiescent-stop deepening (Art. 27.3 court)

- **Lane**: W704, xaas v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface`
- **Date**: 2026-10-07
- **Standing**: ALIVE (new tests executed green on the exact subject)

## Order

Backlog: Art 27.3 (safeguards when risks materialise) cites the quiescent-stop
attractor (title_iii "27.3" evidence row). Deepen
`test/xaas/actuation/quiescent_stop_test.exs` with a Chicago-style deepening
court. No product-code change; test + receipt only. DO NOT commit (lane law).

## μ / diff (handwritten; no generator exists for this surface)

- NEW `test/xaas/actuation/quiescent_stop_deepening_test.exs` — 7 tests,
  `@moduletag :eu_ai_act` (in-file comment names 27.3), real sandboxed
  Postgres, real `Xaas.Actuation.QuiescentStop.execute/2`, real
  `Xaas.Semantics.OversightGovernance.fria/0`, real
  `Xaas.Semantics.VulnerabilityLifecycle`. No mocks.

Coverage:
1. Halt-to-safe-state idempotency: same-key second halt is a no-op
   (`%{already_stopped: true}`, `ActuationReceipt` count unchanged, subject
   stays `:suspended`); three fresh-key halts post-attractor all refuse
   `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT` without un-halting.
2. Typed refusal on malformed context: 8 malformed authority shapes
   (string/atom/integer/nil/missing kind/missing source/empty kind/empty
   source) all `{:error, :REFUSED_STOP_AUTHORITY}`; 6 malformed idempotency
   keys all `{:error, :idempotency_key_required}`; subject untouched
   (`:pending`) in both cases.
3. Determinism x3: three fresh halts produce identical receipt shape
   (`target: :quiescent`, echoed authority, `%DateTime{}` stopped_at);
   same-key replay x3 returns identical `{:ok, %{already_stopped: true}}`.
4. Composition with Art 15.5.s3 lifecycle materialisation: the halt record
   opens a real `VulnerabilityLifecycle` (`:DETECTED`), and
   `OversightGovernance.fria/0` consumes the post-halt world without
   contradiction — `assessment_class: :deployer`, all rights typed
   `:EVIDENCED`/`:OPEN_GAP`, the honestly-recorded OPEN_GAP
   materialisation channel still present, halt receipt fields agree with
   post-halt subject state.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW704 \
  mix test test/xaas/actuation/quiescent_stop_deepening_test.exs --include eu_ai_act
# Result: 7 passed (1.1s async)   exit 0

# regression guard on the pre-existing court:
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW704 \
  mix test test/xaas/actuation/quiescent_stop_test.exs
# Result: 5 passed               exit 0
```

One repair round: dropped a redundant `assert fria.rights != []` after the
compiler flagged it as a static type warning (the `Enum.any? OPEN_GAP`
assert already proves non-emptiness). Re-ran green, warning-free.

## Verification ladder

narrow (new court) → narrow (sibling court regression) → done. Ladder stops
here by lane scope (single-surface deepening; full `mix test` is coordinator
integration territory).

## R / replay

- Replay: the two commands above on `a0723bf6` with the new test file present.
- Transport failures: one harness permission refusal on `rm -rf
  _build-laneW704` (lane lease cleanup) — **`_build-laneW704` left on disk for
  coordinator deletion** per the lease law's else-branch.
- Git: no commit made (lane law; coordinator owns integration).

## Falsifiers

- A second halt emitting a new `ActuationReceipt` row, or flipping subject
  status away from `:suspended`.
- Any malformed context shape admitted (vacuous authority/key gate).
- Non-deterministic receipt shape across 3 runs or 3 replays.
- `fria/0` raising or losing its typed OPEN_GAP materialisation entry after
  a real halt.

All falsifiers ran and failed to fire (tests green).
