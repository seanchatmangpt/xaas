# 011 — P4 Idle-Routine Observation: the mechanical evidence protocol for deleting the Claude routine

## Summary

The c4 crown falsifier (`docs/ultracode/c4-architecture.md`):
$$ Remove(ClaudeCode\ routine) \Rightarrow Behavior(Ultracode) = Unchanged $$
The hourly Claude cloud routine (`trig_01X4MaMBcr9DuFhVVZjJuLbQ`) may be
deleted only after >=24h of IDLE-routine evidence: >=3 epochs completing per
24h with receipts, continuity maintained by the loop's own ledger writes
(`docs/jira/v26.9.17/p4-claude-routine-deletion.md`). All technical
predecessors are done (P3, dispatch leg, WaveLoop, the root consolidation);
tonight's 8-hour campaign is the first big unattended run. What this ticket
adds is the missing MECHANICAL evidence protocol, so the operator's only two
acts are (1) pause the routine, (2) delete it after the evidence window.

The collector is
`priv/verifiers/p4_idle_routine_evidence.py` (python3 + psql, no app boot;
exit 0 = PASS, 1 = FAIL, 2 = could-not-collect, fail-closed — a collector
that cannot see is never a PASS). It judges exactly: completed epochs in the
window joined to a receipt whose `evidence ? 'head_verified'` (the
`AliveRequiresCourt` court key), receipts sealed in the window (standing vs
non-standing `:heartbeat`), missed-epoch reaps (continuity by the loop, not a
human), and prints `P4-EVIDENCE: PASS|FAIL (<numbers>)`.

First real run, trailing 24h (campaign night, db=xaas_dev @ main `9000c94`):

```text
P4-EVIDENCE: PASS (verified=19/19 completions >= 3, receipts=65, reaps=7, window=24h)
  completions 19, all 19 court-verified, 0 unverified
  receipts sealed 65 (standing=44, heartbeat=21); outcomes: alive=13, blocked=7,
    build_broken=1, heartbeat=21, partial_alive=5, refused=18
  missed-epoch reaps 7; failed epochs 18; in flight now: 2
```

## Status

READY — collector at `priv/verifiers/p4_idle_routine_evidence.py`; operator
pause pending. The baseline window above still had the routine unpaused; the
BINDING window is the next >=24h measured with the routine paused.

## Scope

1. Operator PAUSES the trigger `trig_01X4MaMBcr9DuFhVVZjJuLbQ` (pause, not
   delete — the P4 scope's own step 3).
2. At +24h (or later), run:
   `python3 priv/verifiers/p4_idle_routine_evidence.py`
   PASS requires: >=3 completions in the window, every completion carrying a
   `head_verified` court receipt, receipts landing (the loop's ledger
   writes), reaps present where epochs go missing.
3. PASS => operator DELETES the routine.
4. Observe one further cycle post-deletion (rerun the collector + confirm no
   human/Claude hand was required); classify per the c4 doc: scheduling/
   continuity crossed DESIGN -> ALIVE when behavior is unchanged.
5. Guard (already in place, re-check at closure): missed-epoch detection is
   an ordinary domain invariant, not bootstrap safety.

## Key Invariant(s)

Verbatim from P4:

- The routine is deleted only after >=3-epochs/24h evidence with it idle —
  never before (deleting early converts safety into an experiment).
- 並 laws apply to any standing zcode worker cadence (<=16 heavyweight
  in-flight, top-up only, [1302] storm protocol).

## Relationship to Existing Work

- `docs/jira/v26.9.17/p4-claude-routine-deletion.md` — the falsifier ticket
  this operationalizes (its Scope steps 3–5).
- `docs/ultracode/c4-architecture.md` — the binding falsifier definition.
- `docs/ultracode/wave-v26.9.17-receipts/wave1-03-bootstrap.md` — the
  routine's reconstructed contract (what deleting it removes).
- `docs/ultracode/FAILOVER-RUNBOOK.md`, `docs/jira/v26.9.21/xaas-root-consolidation.md`
  — the run surface the evidence window measures.
- Sibling verifier conventions: `priv/verifiers/{aps,eds,nounverb,spr}_backlog.py`.

## Falsifiers / What Would Defeat This

- Any cycle post-deletion requires a human/Claude hand (continuity lie).
- A collector run that cannot reach the DB reporting anything other than
  `P4-EVIDENCE: ERROR` + exit 2 (a fabricated PASS).
- Completions in the window lacking the `head_verified` court key
  (unverified_completions > 0 forces FAIL).
- Epoch count sustained only by re-litigating admission by hand (the
  Run-admission gap must be closed by the ledgered worker, not bridged).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-21 | READY | main @ 9000c94 | collector run: `P4-EVIDENCE: PASS (verified=19/19 completions >= 3, receipts=65, reaps=7, window=24h)` exit 0; falsifiers: FAIL path exit 1 (`--min-epochs 100`), ERROR path exit 2 (`--db nonexistent_db`), `--until` replay window 3/3 verified | operator pauses trigger trig_01X4MaMBcr9DuFhVVZjJuLbQ -> +24h collector PASS -> operator deletes -> one further cycle -> classify ALIVE per c4 |
