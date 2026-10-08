# W984jh — Dead-Residue Re-Verification Receipt (2026-10-07)

Lane W984jh, canonical checkout /Users/sac/xaas, branch `feat/playwright-surface`.
Docs/verification lane — no deletions, no test writes, no commits.

## Verdict

**W984dq8's UNSUPPORTED(dead-residue) disposition (docs/sjira/v26.10.6/plans/w984dq8-probe.md:82-84, 144-146) is FALSIFIED.** All three typed-dead files are LIVE. Zero deletions are warranted. There is nothing for the coordinator to `rm`.

## Method

Fresh `grep -rn` across `test/` and `lib/` (`*.ex`, `*.exs`), excluding the defining
file itself, per module defined in `test/support/`. All counts are machine output,
re-runnable via the loop below.

```bash
for f in test/support/*.ex; do
  mods=$(grep -oE '^defmodule [A-Za-z0-9._]+' "$f" | awk '{print $2}')
  for m in $mods; do
    n=$(grep -rn --include='*.ex' --include='*.exs' -F "$m" test/ lib/ | grep -v "^$f:" | wc -l)
    echo "$f | $m | $n"
  done
done
```

## Full test/support dead/live table

| file | module | refs (excl. self) | verdict |
|---|---|---|---|
| conn_case.ex | XaasWeb.ConnCase | 122 | LIVE |
| data_case.ex | Xaas.DataCase | 59 | LIVE |
| dod_fixture.ex | Xaas.Test.DodFixture | 5 | LIVE |
| generator.ex | Xaas.Generator | 177 | LIVE |
| semantic_jira_bridge_fixtures.ex | Xaas.Ultracode.SemanticJiraBridgeFixtures | 9 | LIVE |
| sip2_test_server.ex | Xaas.Test.SIP2TestServer | 2 | LIVE |
| ultracode_semantic_case.ex | Xaas.Ultracode.SemanticCase | 9 | LIVE |
| vkg_observation_engine.ex | Xaas.Test.VKGObservationEngine | 9 | LIVE |
| fake-node.sh | (shell fixture, path-referenced by `test/xaas/ultracode/zcode_package_falsifier_test.exs:31`) | 1 | LIVE |
| graphlaw_spin_guest.rs | (Rust fixture, path-referenced by `test/xaas/semantics/graphlaw_wasm_test.exs:20`) | 1 | LIVE |

**Dead count: 0.** Every file in `test/support/` is referenced.

## Key evidence: the three typed-dead files

### vkg_observation_engine.ex — LIVE (9 refs)

- test/xaas/semantics/vkg_refusal_negative_test.exs:18 — `@engine Xaas.Test.VKGObservationEngine`
- test/xaas/semantics/vkg/family_court_w984hn_test.exs:21
- test/xaas/semantics/vkg/workspace_test.exs:7
- test/xaas/semantics/vkg/integration_test.exs:7
- test/xaas/semantics/vkg/replay_test.exs:7
- test/xaas/fabric/castle_alive_test.exs:122 — passed as config to `Planes.Projection`
- (plus doc-comment mentions at vkg_refusal_negative_test.exs:7, family_court_w984hn_test.exs:8, castle_alive_test.exs:7)

### generator.ex — LIVE (177 refs)

W984dq8 claimed 0 refs; W984ei's usage was already a counterexample. Fresh sweep:
`Xaas.Generator.create_org!`, `create_user!`, `create_book!`, `create_provider!`,
`create_webhook!`, `pending_approval!` used across ≥30 test files, including:

- test/xaas_web/controllers/approval_tier_downgrade_controller_test.exs:67 — `Xaas.Generator.create_org!().slug`
- test/xaas_web/controllers/incident_controller_test.exs:49 — `Xaas.Generator.create_org!(...)`
- test/xaas_web/ocel_envelope_avatars_test.exs:139,149
- test/xaas_web/execution_fabric_controller_test.exs:637,681,682
- test/xaas_web/live/autofde_lab/status_live_test.exs:38
- test/xaas_web/a2a/return_hold_cascade_avatars_test.exs:62-63,81
- test/xaas/actuation_ocel_undo_test.exs:98
- test/xaas/accounts_deepening_test.exs:40,47
- test/xaas/sa2a_computation_boundary_test.exs:410
- full list: `grep -rn "Xaas.Generator" test/ lib/ | grep -v support/generator.ex` (177 lines, 30+ files)

### ultracode_semantic_case.ex — LIVE (9 refs)

- test/xaas/ultracode/semantic_work_test.exs:7 — `use Xaas.Ultracode.SemanticCase, async: false`
- test/xaas/ultracode/semantic_wave_test.exs:9
- test/xaas/ultracode/semantic_wave_trigger_test.exs:9
- test/xaas/ultracode/semantic_jira_bridge_crown_test.exs:25
- test/xaas/ultracode/semantic_jira_bridge_provenance_test.exs:17
- test/xaas/ultracode/semantic_jira_bridge_forged_court_test.exs:21
- test/xaas/ultracode/test_db_leak_guard_test.exs:32 — `import Xaas.Ultracode.SemanticCase`
- test/xaas/ultracode/two_port_e2e_test.exs:30

## Corrected claims

1. **W984dq8 (w984dq8-probe.md:82-84):** claimed 0 refs / DEAD for vkg_observation_engine.ex,
   generator.ex, ultracode_semantic_case.ex
2. **W984ei usage:** confirmed real — `Xaas.Generator.create_org!` is called in
   approval_tier_downgrade_controller_test.exs:67 and 10+ other controller/deepening tests.
   W984dq8's zero-reference claim was stale/wrong even at issue time.
3. **sip2_test_server.ex** remains LIVE (sip2_adapter_test.exs:11,14) — matches dq8's own ALIVE row.
4. **fake-node.sh / graphlaw_spin_guest.rs** LIVE via literal path references in test sources.

## Coordinator actions

**None.** No `rm` commands — deletion would break ≥46 test files. If the coordinator
wants the dead-residue register cleaned instead, the correction is a docs edit to
w984dq8-probe.md (typed **REFUTED(dead-residue-claim)** on rows 82-84/144-146), not
a filesystem change.

## Falsifier status

The falsifier for the original claim ("grep finds zero references") was run fresh and
returns 177 / 9 / 9 for the three files. Claim dead; disposition
**UNSUPPORTED(dead-residue) → REFUTED**; no deletion plan should be built from
w984dq8-probe.md.
