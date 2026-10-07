# Stage-3 Evidence Pack — v26.10.6 (CRO-LOOP S3)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, head
`d1db2b03179975213c14663b9dbd86b5ac2a14cf`, 2026-10-06. Assembled per
`docs/cro/CRO-LOOP.md` §S3 from receipts under `docs/sjira/v26.10.6/plans/`
and `docs/cro/artifacts/`. Wordings follow the ship-list in
`artifacts/evidence-claims-index.md` (w405).

## 1. What this pack attests

Fail-closed deterministic refusal with replayable typed receipts: an
out-of-bounds action against the governed surfaces is refused, not repaired,
and every refusal is a typed token with a replayable fixture. Backed by:

- 62/62 typed refusal tokens covered, delta 0 (w202 recount; ledger JCS
  `coverage: "62/62"`; capstone w236).
- 86-test refusal-negative suite, 0 failures, 12 files (w236 capstone).
- One-command conformance court: 26/26 CONFORMANT, EXIT=0, machine-readable
  JSON — pinned in-repo court corpus, NOT the official A2A TCK (w385).
- 96 Playwright E2E passed (2 skipped) under real tokens (w317).
- Zero-config posture HELD — zero safety-adjustable knobs (w322, re-verified
  post-OS-17 by w396 STILL-HELD).

## 2. The refusal corpus

- **62/62 refusal tokens, 86/0 capstone** (w236): consolidated run over the
  exact 12-file list = `Result: 86 passed`, 0 failures, 0 skipped; per-file
  sum 86 (CASTLE batches 1–6 = 19+12+7+3+3+18; auth-floor plug 7/7;
  body-limit 3; token revocation 4; r2rml 2; vkg 3; actuation 5).
- **Mutant-kill evidence** (ledger JCS `counts`): 8 kills, 9 mutation
  runs, 2 structurally-unreachable (typed). Receipts: w320 (6 mutants,
  4 killed) + w382 round 2 (3 mutants, 2 killed, 1 survived). Survivors
  carry typed dispositions: `REFUSED_VKG_EMPTY_CATALOG` reclassified
  structurally unreachable (w378, `lib/xaas/semantics/vkg.ex:52`);
  actuation identity-mismatch clause witnessed dead (w379 kill test;
  foreign input caught earlier at `actuation.ex:537`).
- **1 gap, in flight, NOT landed**: empty-bearer anti-vacuity gap
  (`require_internal_api_token.ex:130`, w382 mutant 2 survived) — fix
  receipt `w414` is in the declared in-flight set (`_FRONTIER.md`,
  artifact-integrity W419); NO file on disk. Not counted as evidence.
- Honest scope: coverage = fixture/token presence (delta 0) plus the 9
  witnessed mutation runs; variants without a witnessed kill carry
  `mutant_killed: null` — fixture presence, not mutant-kill.

## 3. Replay commands

Run all under the pinned toolchain (`PATH=$HOME/.asdf/shims:$PATH`,
Elixir 1.20.2-otp-28). Confirm subject: `git -C /Users/sac/xaas rev-parse HEAD`.

### 3.1 Refusal corpus (w236, exact 12-file command)

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/castle_refusal_negative_test.exs \
  test/xaas/castle_refusal_negative_batch2_test.exs \
  test/xaas/castle_refusal_negative_batch3_test.exs \
  test/xaas/castle_refusal_negative_batch4_test.exs \
  test/xaas/castle_refusal_negative_batch5_test.exs \
  test/xaas/castle_refusal_negative_batch6_test.exs \
  test/xaas/semantics/r2rml_refusal_test.exs \
  test/xaas/semantics/vkg_refusal_negative_test.exs \
  test/xaas/actuation_refusal_negative_test.exs \
  test/xaas/accounts/token_revocation_test.exs \
  test/xaas_web/plugs/require_internal_api_token_test.exs \
  test/xaas_web/endpoint_body_limit_test.exs
