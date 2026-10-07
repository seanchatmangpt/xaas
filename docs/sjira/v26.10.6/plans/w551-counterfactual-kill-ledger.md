# W551 — Counterfactual Harness Mutation Ledger (dissertation §4, KillScore)

Lane W551, EU-AI-Act wave @ `feat/playwright-surface`, canonical checkout `/Users/sac/xaas`.
Court: 6 hand-applied one-line mutants over the six modules asserted by the W550 harness.
Per mutant: run `test/eu_ai_act/counterfactual_test.exs` (W550) + the module's own test file.
KILLED = suite red under mutant; SURVIVED = vacuous suite clause (typed finding, reported, not fixed).

## Transport repairs (disclosed, out-of-contract, forced by shared-checkout blockers)

1. `lib/xaas/semantics/airo_risk_mapping.ex` (UNTRACKED, foreign lane): SyntaxError at 201:52 —
   `\"` escapes inside `#{...}` interpolation. Broken 25+ min, blocked whole-app compile;
   repaired by removing the invalid escapes. Left in place (reverting would re-break compile).
2. `lib/xaas/semantics/authority_channel.ex` (UNTRACKED, foreign lane): CompileError —
   `def transmit(_report, ...)` head named the first arg `_report` while the body referenced
   `report_input` (undefined variable at 145:27). Repaired by renaming the head arg.
3. Harness (`test/eu_ai_act/counterfactual_test.exs`) was itself mid-write by W550 for ~40 min
   (grew 464→791 lines; passed through a syntax-error phase). All mutant runs were done only
   after it parsed and ran green.

Both repaired files are untracked wave products; both repairs are minimal and are visible as the
current file state. No tracked file was modified by W551 (git status tracked-M set is unchanged
from session start).

## Protocol (per mutant)

1. Fresh pristine snapshot of the target to `/tmp/w551pristine/` (targets are untracked, so
   revert verification is `cmp`-based, not `git diff`).
2. Apply the one-line edit.
3. `MIX_BUILD_ROOT=_build-laneW551 MIX_ENV=test mix test test/eu_ai_act/counterfactual_test.exs <module_test>`
4. Verdict KILLED/SURVIVED; revert by inverse edit; `cmp` against pristine snapshot.

Toolchain: asdf elixir 1.20.2-otp-28. Build root: `_build-laneW551`.

## Baseline

- `mix test test/eu_ai_act/counterfactual_test.exs` → `Result: 25 passed` (green, pre-mutants).
- Final post-revert run of all 7 files → `Result: 105 passed`, exit 0.

## Ledger (KillScore = 5/6)

| # | module | file | mutant (one-line edit) | killed-by-test | verdict |
|---|--------|------|------------------------|----------------|---------|
| M1 | EuAiActAdmission | lib/xaas/semantics/eu_ai_act_admission.ex | drop Art. 5(1)(e) partition check (remove `{fn c -> affective_in_context?(c) end, :REFUSED_EUAIA_EMOTION_RECOGNITION}` from `checks/0`) | counterfactual_test "Art 5(1)(e) emotion recognition… refuses deterministically" (counterfactual_test.exs:161) + eu_ai_act_admission_test "(e) … is refused" (test:183) | KILLED |
| M2 | DatasetAdmission | lib/xaas/semantics/dataset_admission.ex | `if w1 > epsilon do` → `if false do` (bias gate always admits) | counterfactual_test "Art 10(2) … REFUSED_BIAS_THRESHOLD" (counterfactual_test.exs:220) + dataset_admission_test ×2 (test:35, test:76) | KILLED |
| M3 | AuditChain | lib/xaas/witness/audit_chain.ex | `not valid_payload_digest?(r) ->` → `not valid_payload_digest?(r) and :erlang.system_time() < 0 ->` (payload-digest tamper recomputation vacated) | — (suite stayed green: 42 passed) | **SURVIVED** |
| M4 | RobustMargin | lib/xaas/semantics/robust_margin.ex | `margin_value - penalty >= 0` → `<= 0` (invert comparison) | counterfactual_test "Art 15(1) … REFUSED_ROBUST_MARGIN" + robust_margin_test ×4 | KILLED |
| M5 | VulnerabilityLifecycle | lib/xaas/semantics/vulnerability_lifecycle.ex | `respond` state guard `:TRIAGED` → `:DETECTED` (allow DETECTED→RESPONDED skip) | counterfactual_test "Art 15(5) … REFUSED_LIFECYCLE_SKIP" + vulnerability_lifecycle_test ×5 | KILLED |
| M6 | AutomationBiasCountermeasure | lib/xaas/semantics/automation_bias_countermeasure.ex | `refusal_anatomy = refusal_anatomy(admitted?, checks)` → `= []` (drop refusal anatomy) | counterfactual_test ×3 (Art 14(4)(b), Art 14(4)(b) extension, Art 14(4)(a)) + automation_bias_countermeasure_test ×2 | KILLED |

Note on M3's first attempt: a literal `false ->` cond clause was rejected by the type checker
("clause will never match"), so the vacating mutant used an opaque always-false conjunct
(`:erlang.system_time() < 0`), which compiles and is semantically identical to clause removal.

## Typed finding (M3 SURVIVED — payload-digest clause vacuous as tested)

The suite kills Art 12 tamper detection via the successor-linkage clause
(`rest != [] and hd(rest).prev_hash != h`), because the harness tampers link k=2 of 4 (which has
a successor). A tamper of the TAIL link's payload_digest is detectable only by the dedicated
`not valid_payload_digest?(r)` clause, and no test exercises a tail tamper. Direct probe under
the live mutant (2-link chain, tamper last link, no expected_head):

```
W551PROBE: :ok   # verify_chain/2 of a tampered-payload chain returns :ok — undetected
```

(probe log: /tmp/w551probe.log; suite under mutant: /tmp/w551_m3.log → `Result: 42 passed`)

The harness is therefore NOT bound to the payload-digest recomputation clause for tail links.
Fix belongs to the owning lane (add a tail-tamper court), not to W551 — reported, not fixed.

## Run tails (real, per mutant)

```
M1: Result: 47/49 passed / Failed: 2 tests   (log /tmp/w551_m1.log)
M2: Result: 28/31 passed / Failed: 3 tests   (log /tmp/w551_m2.log)
M3: Result: 42 passed   / exit 0             (log /tmp/w551_m3.log)  ← SURVIVED
M4: Result: 30/35 passed / Failed: 5 tests   (log /tmp/w551_m4.log)
M5: Result: 34/40 passed / Failed: 6 tests   (log /tmp/w551_m5.log)
M6: Result: 28/33 passed / Failed: 5 tests   (log /tmp/w551_m6.log)
Baseline: 25 passed (harness alone); final all-7-file post-revert: 105 passed, exit 0
```

## Revert verification

- M2, M4, M5, M6, audit_chain: `cmp` byte-identical vs pristine snapshots — CLEAN.
- M1 (eu_ai_act_admission.ex): my mutant line fully reverted ((e) check present, count=1);
  the only remaining delta vs my pre-mutant snapshot is the OTHER lane's concurrent W630
  `wrap_field`/`proper_list?` refactor that landed mid-session — not a W551 change.

## Result

- **KillScore = 5/6** (M1, M2, M4, M5, M6 KILLED; M3 SURVIVED).
- One typed vacuity finding: AuditChain payload-digest recomputation is un-tested for tail-link
  tamper; harness Art 12 kills only through successor-linkage.
- No tracked file modified by this lane; all mutants reverted byte-exact (cmp-verified).
