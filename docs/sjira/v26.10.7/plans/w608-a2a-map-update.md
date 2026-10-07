# W608 — ash_a2a Map.update sweep (v26.10.7, WP-4 / OS-20)

- **Repo / subject**: `~/ash_a2a` @ `b588c55c22580885e9fb56f18a4dac4a3f0133ba` (branch `main` checkout state; dirty from other waves — untouched, worked around)
- **Toolchain** (`.tool-versions`): elixir 1.20.4-otp-29 / erlang 29.1.1, asdf shims
- **Build root**: `_build-laneW608` (fresh root; **deleted at integration** per fanout cleanup law)
- **Diff surface**: exactly one new file, `~/ash_a2a/test/ash_a2a/w608_map_update_court_test.exs` (court only). **Zero lib/ patches.** No commit (per directive).

## Runtime probe (ground truth, recorded)

`elixir -e` on the pinned toolchain, OTP 29.1.1 / Elixir 1.20.4:

```
absent-key update/4: %{k: 1}          # default stored verbatim, fun NOT applied
present-key update/4: %{k: 6}         # standard
absent-key list default: %{k: [0]}    # verbatim
40+keys absent: 1                     # large maps identical
:maps.update absent: :raises          # :maps.update/3 still raises on absent key
update! absent-key raises: KeyError
```

**Finding**: on the exact pinned toolchain, `Map.update/4` absent-key semantics are
the **documented standard** (default verbatim, fun not applied) across small maps,
40+-key maps, and structs. No deviation observed. The OS-20 memory
("60 accumulator sites rely on the deviation") does not manifest on
OTP 29.1.1 + Elixir 1.20.4 in this repo. A struct probe initial failure was my
probe's own present-`nil`-key artifact, not a semantics deviation.

## Sweep + classification (W606 rubric)

`grep -rn "Map.update" lib/` → **42 sites in 22 files** (including comments).

### Already dual-safe (prior OS-20 wave, HEAD b588c55c) — verified in place

task_events.ex:142, entropy.ex:27, court.ex:333, ocel/log.ex:177,
validator.ex:841 (warn), ocel_validity.ex:776/787, protocol/agent/state.ex:138
(track_context), workload_watcher.ex:337/388, trace.ex:180.

### Class (b) — default-intended, left + disclosed (0 patches)

Every remaining site. The 5 bare `Map.update/4` accumulator sites are all
**idempotent-fun** (`fun(default) == default`), so identical under either
absent-key semantics:

| Site | Form | fun(default) test |
|---|---|---|
| chicago/closure/court.ex:359 | `Map.update(acc2, to, MapSet.new([from]), &MapSet.put(&1, from))` | `MapSet.put(new([from]), from)` = same set → idempotent |
| chicago/observer/journal.ex:207 | `Map.update(acc.drops, inc, total, &max(&1, total))` | `max(total, total)` = total → idempotent |
| runtime_identity/execution.ex:285 | `Map.update(state.beam, key, {pid, memory}, fn {p, m} -> {p, max(m, memory)} end)` | `{p, max(m,m)}` = same → idempotent |
| telemetry/allocation_counters.ex:136 | `Map.update(acc, class, %{r => c}, &Map.put(&1, r, c))` | put over itself → idempotent |
| c2/memory_claim_store.ex:21 | `Map.update(&1, d, {0, {completed, r}}, fn {g,_} -> {g, {completed, r}} end)` | {0,...} → {0,...} → idempotent |

Every `Map.update!/3` site has its key guaranteed present at the point of call
(struct defaults / reduce init / `Map.fetch!` guard / schema-loaded artifact):

