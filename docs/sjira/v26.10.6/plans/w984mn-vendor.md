# W984mn — vendor-tree + runtime_contract residue disposition (lane receipt)

- Date: 2026-10-08 · Lane: W984mn · Subject: /Users/sac/ash_pplan @ HEAD `847f487b` (branch `fix/ggen-verify-header`, untouched, NO commit)
- References: `w984hb-residue.md` (escalation), `w984hd-repin.md`, `w984ic-chaos-drivers.md`, `w984im-fixtures.md`
- Method: read-only reconciliation of every working-tree path against the three
  lane receipts, with content spot-verification (not name matching). Zero tree changes.

## Verdict summary

| Class | Count | Verdict |
|---|---|---|
| EXPECTED(W984hd) — re-pin + re-vendor | 18 | KEEP (lawful completed work, awaiting coordinator commit) |
| EXPECTED(W984ic via sync.sh re-vendor) — chaos positive drivers + verify relocations | 6 | KEEP |
| EXPECTED(W984im) — sync.sh 2h + lock/provenance regen + timeout tags | 4 | KEEP |
| EXPECTED(W984im, overlay header pin bump via sync.sh) | 6 + 5 lib | KEEP |
| Pre-existing residue NOT from these lanes | 1 | ESCALATE (do not commit with the vendor batch) |
| UNEXPECTED (unattributable content) | 0 | — |

Full inventory (git status @ HEAD 847f487b, 55 vendor/overlay/lib/test paths + 1 untracked test):

| # | Path | Class | Content evidence |
|---|---|---|---|
| 1 | `priv/ggen/vendor/sync.sh` | EXPECTED(W984hd+W984im) | pin → ba21c22a with dated W984hd comment; section 2h (+58) present at :371 with base64-embedded a224db049 driver bytes and W984im comment |
| 2 | `priv/ggen/vendor/PACKS.lock.json` | EXPECTED(W984hd/W984im) | pin `ba21c22a…` ×3; chaos gates recorded `source_tree_dirty: true` + `patched` per W984im §2.1 |
| 3 | `priv/ggen/vendor/provenance.ttl` | EXPECTED(W984hd/W984im) | pin ba21c22a ×11 |
| 4–6 | `vendor/ash-pplan-chaos-pack/gates/010_harness.rq`, `020_invariants.rq`, `030_kill_phases.rq` | EXPECTED(W984ic) | 010 byte-identical to marketplace working tree (`diff -q` SAME); 020/030 differ from marketplace working tree by exactly one token (`SELECT DISTINCT` vs `SELECT`) — the vendor-time 2f gate-hygiene determinism pass, per W984im §2 ("gate-hygiene patch (2f) runs AFTER 2h"). Row projections match W984ic's receipt (invariants/kill_phases/harness drivers, ORDER BY as documented) |
| 7–9 | `vendor/ash-pplan-chaos-pack/verify/010_harness.violation.rq`, `020_…`, `030_…` (untracked) | EXPECTED(W984ic) | each byte-identical (`diff -q` SAME) to `/Users/sac/ggen-marketplace/packs/ash-pplan-chaos-pack/verify/*.violation.rq` — the documented bytes-unchanged violation relocation |
| 10 | `vendor/ash-pplan-chaos-pack/templates/placeholder.tmpl` (D) | EXPECTED(W984hd) | "placeholder removed upstream" (w984hd §1 / w984im §4) |
| 11 | `vendor/ash-pplan-chaos-pack/templates/qualification_probe.txt.tmpl` (??) | EXPECTED(W984hd) | "new `templates/qualification_probe.txt.tmpl` added to three packs" at ba21c22a (w984hd §1) |
| 12–21 | `vendor/ash-pplan-protocol-court-pack/gates/010_protocols.rq` … `070_mutants.rq` (7, M) | EXPECTED(W984im) | 010 byte-identical to marketplace `a224db049` pre-rework positive driver (the exact source sync.sh 2h base64-embeds); marketplace HEAD copy is the violation form, as the receipt states |
| 22–28 | `vendor/ash-pplan-protocol-court-pack/verify/010…070_*.violation.rq` (7, ??) | EXPECTED(W984im) | 7 violation companions per 2h ("relocates the violation bytes verbatim to verify/<stem>.violation.rq"); no such files exist upstream at ba21c22a (upstream verify/ has only *.unbound.rq + cardinality.json) |
| 29–30 | `vendor/ash-pplan-protocol-court-pack/templates/{placeholder.tmpl D, qualification_probe.txt.tmpl ??}` | EXPECTED(W984hd) | upstream rework @ ba21c22a |
| 31–36 | `vendor/tokyo-depeg-burn-in-pack/gates/005…090_*.rq` (9, M) | EXPECTED(W984hd) | upstream gates rework across tokyo-depeg at ba21c22a (w984hd §1); W984im §4 confirms "re-pin fallout of sync.sh @ ba21c22a" |
| 37–41 | `vendor/tokyo-depeg-burn-in-pack/templates/{alignment_spec,burn_in_runner,corpus,stage_handler}.exs|ex.tmpl ?? + placeholder.tmpl D` (5) | EXPECTED(W984hd) | ".eex → .tmpl renames" at ba21c22a (w984hd §1); spot-checked head of burn_in_runner.ex.tmpl |
| 42 | `vendor/tokyo-depeg-burn-in-pack/verify/cardinality.json` (D) | EXPECTED(W984hd) | "tokyo `verify/cardinality.json` deleted upstream" (w984hd §1) |
| 43 | `test/courts/pack_chaos_court_test.exs` | EXPECTED(W984im) | diff = exactly +7 lines: comment + 3 × `@tag timeout: 600_000` |
| 44 | `test/courts/pack_gate_witness_court_test.exs` | EXPECTED(W984hd) | `@pinned_marketplace_sha` → ba21c22a + moduledoc pin mention + dated re-pin history comment |
| 45 | `priv/ggen/ash-pplan-runtime-overlay/bin/cross_contract_courts.exs` | EXPECTED(W984hd) | `pin = "ba21c22a…"` with dated comment (line 38) |
| 46–50 | `priv/ggen/ash-pplan-runtime-overlay/templates/{authority_gate,exact_subject,receipt,refusal,replay}.ex.tmpl` | EXPECTED(W984hd) | each exactly 2 changed lines (GENERATED-PROVENANCE header pin bump via sync.sh, w984hd §2.5) |
| 51–55 | `lib/ash_pplan/runtime_contract/{authority_gate,exact_subject,receipt,refusal,replay}.ex` | EXPECTED(W984im-era sync run) | each exactly 1 changed line: GENERATED-PROVENANCE header 6f779318 → ba21c22a. No body changes; no deletions, no untracked files under lib/. Consistent with w984hd's note that the overlay/lib headers would bump at the next sync/regeneration; w984im §4 lists lib/* as "not this lane's (pre-existing)" — i.e., present before its run, produced by the same sync.sh pin-bump mechanism |
| 56 | `test/map_update_w609_residual_court_test.exs` (??) | PRE-EXISTING (W609b residue) | W609 OS-20 Map.update residual court; w984hd §Residue discloses it as "pre-existing, not this lane's: W609b's untracked court file". Outside the vendor/re-pin work — ESCALATE to its own disposition (keep-on-disk, commit decision belongs to a W609 lane) |

