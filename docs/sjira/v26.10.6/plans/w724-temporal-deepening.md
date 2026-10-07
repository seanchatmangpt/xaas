# W724 — Temporal Memory Deepening (receipt)

- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6` (uncommitted lane; no commit made per dispatch).
- Backlog item: `Xaas.TemporalMemory` (bitemporal Observation / `as_of/2` / deterministic replay verifier) undocketed.
- Files read: `lib/xaas/temporal_memory.ex`, `lib/xaas/temporal_memory/{observation,query,replay,changes}.ex`, `test/xaas/temporal_memory/{observation_test,query_and_replay_test}.exs`.
- File written: `test/xaas/temporal_memory_deepening_test.exs` (only new file; hand-written, 0 generated).

## Coverage (4 tests, all passing)

- **(a) retroactive insertion order**: O1 written first (valid from t), O0 superseding row written later claiming the same earlier valid interval. Asserts `latest_per_subject` picks the later-recorded O0 at unbounded `t_o`, a `t_o` bounded between the writes still resolves O1, `lineage_at/2` really holds both rows, and `o0.observed_at > o1.observed_at` (real server-set observation times).
- **(b) retroactive-safe mutation semantics (real contract)**: `:supersede` stamps only the prior row's `superseded_by_id`; prior `fact`, `valid_from`, `observed_at`, `receipt_hash` byte-identical on reload; prior `as_of/2` view (bounded `t_o` before correction) still returns the original row/hash; correction row points back via `supersedes_id`. No gap — the documented non-destructive contract holds.
- **(c) replay verifier**: `Replay.verify/2` bounded before the correction reproduces the O1 receipt (`observation.id`, `receipt_hash == o1.receipt_hash`, `valid_time`/`observation_time` echo the bounds); `replay_matches?/3` distinguishes a perturbed sequence (different fact, same subject/valid-time shape) from the real history, and rejects `nil` expected hash; verify's no-leak invariant checked (`observed_at <= t_o_bound`).
- **(d) determinism ×3**: three consecutive `Replay.verify/2` runs against a *pinned* `observation_time` agree on `receipt_hash`. (First draft used the implicit `now()` default per call and failed — determinism is a property of a fixed bitemporal query; fixed by pinning the bound.)

## Commands (real runs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW724 \
  mix test test/xaas/temporal_memory_deepening_test.exs
→ Result: 4 passed (0.6s)

... mix test test/xaas/temporal_memory   (regression, existing suite)
→ Result: 10 passed
```

Chicago discipline: real Postgres sandbox (`Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)`), real Ash `:observe`/`:supersede`/read actions, assertions on reloaded row state. No mocks (mock gate not needed — no mocking constructs present in the file).

## Standing

- Lane tests: **ALIVE** (executed on exact subject, real output above).
- Existing temporal suite: **ALIVE** (10 passed).
- `@moduletag :eu_ai_act`: **not applied** — content is the campaign's own process memory, not an Art-12 record-keeping boundary; no in-file justification claimed.

## Typed gaps

- `UNSUPPORTED(concurrent-corrections)`: two independent supersession branches per subject remain out of scope by the module's own documented contract (`Query` UNSUPPORTED note) — not exercised here.
- `UNSUPPORTED(tstzrange-storage)`: plain `valid_from`/`valid_to` columns, per the domain moduledoc — unchanged by this lane.
- Coordinator action: `_build-laneW724` deletion was denied by the session permission system; build root left in place for coordinator cleanup (allowed fallback per dispatch).
