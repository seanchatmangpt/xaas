# W666 — OCEL 2.0 egress deepening (Art. 12 / Art. 19 evidence lines)

Lane W666, xaas v26.10.6, branch `feat/playwright-surface`, base subject
`a0723bf61a1c6058bdcd2d0202c9519840182a5e` (uncommitted diff on top, per lane rules — no commit).

## Before

Deepening target modules: `lib/xaas/telemetry/ocel_ash_emitter.ex`,
`lib/xaas/telemetry/ocel_ndjson.ex` (read-only). Existing coverage:
`test/xaas/telemetry/ocel_ash_emitter_test.exs` (outcomes, reshape field law,
fail-safe), `ocel_ash_emitter_rotation_test.exs`
(production defaults pin, sandbox rotation laws, one real over-cap append),
`ocel_ndjson_test.exs` (assembly laws: dedup, blank lines, legacy tripwire,
typed refusals for malformed JSON / missing keys / bad declarations). No
existing file asserted event/object correlation replayed from real disk bytes
across a multi-line log plus the aggregate court run over the same file, nor
a repeated-rotation disk bound with survivor identity, nor the
no-fabricated-record law after an unencodable payload.

## After

New file `test/xaas/telemetry/ocel_egress_deepening_test.exs` (378 lines, 6 tests,
Chicago-style: real emitter -> real ndjson bytes on disk -> parse back ->
real court; no mocks):

1. **Correlation replayed from disk** — 3 real `handle_event/4` emissions
   (ok with real `Ash.Seed.seed!` actor + tenant, error outcome via the real
   `Ash.Tracer.set_handled_error/2` callback, degraded unknown-resource
   fallback) -> 3 real lines in the real test-env log -> parsed back from the
   bytes: every relationship resolves in-line, qualifier == referenced
   object's type lowercased, every used type declared in-line, real UUID event
   ids (distinct), zero-offset ISO times, real actor primary key in the actor
   object id, and the aggregate passes the real court (`Xaas.Ultracode.Ocel.Validator`
   via `OcelNdjson.validate_ndjson_file/1`: 3 events, 4 deduplicated objects,
   types book/user/Tenant/unknown).
2. **Rotation bound over real files** — 5 real `maybe_rotate` generations
   (cap 50 B, keep 2) on sandbox files: exactly `.1`+`.2` survive, no `.3`,
   `.1`=gen5 / `.2`=gen4, footprint <= keep x cap.
   Plus a real over-cap append through the REAL `handle_event/4` against the
   real test-env log: over-cap generation survives byte-identical in `.1`
   (no evidence lost by rotation), post-rotation live log still court-valid.
   Production defaults (10 MiB / keep 2) pinned.
3. **Typed behavior on malformed payloads** — an unencodable payload (pid in
   a raw attribute) raises nothing into the caller AND appends no line (the
   Art. 12 log never contains a record that was not built); malformed JSON,
   missing top-level keys, and malformed type declarations each fail closed
   with typed violations at exact line paths, with the good line alone still
   validating; a legacy flat-event line is refused by name through the full
   file->court path.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW666 \
  mix test --include eu_ai_act test/xaas/telemetry/ocel_egress_deepening_test.exs
```

Real green tail (run 4, `/tmp/w666-run4.log`):

```
Result: 6 passed
Finished in 0.7 seconds
```

Note: `:eu_ai_act` is excluded by the repo's default tag-exclusion list, so the
verification gate is `mix test --include eu_ai_act <file>` (plain `mix test <file>`
reports "All tests have been excluded", exit 0 — that is a vacuous pass and was
disclosed here, not counted).
Also disclosed: first run failed with a compile error (`@moduletag` before
`use ExUnit.Case`), second run 4/6 (rotation survivor off-by-one — test bug,
fixed forward), third run 5/6 (aggregate object_count 2 vs. real 4 — test
assertion wrong vs. real law, fixed forward). All fixed forward, no resets.

## Standing

- Test file: ALIVE — real green run on subject `a0723bf6` + this diff.
- `@moduletag :eu_ai_act`: GENUINE — the file feeds an Art. 12
  (record-keeping) disposition: it proves the automatic OCEL 2.0 event log is
  internally correlated, size-bounded, and fail-closed on malformed input,
  replayed from real disk bytes. Comment in the file says exactly this.
- Aggregate: PARTIAL_ALIVE — this lane ran only its own file (per lane rules);
  the full suite was not run and full-suite standing is the coordinator's.
- Lane build root `_build-laneW666` deleted at lane end (or left for the
  coordinator if rm is denied).