## Key falsification attempts (all negative)

1. Chaos 020/030 vs marketplace working tree — resolved as vendor-time 2f
   `SELECT DISTINCT` hygiene, exactly the mechanism W984im documents; not drift.
2. Chaos verify/*.violation vs HEAD old gate bytes DIFFERS — resolved: HEAD had
   pre-rework positive-form bytes; the violation bytes came from the upstream
   ea8aff64b rework and match the marketplace relocation byte-for-byte.
3. lib/ runtime_contract — task hypothesized diffs "beyond receipts"; diff is
   header-only (1 line × 5 files). Nothing beyond the receipts exists in lib/.

## Recommendation to coordinator

KEEP the whole vendor/re-pin/overlay/lib-header batch as one coherent commit
(lawful completed work of W984hd + W984ic + W984im: pin ba21c22a, chaos/protocol
positive drivers, verify relocations, 2h patch, timeout tags, provenance/lock
regen, header pin bumps). It is internally consistent, idempotency-witnessed by
W984im, and all three owning courts passed exit 0 per those receipts. Exclude
`test/map_update_w609_residual_court_test.exs` from that commit (separate W609
disposition). Nothing to restore — zero UNEXPECTED paths.

## Build-root cleanup note

`rm -rf` of lane build roots remains permission-DENIED in this environment;
still on disk: `_build-laneW984hb` (398M, w984hb denial), `_build-laneW984hd`
(w984hd denial), plus `_build-lane{W291b,W609,W609b,W635,W658e,W682,W939,W984hl}`.
Coordinator cleanup required. No new denial occurred this lane (no destructive op
attempted).