```

Expected (w236 verbatim): `Result: 86 passed`, 0 failures, 0 skipped.

### 3.2 Conformance court (w385)

```bash
cd /Users/sac/ash_a2a && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=/Users/sac/ash_a2a/_build-laneW385 \
  mix ash_a2a.v1_conformance_report --out /tmp/w385-v1-conformance.json
# EXIT=0; totals: {"total": 26, "pass": 26, "fail": 0}
```

Note: cold `MIX_BUILD_ROOT` may exceed a background time limit on first
run (w385 did); rerun on the warm root. Gate: `totals.fail == 0`.

### 3.3 Ledger JSON verification

```bash
# Subject binding
git -C /Users/sac/xaas rev-parse HEAD

# Token recount (w202 method) — expected: empty output (delta 0, 62/62)
comm -23 \
  <(grep -rhoE 'REFUSED_[A-Z_]+' /Users/sac/xaas/lib/ | sort -u) \
  <(grep -rhoE 'REFUSED_[A-Z_]+' /Users/sac/xaas/test/ | sort -u)

# Canonical round-trip (artifact-integrity W419 method) — stable, byte-identical
python3 -c 'import json;p="/Users/sac/xaas/docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json";d=json.load(open(p));s=json.dumps(d,sort_keys=True,separators=(",",":"));assert s==json.dumps(json.loads(s),sort_keys=True,separators=(",",":"))'
# (single line; split here only for readability)
```

### 3.4 Release-snapshot verify court (w418)
```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW418 MIX_ENV=test mix run -e '{:ok,m}=Xaas.Deployment.ReleaseSnapshot.member("lib/xaas/application.ex");{:ok,snap}=Xaas.Deployment.ReleaseSnapshot.freeze([m],provenance:%{version:"v26.10.6"});File.write!("_build-laneW418/w418-release-snapshot.json",Xaas.Deployment.ReleaseSnapshot.Codec.encode!(snap))'
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW418 MIX_ENV=test mix xaas.release_snapshot.verify _build-laneW418/w418-release-snapshot.json  # exit 0, standing:"ALIVE" (w418 receipt)
```

## 4. Demo evidence — agent-obliviousness (W407, verbatim legs)

Suite gate: `npx playwright test e2e/mcp-a2a.spec.cjs` → 5 passed (22.2s)
on the real Phoenix e2e server (port 4097, `INTERNAL_API_TOKEN=w407-token`,
health probe 200). Full request/response bodies and boot/teardown script:
`docs/cro/artifacts/agent-obliviousness-demo.md`. The three legs:

**Leg A — normal call passes (tools/list).** Plain JSON-RPC over HTTP with
`Authorization: Bearer w407-token` → HTTP 200 with exactly the 3 read-only
Library tools; parsed names: `['active_curations_for_grade',
'books_by_grade_band', 'list_books']`.

**Leg B — admitted tool call works (tools/call list_books).** Same
unmodified harness shape → HTTP 200 standard MCP `result.content` with real
seeded book rows (e.g. "First Words, First Steps", "Senior Year, Zero
Gravity", "Circuits and Constellations").

**Leg C — unadmitted call refused, wire-indistinguishable.** Call to
nonexistent/write-shaped tool `delete_all_books` → same HTTP 200 envelope,
standard JSON-RPC typed error:
`{"error":{"code":-32602,"message":"Tool not found: delete_all_books"},"id":3,"jsonrpc":"2.0"}`.
An unmodified agent cannot distinguish policy refusal from tool absence
from the wire alone. Supplementary fail-closed auth: tokenless request →
HTTP 401 `{"error":"unauthorized",...}`.

## 5. Scope limits

- **In-repo courts, not official TCK.** The 26/26 conformance verdict is
  the pinned in-repo court corpus (w385, ash_a2a @ `07180bd3`); official
  A2A TCK certification is UNSUPPORTED. Never present as "TCK-certified".
- **Typed gaps OS-14/15/16** (EU AI Act, closure plan scope v26.10.7+):
  OS-14 Art. 12(3) — no operator-facing refusal/authority-receipt export
  surface; OS-15 Art. 14(4)(e) — no bias-awareness doc-class; OS-16
  Art. 50 — no end-user AI-disclosure surface. Open, declared gaps.
- **Corrected claims only (w405 ship-list).** Say "fail-closed
  deterministic refusal" — never "mathematically unrepresentable". Say
  "62 CASTLE refusal-negative tests" — never "44". SHA-256 over JCS
  (RFC 8785-style) canonical JSON (`ReleaseSnapshot`; digest path exercised
  end-to-end, w418); BLAKE3 is not used.
  ML-DSA-65 (FIPS 204) is an admitted signing-surface algorithm in the
  witness catalog; runtime ML-DSA-signed receipts are not witnessed on
  this subject — never "every intercepted command yields an ML-DSA
  affidavit". No "<15 ms WASI gate" (no latency receipt). No "FRE 902(14)"
  (no backing artifact). Caremark case-law framing is rhetorical, out of
  technical-evidence scope.

## 6. Post-consolidation refresh (W861, 2026-10-07)

Added after the consolidation wave; every row's file existence verified
(`test -f`, 2026-10-07, HEAD `a0723bf6`). Pre-refresh pack sha256
`aaab08f9ba5aa8ebb8bc5832062f9c88a4a3ddd2dc4e22c1850bb78735985260`;
post-refresh sha256 recorded in the W861 receipt
(`docs/sjira/v26.10.6/plans/w861-evidence-pack-refresh.md`). The pack carries
no internal aggregate hash; the only hash it carries is this file's own
sha256, recomputed honestly at each refresh.

| Wave | Evidence path | One-line description | Standing (from receipt) |
|---|---|---|---|
| w821 | `test/eu_ai_act/title_i_test.exs`, `test/eu_ai_act/title_iii_test.exs`, `test/eu_ai_act/title_iv_v_test.exs` | Terminal census 2: census-minus-gate delta equals the open-gap count across the EU-AI-Act suite — census certified terminal | ALIVE |
| w778 | `test/eu_ai_act/title_i_test.exs`, `test/eu_ai_act/title_iii_test.exs` | Gate-fix verification: F1 coordinator repair VERIFIED as-found; F2 direction-inverted repair corrected forward; gate ALIVE | Gate ALIVE; F1 VERIFIED; F2 PARTIAL (corrected forward) |
| w780 | `lib/xaas/actuation.ex`, `test/xaas/sa2a_computation_boundary_test.exs` | Claim-shaped authority guard closing XAAS-W763-G1: `:w763_measured_gap` test flipped to assert the typed refusal | ALIVE (lane-local, uncommitted) |
| w786 | `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs` | ash_onetime logical-partition migration: partition column + delete-guard triggers on all three authority tables; round-trip 21 passed | ALIVE (per receipt verification ladder) |
| w801 | `lib/xaas/governance/validations/audit_export_token_no_active_freeze_window.ex`, `test/xaas/governance/freeze_window_test.exs` | FreezeWindow minimal enforcement wiring closing GAP-D: primary suite 16/16 exit 0 | PARTIAL_ALIVE |
| w836 | `test/xaas_web/health_court_test.exs`, `lib/xaas_web_web/controllers/health_controller.ex` | Health-endpoint contract court: 11/11 across two consecutive real runs | ALIVE |
| w837 | `test/xaas_web/ts_codegen_drift_court_test.exs` | TS codegen drift court: 3/3 passed on exact subject; PARTIAL_ALIVE fallback documented in receipt | ALIVE |
| w829 | `test/xaas_web/sensitive_resources_routing_court_test.exs`, `lib/xaas_web/router.ex` | Sensitive-resources routing court: 5/5 both runs on HEAD a0723bf6; one typed gap declared in receipt | Court ALIVE (receipt status PARTIAL_ALIVE, one typed gap) |

Existence verification: 15/16 referenced paths present; 1 MISSING
(`lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex`) — deleted
by a concurrent sibling lane, documented as such inside the w780 receipt
itself; it is not evidence for any row above.