| Site | Key source (presence guarantee) |
|---|---|
| trace.ex:125/159/299/301 ("attributes"/"events") | spans created at trace.ex:144–146 with both keys; events created with both |
| observer.ex:838 `:records` | init `records: []` (observer.ex:605) |
| sut_events.ex:90 `:events` | init at sut_events.ex:74 `%{events: [], ...}` |
| journal.ex:177/178 `:records`/`:run_ids` | `initial` map, journal.ex:157–160 |
| validator.ex:853 `bump` counters | init at validator.ex:817 (8 counter keys pre-initialized to 0) |
| canonical_identity.ex:474/507 "goals" | `ir_payload()` declares "goals" (canonical_identity.ex:330) |
| ocel_validity.ex:618 "events" | base.doc from real OCEL artifact; `doc["events"]` required field, accessed at :561 |
| root_manifest.ex:384 "implementations" | `held` from `Root.load` of a schema-validated staged manifest |
| fresh_consumer.ex:371 "receipt_digest" | real `standing_receipt.json` of a real package |
| deliberation.ex:157/159/163 `:approve_shaped`/`:other`/`:errored` | reduce init at deliberation.ex:151 `%{approve_shaped: 0, other: 0, errored: 0}` |
| bounds.ex:175/255 | `Map.fetch!(bounds.resources, key)` guard above both (charge/3, debit reduce) |
| hook_reactor.ex:683 `:bound_decisions` | `Result` struct default `[]` (hook_reactor.ex:95); sole call site :679 |
| standing_ref.ex:151 `:refused` | resolution built with `refused:` always (standing_ref.ex:257) |
| ocel_forwarder.ex:371 "attributes" | `SemanticProjection.ocel_event/1` always emits "attributes" (semantic_projection.ex:93) |
| mix task standing_ref | (covered above) |

## Court

`~/ash_a2a/test/ash_a2a/w608_map_update_court_test.exs` — parameterized
deterministic insertion, **empty and populated baselines, ×2 runs**, over 3 real
modules: `AshA2A.Telemetry.AllocationCounters` (real ETS + real
`[:ash_a2a, :semantic, :allocation]` telemetry), `AshA2A.C2.MemoryClaimStore`
(real named Agent), `AshA2A.Protocol.Agent.State.track_context/2` (pure struct,
dual-safe shape). Asserts exact resulting maps — default stored verbatim, exactly
one prepend/count per insert. No mocks.

## Execution (real commands, real tails)

Build root `_build-laneW608` (fresh), pinned toolchain:

```
$ MIX_BUILD_ROOT=_build-laneW608 mix test test/ash_a2a/w608_map_update_court_test.exs   # run 1
..                                                                                      
Finished in 0.08 seconds ...  Result: 2 passed

$ (same command)   # run 2
Result: 2 passed
```

Per-module suites (docs-named per-context suites for the modules in the table):

```
$ mix test test/ash_a2a_trace_test.exs test/ash_a2a/semantic_bounds_test.exs \
    test/ash_a2a/durable_conformance/strict_c1_checks_test.exs \
    test/ash_a2a/security_profile/boot_durable_stores_test.exs \
    test/ash_a2a/semantic/machine_experience_test.exs
Result: 52 passed (4 doctests, 48 tests), 1 skipped
```

(Second batch)

```
$ mix test test/ash_a2a_telemetry_ocel_forwarder_test.exs \
    test/ash_a2a/telemetry/allocation_counters_test.exs \
    test/ash_a2a/enterprise/dlp_filter_test.exs \
    test/ash_a2a/enterprise/affidavit_ocel2_test.exs
Result: 28 passed, 6 excluded
```

80 test assertions, 0 failures across court×2 + 9 suite files; pre-existing
compile warning (DOWN-clause clause, not lane-introduced) observed.

## Standing

**PARTIAL_ALIVE**: the sweep is complete and courts green on the exact subject,
but the patch set is empty (0 class-(a) sites found — the prior wave at HEAD
b588c55c already converted the genuinely absent-key-critical sites to dual-safe
explicit branches; the remaining 27 code sites are all class-(b) with verified
presence guarantees or idempotent-fun accumulators). No lib/ diff to integrate;
only the court file. Not ALIVE for "patched class-(a) sites" because there are
none on this subject.

## Falsifiers

1. Court fails if any of the 3 modules' insertion deviates from default-verbatim
   insertion — rerun: `MIX_BUILD_ROOT=<root> mix test test/ash_a2a/w608_map_update_court_test.exs`.
2. Probe falsifier: any OTP/Elixir build where `Map.update(%{}, :k, 1, &(&1+1))`
   yields `2` would refute the probe finding and reopen the sweep.
3. A site table row whose presence guarantee line no longer exists in lib/ is
   reopened for classification.

## Exclusions / disclosures

- Checkout was dirty from other waves (untracked `docs/thesis/`); untouched.
- Full 3,708-test suite NOT run (lane budget); per-context suites for the named
  modules only. Full-suite run remains open for the campaign integration lane.
- One pre-existing compile warning (DOWN-clause) observed during court compile —
  not session-introduced.
