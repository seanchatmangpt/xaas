# W984im — ash_pplan chaos/protocol court fixture refresh (receipt)

- Lane: W984im on `/Users/sac/ash_pplan` @ `847f487` (no branch change, NO commit)
- Date: 2026-10-07/08
- Command env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984im`
  (repo pins elixir 1.20.4-otp-29 / erlang 29.1.1 via generated `.tool-versions`)
- References: `w984ic-chaos-drivers.md` (fixed the marketplace chaos pack, uncommitted),
  `w984hl-reconcile.md` (typed this work order)

## 1. BEFORE (real, /tmp/w984im-before.txt)

`mix test test/durable/pack_courts_harness_court_test.exs test/courts/pack_chaos_court_test.exs
test/courts/pack_protocol_court_test.exs` → **Result: 2/10 passed, 8 failed, EXIT=2**:

- chaos: render/determinism/anti-vacuity legs die on `mix ggen_igniter.sync` exit 1
  (vendored bytes still violation-form; 0 driver rows); gates leg `gate gates/010_harness.rq:
  expected 1 rows, got 0`.
- protocol: all 4 legs die on `undefined variable "cfgConstants"` EEx compile refusal —
  the vendored protocol pack's 7 gates are ALSO violation-form (`FILTER NOT EXISTS`, 0 rows
  on valid data), so the stem bindings (`protocols` single-row flatten → `moduleName`,
  `cfgConstants`, `stepSet`, `initExpr`, ...; `statuses`/`transitions`/`actions`/`guards`/
  `properties`/`mutants` list bindings) never materialize. Gates leg `010_protocols:
  expected 1 rows, got 0`.

## 2. Root cause + fix

The marketplace rework `ea8aff64b` put FILTER NOT EXISTS violation gates into
`gates/` for BOTH the chaos pack (fixed upstream by W984ic) and the protocol
court pack (NOT fixed upstream — verified: vendored bytes == upstream working
tree @ ba21c22a except README). ggen_igniter `build_bindings/2` binds each
gate stem as `stem: rows` and flattens single-row gates into atom-keyed
assigns, so violation-shaped gates starve the renders.

Two-part fix, all consumer-side (ash_pplan only; no ggen-marketplace edits):

1. **Chaos pack**: re-vendored via `priv/ggen/vendor/sync.sh` (which vendors
   from the marketplace WORKING TREE, so W984ic's uncommitted positive-driver
   fix came across; lock re-pins at marketplace HEAD `ba21c22a`, chaos gates
   recorded `source_tree_dirty: true` + `patched` automatically). Fixture
   expectations 1/6/4 are the real contract of the fixed pack and stay.
2. **Protocol pack**: no upstream fix exists, so sync.sh gained a
   deterministic consumer patch (**section 2h**, +58 lines in
   `priv/ggen/vendor/sync.sh`): restores the 7 pre-rework positive drivers
   (byte-identical to marketplace `a224db049`, base64-embedded so the bytes
   cannot drift in sync.sh itself), relocates the violation bytes verbatim to
   `verify/<stem>.violation.rq` (GateVerify doctrine: offender-shaped queries
   belong in verify/, zero-rows-is-pass), idempotent; gate-hygiene patch (2f)
   runs AFTER 2h so the restored drivers still pass the ORDER BY determinism
   law. Idempotency witnessed: two consecutive sync.sh runs → byte-identical
   `PACKS.lock.json` + gates.
3. **Chaos court timeout tags**: render legs spawn 6 real `mix ggen_igniter.sync`
   subprocesses and tripped the default 60s ExUnit timeout under a loaded
   lane-fanned machine (3 spurious failures in one run). Added
   `@tag timeout: 600_000` to render/determinism/anti-vacuity legs of
   `test/courts/pack_chaos_court_test.exs` — same ceiling the protocol court
   already carries. No assertion changed; gates still 1/6/4, renders still
   6+4.

## 3. AFTER (real outputs)

- chaos + harness: `mix test test/courts/pack_chaos_court_test.exs
  test/durable/pack_courts_harness_court_test.exs` → **6 passed, 0 failures,
  EXIT=0** (chaos gates 1/6/4 witnessed; renders 6 invariant + 4 kill suites,
  parseable; anti-vacuity 6→5 witnessed; harness 86-courts/anti-vacuity legs
  green).
- protocol: `mix test test/courts/pack_protocol_court_test.exs` → **4 passed,
  0 failures, EXIT=0** (gates 1/9/29/9/23/6/2 witnessed; renders byte-identical
  to checked-in `priv/ggen/generated/protocol-court/`; anti-vacuity 9→8
  witnessed). Fixtures did NOT need re-pinning — the old row counts were the
  real contract once the gates fire positive rows again.
- witness + provenance: `mix test test/courts/pack_gate_witness_court_test.exs
  test/courts/provenance_baseline_court_test.exs` → **16 passed, EXIT=0**.
  NOTE: the dispatch predicted "18 passed" — stale count; the two files
  contain 7 + 9 = 16 tests today; all 16 pass. Re-read from the files, not
  the dispatch.
- `bash bin/ggen-verify` over the vendored packs: `vendor/ash-pplan-protocol-court-pack
  PASS (7 gates, 7 under contract, 0 unbound facts)`; `ash-pplan-durable-chaos-pack PASS`.
  Pre-existing, untouched-by-this-lane rows: workflow FAILs + state-transition/
  evidence-standing ENGINE-LIMIT (their violation gates use FILTER NOT EXISTS,
  unimplemented in sparql.ex 0.3.12) — upstream bytes at the W984hd pin, out
  of scope.

## 4. Files touched by THIS lane (ash_pplan)

- `priv/ggen/vendor/sync.sh` (+58: section 2h protocol positive-driver patch)
- `priv/ggen/vendor/PACKS.lock.json`, `provenance.ttl` (regenerated; deterministic)
- `priv/ggen/vendor/ash-pplan-chaos-pack/` (gates → W984ic positive drivers;
  placeholder.tmpl removed upstream; dirty+patched flags in lock)
- `priv/ggen/vendor/ash-pplan-protocol-court-pack/` (7 gates → restored
  positive drivers; 7 × `verify/NNN_*.violation.rq` added; qualification_probe
  template added upstream; placeholder removed)
- `priv/ggen/vendor/tokyo-depeg-burn-in-pack/` + other vendored packs (re-pin
  fallout of sync.sh @ ba21c22a — W984hd's re-vendor completed through my run)
- `test/courts/pack_chaos_court_test.exs` (+7: three `@tag timeout` lines +
  comment)

NOT this lane's (pre-existing working-tree state, untouched): `lib/ash_pplan/runtime_contract/*`,
`lib/ash_pplan/providers/a2a.ex`, `priv/ggen/ash-pplan-runtime-overlay/*` edits,
`bin/runtime-contract-courts`-related overlay changes.

## 5. Cleanup

- `/Users/sac/ash_pplan/_build-laneW984im`: **deleted, exit 0** (NOT denied this
  time — unlike W984hl's attempt).
- `/tmp/w984im-pd`, `/tmp/w984im-{before,after,proto,chaos-harness,chaos2,
  witness}.txt` left in /tmp (evidence copies; OS-scratch).

## 6. Standing

- ALIVE for the fixture refresh: all three courts exit 0 with real renders,
  real gate row counts, witnessed anti-vacuity; vendored pack verify-clean;
  sync.sh byte-idempotent.
- Out-of-lane work orders (typed):
  1. ggen-marketplace: `ash-pplan-protocol-court-pack` needs the same upstream
     positive-driver fix W984ic applied to the chaos pack (gates/ → positive
     drivers, violation bytes → verify/*.violation.rq); until then my sync.sh
     2h patch carries the fix consumer-side. After an upstream fix, sync.sh 2h
     becomes a no-op (idempotent by construction: it only rewrites on
     divergence).
  2. ash_pplan `bin/ggen-verify` shows pre-existing FAIL/ENGINE-LIMIT rows
     (workflow-corpus, state-transition, evidence-standing at the current pin)
     — same violation-gate/sparql.ex-0.3.12 class; separate lane.
- NO commit made (per dispatch).
