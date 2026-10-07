# W984bt — OCEL telemetry-egress depth court (receipt)

- **Lane**: W984bt, campaign v26.10.6, repo `/Users/sac/xaas`
- **Subject**: new file `test/xaas/ultracode/w984bt_ocel_egress_depth_test.exs` (5 tests) + this receipt. No lib/ changes. Not committed (lane law: coordinator owns commits).
- **Surface**: `Xaas.Telemetry.OcelAshEmitter` (`lib/xaas/telemetry/ocel_ash_emitter.ex`) + `Xaas.Telemetry.OcelNdjson` (`lib/xaas/telemetry/ocel_ndjson.ex`) + `Xaas.Ultracode.Ocel.Validator` (`lib/xaas/ultracode/ocel/validator.ex`) over the real `priv/ocel/ash-actions.ndjson` line protocol.

## Coverage subtraction (read-first)

Covered slices excluded per lane contract:
- W983e courts 4/6 (`test/xaas/ocel/w983e_ocel_log_courts_test.exs`): refusal-capture, destroy floor.
- Existing emitter courts (`test/xaas/telemetry/ocel_ash_emitter_test.exs`): outcome discrimination via real actions, per-field laws incl. one drop_nils case (resource_description), unknown fallback, unencodable-payload `:ok` return.
- Rotation courts (`ocel_ash_emitter_rotation_test.exs`), egress deepening (`ocel_egress_deepening_test.exs`: aggregate-across-rotation, malformed fail-closed, legacy-shape refusal, disk bound), validator unit tree (`test/xaas/ultracode/ocel/validator_test.exs`).

## The five tests (per-test invariant + mutation rationale)

1. **Batch N/0 line-format contract** — 8 emissions through the REAL `handle_event/4` land exactly 8 lines; each line is individually `{:ok, "valid", event_count: 1}` under the court; the whole batch assembles through real `OcelNdjson.validate_ndjson_file/1` at exactly `event_count == 8`, `object_count == 2` (dedup collapses 8× `book` + 1× `tenant:org-bt-1`), with all emitted event types declared. *Mutation killed*: any per-line shape regression (extra key, undeclared type, dangling relationship, non-UTC time) flips a per-line verdict; an assembly-law regression (lost declaration union, broken object dedup) flips the aggregate verdict/counts.
2. **Time/monotonic law** — event `"time"` parses `{:ok, _, 0}` (ISO8601, zero offset) for every emission; times non-decreasing in append order and STRICTLY increasing across a real `Process.sleep(2)` clock advance; ids unique non-empty; `duration_ms` exact native→ms conversion. *Mutation killed*: a local-time/naive time source (offset ≠ 0 or unparseable), a frozen per-test time, id reuse, or a wrong duration conversion each fail.
3. **Payload-minimality law** — an emission whose truly-nullable enrichments (actor, tenant, `authorize?`, duration, description) are all nil yields a raw line containing NO `null` bytes and attributes equal EXACTLY to domain/resource/action/outcome plus the real introspected `public_attribute_count` (measured: 12 for `Xaas.Library.Book`); objects/relationships exactly the class-level `book` object. *Mutation killed*: reintroducing `"key": null` entries (lost `drop_nils`), a fabricated default fact, or a fabricated actor/tenant object id.
4. **Concurrent emission interleaving** — 12 processes × 3 emissions append concurrently; delta is exactly 36 lines, every line JSON-decodable (no torn/interleaved bytes), every line court-valid, aggregate valid at `event_count == 36`, `object_count == 1`, and every observed event type belongs to the emitted multiset. *Mutation killed*: non-atomic append or shared-handle corruption producing torn lines; per-line shape drift; dedup/aggregate regression.
5. **Egress failure isolation across a batch** — an unencodable (pid-valued attribute) emission mid-batch returns `:ok`, fabricates NO line, leaves no torn bytes, and the before/after valid emissions land as exactly `["book.create", "book.destroy"]`, both court-valid, aggregate `event_count == 2`. *Mutation killed*: the append `rescue` leaking into the caller, a partial-line write, or mis-ordered subsequent appends.

## Commands + exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bt \
  mix test test/xaas/ultracode/w984bt_ocel_egress_depth_test.exs
=> Result: 5 passed   (fresh lane root, cold compile ~18 min)
=> Result: 5 passed   (warm rerun, 0.4s)
```

×2 fresh-root: WITNESSED — forced full `mix compile --force` under the lane root, then reran: `Result: 5 passed` (exit 0). Both runs green: cold-compile run and forced-recompile run.

## Standing

- Tests 1, 2, 3, 4: **ALIVE** — real handle_event emissions against the real file, real court verdicts, all observed green.
- Test 5: **ALIVE** — real rescue path witnessed (real `Logger.error` disclosure of `Jason.Encoder` Protocol.UndefinedError captured in the run output); the mid-batch `:ok` + exact-line assertions are the witnessed consequence.
- Note (pre-existing, disclosed): test 3's expected attribute set includes `public_attribute_count` (non-nil for any real resource) — the truly-nullable law is narrower than "all nullable keys nil"; pinned to real introspection, not a hard-coded 12.

## Cleanup

Build root `_build-laneW984bt` (426 MB): `rm -rf` denied by the permission system in this lane session (same refusal class as W984aj). LEFT FOR COORDINATOR to delete at integration.
