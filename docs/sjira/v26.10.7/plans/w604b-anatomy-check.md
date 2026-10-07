# W604b — W604 causal-anatomy on-disk state check (report-only)

Lane W604b, v26.10.7 campaign, 2026-10-07. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`.
Read-only verification for coordinator sequencing. No code changed, nothing committed.

## W604 on-disk state

| item | path | state |
|---|---|---|
| module | `lib/xaas/operations/approval_causal_anatomy.ex` | present, untracked (`??`), 246 lines |
| court | `test/xaas_web/controllers/approval_causal_anatomy_controller_test.exs` | present, untracked (`??`), 201 lines, 4 tests |
| wiring | `lib/xaas/billing/approval_sla_credit_apply.ex` | modified (`M`); `metadata: fn` → `ApprovalCausalAnatomy.metadata/1` present at ~line 93-96 |
| receipt | `docs/sjira/v26.10.7/plans/w604-causal-anatomy.md` | present; claims PARTIAL_ALIVE (4/4 + 16/16 witnessed, second fresh-root run pending) |

No dedicated approval controller/LiveView exists on disk — consistent with W604's receipt
disclosure that the JSON:API route `metadata` seam IS the operator surface. Router grep for
`ApprovalCausalAnatomy` shows no router edit (correct — the seam is resource-level route metadata,
not a new route).

## Court run (witnessed this session)

Fresh lane root `_build-laneW604b`, `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`:

```text
mix test test/xaas_web/controllers/approval_causal_anatomy_controller_test.exs
  → 4 passed, 0 failures, exit 0  (full recompile from empty build root, ~25 min wall)
```

This also completes W604's own receipt's pending "second fresh-root run" — the court is green
from a second independent fresh root. Standing upgrades PARTIAL_ALIVE → ALIVE on W604's own
criteria (coordinator may fold this citation into the W604 receipt at integration).

## w423 / OS-15 reconciliation (W620 CYCLE-5 caveat)

**Not genuinely missing — the caveat is stale and can be retired.**

- No `docs/sjira/v26.10.6/plans/w423*.md` exists — confirmed by `ls | grep w423` (empty).
- But `docs/sjira/v26.10.6/plans/w466-os-register-check.md:19-21` already resolved this: w319/w423
  are **in-place artifacts, not plans/ files**; w423 = `docs/cro/artifacts/bias-awareness-measures-v26.10.6.md`,
  header reads "Lane W423", grounded (typed limitations incl. `NO_DEMOGRAPHIC_BIAS_DETECTION`).
- That artifact exists on disk and is intact (verified header + grounding).
- W620's `w620-cro-entry.md:25` still carries the "w423-receipt-missing caveat" — it cites the
  caveat as carried "since w694", but w466 (later than w694 in the register lineage) already
  reconciled it. Drift is in W620's caveat text, not in the evidence.

Coordinator action available: drop the caveat in W620, cite `w466` + the artifact path.

## Transport failure disclosure

Lane-lease cleanup incomplete: `rm -rf _build-laneW604b` was **denied by the permission system**
(sandboxed and unsandboxed attempts). The empty-root build dir remains on disk at
`/Users/sac/xaas/_build-laneW604b` (test deps compiled, ~full dep tree). Coordinator or a
permitted actor should delete it at integration. Known class per osx-clnr lane-lease blindspot
memory.

## Standing

- W604 diff: **ALIVE** (all 4 court tests pass on fresh root, exit 0, witnessed this session).
- W604 receipt's own PARTIAL_ALIVE claim: superseded by this run; refresh at integration.
- w423 caveat: **stale** (artifact exists; w466 already reconciled).
- Lane W604b: complete, report-only, nothing committed.
