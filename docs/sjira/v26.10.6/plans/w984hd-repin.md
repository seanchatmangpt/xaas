# W984hd — ash_pplan marketplace re-pin 6f779318 → ba21c22a (receipt)

- Lane: W984hd on `/Users/sac/ash_pplan` @ `847f487b4bb3b4e41afc179c813406d97cdfdc98` (main)
- Date: 2026-10-07 (evening)
- Command env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hd`
- Commit: none (per dispatch); all edits left in working tree.

## 1. Pin decision: LAWFUL (fast-forward re-pin)

In `~/ggen-marketplace` @ HEAD `ba21c22a4259e0909dad9fa9196b06baadd5bbb1`,
branch `feat/aaif-gcp-roadmap-v26.10.5` (tracks origin, in sync):

- `git merge-base --is-ancestor 6f779318 HEAD` → **ANCESTOR** — fast-forward,
  lawful re-pin, not diverged.
- `git log --oneline -5` at HEAD: ba21c22a (multi-pack Chicago court + CDBR-v1
  execution isolation), 92b7f9e2f, 3abeac17e, 308427c3a (v26.10.7 version
  bump), 969ab0e1a.
- Dirty state in the marketplace tree does not touch any vendored pack:
  `git status --porcelain` over all 10 consumed packs → empty (only
  `packs/ash-extension-pack` files are dirty, which ash_pplan does not vendor).
- Upstream diff `git diff --stat 6f779318 ba21c22a -- packs/` = 248 files.
  For the vendored packs specifically: gates reworked in ash-pplan-chaos /
  ash-pplan-protocol-court / state-transition / evidence-standing / tokyo-depeg;
  tokyo-depeg templates renamed `.eex` → `.tmpl`; new
  `templates/qualification_probe.txt.tmpl` added to three packs;
  tokyo `verify/cardinality.json` deleted upstream.
  **Byte-identical across the move** (relevant to their courts):
  `semantic-gate-witness-court-pack`, `ash-runtime-integration-contract-pack`
  (diffs empty).

## 2. Edits (working tree only, no commit)

1. `priv/ggen/vendor/sync.sh` — `rt_expected_sha` → `ba21c22a…`, with a dated
   re-pin comment noting this move is a REAL re-vendor (bytes changed), unlike
   the two prior lock-only moves.
2. `priv/ggen/ash-pplan-runtime-overlay/bin/cross_contract_courts.exs` — `pin`
   → `ba21c22a…` with dated comment (runtime-integration pack bytes
   unchanged across the move).
3. `test/courts/pack_gate_witness_court_test.exs` — `@pinned_marketplace_sha`
   → `ba21c22a…`, moduledoc pin mention updated, dated comment.
4. Ran `./priv/ggen/vendor/sync.sh` → exit 0:
   `vendored … 8 packs (sha256-locked) + ash-runtime-integration-contract-pack overlay (64 files, 48 patched)`
   — re-vendors the changed pack bytes and deterministically rewrites
   `PACKS.lock.json` + `provenance.ttl` at the new pin.
5. `priv/ggen/vendor/verify_lock.sh` → `verify_lock: OK (9 packs, lock ba21c22a4259e0909dad9fa9196b06baadd5bbb1)`.

Note: `lib/ash_pplan/runtime_contract/*.ex` headers still name the old pin in
their GENERATED-PROVENANCE comments; `test/courts/pack_runtime_overlay_court_test.exs`
passes 5/5 with them (headers are provenance comments, not asserted), so not
regenerated. Pin string also remains in `priv/ggen/vendor/sync.sh`'s historical
comments and `test/…` re-pin-history comments — intentional history.

## 3. Court runs (real output)

The 4 W650v-classified pin-drift refusals, direct re-run:

```
mix test test/durable/pack_courts_harness_court_test.exs \
         test/courts/pack_gate_witness_court_test.exs \
         test/courts/provenance_baseline_court_test.exs
→ EXIT=0 … Result: 18 passed   (PackCourtsHarness ×2 legs, PackGateWitness,
                                ProvenanceBaseline — all green)
```

(`pack_courts_harness ×2` = the harness court's two timeout-tagged legs; both
included. Adjacent consumer of the same pin, `pack_runtime_overlay_court_test`,
passes 5/5.)

## 4. Cascade classification (adjacent render courts)

Re-ran the neighboring render courts (`pack_chaos`, `pack_protocol`,
`pack_runtime_overlay`): 5/13 → 8 failures, ALL
`ggen_igniter: reactor reconciliation failed (refused)` (chaos 4, protocol 4;
overlay green). Classification: **pre-existing, not re-pin-induced** —
replicated the exact `mix ggen_igniter.sync --pack-dir … --template … --out …`
render against the OLD (HEAD, 6f779318-era) vendored chaos-pack bytes in a
mktemp dir: also refused by ggen_igniter 26.10.2, with a different typed
refusal (`duplicate output path(s)` ×6, exit 1, log `/tmp/w984hd-old.log`).
So the reconcile-refusal class fires independent of the pin bytes; it matches
W650v's UNKNOWN-classified `ArgumentError … not a nonempty list` observation
in `MarketplaceSim.GcpContractCourtTest` ("pack re-syncs byte-identically").
Those courts therefore remain in the same pre-existing UNKNOWN/known-failing
class W650v recorded (its chunk D saw the same families fail, classified as
load timeouts), and are a ggen_igniter-reconcile work order, not a pin issue.

Residue observed: `test/support/tokyo_depeg/tokyo-ggen-sync` render lines
reference the old `.eex` template names; upstream renamed them `.tmpl`. No
test or bin entry point invokes that driver today (grep over test/ and bin/
returns no invokers), so nothing breaks; flagged for its next consumer.

## 5. Standing

**ALIVE** for the dispatched scope: pin lawfully re-pinned (fast-forward
ancestry proven), lock+provenance re-vendored byte-deterministically,
verify_lock OK, all 4 refusing courts green exit 0. Pre-existing
ggen_igniter-26.10.2 reconcile refusals in chaos/protocol render courts
stand as a separate work order (reproduces on old pin bytes).

## Residue disclosure

- `_build-laneW984hd` **remains on disk**: `rm -rf` of the lane build root was
  DENIED by the permission system (both attempts). Coordinator should delete
  `/Users/sac/ash_pplan/_build-laneW984hd`.
- Working-tree edits (uncommitted, per dispatch): `priv/ggen/vendor/sync.sh`,
  `priv/ggen/vendor/PACKS.lock.json`, `priv/ggen/vendor/provenance.ttl`,
  re-vendored pack files (M/D/?? under `priv/ggen/vendor/*`),
  `priv/ggen/ash-pplan-runtime-overlay/bin/cross_contract_courts.exs` + 5
  overlay `.ex.tmpl` (header pin bump via sync.sh),
  `test/courts/pack_gate_witness_court_test.exs`.
- Pre-existing, not this lane's: W650v's residue
  (`priv/ggen/ash-pplan-dsl-pack/ontology.ttl` modification), W609b's
  untracked court file.
