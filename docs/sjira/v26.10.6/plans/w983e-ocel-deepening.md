# Lane W983e — OCEL event-log deepening courts — receipt

- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `6f235905`
  (no commit made — write-only lane: 1 test file + this receipt only).
- **Files written**
  - `test/xaas/ocel/w983e_ocel_log_courts_test.exs` (new; 4 courts / 6 tests)
  - `docs/sjira/v26.10.6/plans/w983e-ocel-deepening.md` (this receipt)
- **Commands** (all `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983e`):
  - `mix compile` → exit 0 (fresh lane build root)
  - `mix test test/xaas/ocel/w983e_ocel_log_courts_test.exs` → **6 passed** (seed 62270)
  - `mix test --seed 987654 ...` → **6 passed** (run ×2 on the fresh lane root; both green)
  - `mix test test/xaas/ocel/` → **33 passed, 3 excluded** (whole Ocel dir; no regressions;
    the 3 excluded are pre-existing tag exclusions)
- **Standing: ALIVE** (exact subject, observed execution, real tails above).

## Per-court findings

### Court 1 — append immutability — PASS
- `Xaas.Ocel.Event` (`lib/xaas/ocel/event.ex`) declares exactly
  `defaults([:read, :destroy])` + create `:record`. Introspection court: zero
  update actions of any name. Real-API court: `Ash.Changeset.for_update(event, :update, %{})`
  raises `Ash.Changeset.raise_no_action` ("Available update actions:" — empty) — a real
  refusal raised in-process; no update path mutates a written event row.
- **Typed finding (report-only)**: `defaults([:read, :destroy])` also exposes **destroy**.
  The event log is therefore append-only against *update* but NOT against *deletion* —
  any caller with write authority can delete events (and, given the
  `(event_type, ocel_id)` identity, free the identity for re-recording). If the log is
  meant to be a durable audit surface (Art. 12-adjacent), the destroy default should be
  removed or policy-gated. Not fixed here (write-only lane; fix is a one-line
  `actions do defaults([:read]); create :record do ...` change + court).

### Court 2 — event ordering — PASS with typed finding
- Distinct-timestamp court: 3 events written out of chronological order on one object,
  read via real `Xaas.Ocel.CaseView.derive_for_object/2` → strictly ascending `occurred_at`
  total order. Real query + real in-memory sort; passes.
- **Typed finding (report-only)**: equal-timestamp ties have **no deterministic order**:
  `derive_for_object/2` (`lib/xaas/ocel/case_view.ex:51`) sorts only by `occurred_at`
  (no id tiebreak) and the `EventObject` query carries no `order_by`, so tie order is
  DB-return-order dependent. For a total-order `(timestamp, id)` law the sort should be
  `Enum.sort_by(&{&1.occurred_at, &1.id})` plus an explicit `Ash.Query.sort/2`. The
  REPORT-ONLY tie test in the file asserts only what holds today (permutation with
  non-decreasing timestamps) and never asserts a tiebreak law the code does not implement.

### Court 3 — conformance replay input shape — PASS
- Real pipeline: 2 objects + 2 events via real `Event :record` (multi-object relations,
  attributes, usec timestamps) → `Xaas.Ocel.Projection.project/1` → rename event ids
  (the `(event_type, ocel_id)` identity refuses duplicate re-record — itself more
  append-immutability evidence) → `Xaas.Ocel.Projection.import/1` → `project/1` again.
  Asserted field-for-field equality of `type`, `time` (ISO8601 usec-exact), `attributes`,
  `relationships` (sorted by objectId), plus `objectTypes`/`eventTypes` equality.
  No loss. (Original-destroy variant deliberately avoided: `Event.destroy` is exactly the
  court-1 finding, not something a replay court should depend on.)

### Court 4 — failure-event capture — PASS
- Real refusal path: `Event :record` with empty `:object_relations` refused by
  `Xaas.Ocel.Changes.RelateEventToObjects` before any row is written
  (`{:error, _}` from real `Ash.create/2`).
- Real capture: the global `Xaas.Telemetry.OcelAshEmitter` (attached via
  `config :ash, :tracer` + `attach!/0` from `Xaas.Application`) emits a real
  `priv/ocel/ash-actions.ndjson` line for the refused action with
  `type: "event.record"`, `resource: "Xaas.Ocel.Event"`, `action: "record"`,
  **`outcome: "error"`** (via the real `Ash.Tracer.set_handled_error/2` → process-dict
  chain). Line passes `Xaas.Ultracode.Ocel.Validator.validate/1` (real OCEL 2.0 court).
  Read scoped to this test's own delta of the shared ndjson (same offset-delta discipline
  as `test/xaas/telemetry/ocel_ash_emitter_test.exs`).
- Binding note: the capture is the *telemetry egress* OCEL surface (per-line OCEL 2.0
  documents in ndjson), not an `Xaas.Ocel.Event` row — refused operations do not write
  `ocel_events` rows, which matches the documented design (event rows carry real actions;
  the emitter carries outcomes including error). Asserted as the documented behavior.

## Verification ladder
narrow (per-test) → dir census (33 passed). Both runs on fresh lane build root
`_build-laneW983e` — **deleted** post-receipt per lane-lease law.

## Falsifiers (how to kill this receipt)
- Add an `update` action to `Xaas.Ocel.Event` → court 1 introspection test fails.
- Remove the empty-relations refusal → court 4 gets no error-outcome line.
- Reorder/drop the `occurred_at` sort in `derive_for_object/2` → court 2 fails.
- Change `Projection.project/import` field laws → court 3 field-for-field assert fails.
