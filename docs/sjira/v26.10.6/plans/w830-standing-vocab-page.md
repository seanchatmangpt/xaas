# W830 — Standing-vocabulary diataxis reference page — receipt

**Lane**: W830, xaas v26.10.6 campaign. Canonical checkout `/Users/sac/xaas`,
branch `feat/playwright-surface`, HEAD `a0723bf6`.
**Files written** (3, no commits, no build root):

1. `docs/claude/diataxis/reference/standing-vocabulary.md` (new)
2. `docs/claude/diataxis/README.md` (one index line added under Reference)
3. This receipt.

**Standing**: PARTIAL_ALIVE — the page is written and on disk, and every
code citation in it was read from the live files at this HEAD; the page is
prose, not executed code, so it cannot be ALIVE under its own law
(ALIVE requires observed execution — the very rule the page documents).

## Sources read (in-session, real reads)

- `lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex` (full, 61 lines) —
  the enforced vocabulary (`@standing_vocabulary`, lines 32-41), the two typed
  refusals `INVALID_STATUS_VOCABULARY` (49-50) and `ALIVE_WITHOUT_EXECUTION`
  (52-55), admission-boundary-only enforcement (moduledoc 20-22).
- `lib/xaas/bridges/registry.ex` (full, 106 lines) — 5 bridge rows standing
  `"UNKNOWN"` (63-94), 5 typed absences standing `"UNSUPPORTED"` (96-104 over
  `@absences` 15-31), 0-arity projection surface (34-59), no mutation API.
- `docs/sjira/v26.10.6/plans/w768-liveness-alive-gate.md` (full) — gate diff,
  verification (9 passed / 24 passed 1 excluded), mutation rationale,
  grounding of the vocabulary in real consumers
  (`capability_liveness_regressions.ex:44`).
- `docs/sjira/v26.10.6/plans/w767-registry-deepening.md` (full) — exact row
  set, no-synthesized-evidence court (b), structural R8 property (court (d)).
- Supporting greps: `REFUSED_` atoms across `lib/`
  (`eu_ai_act_admission.ex`, `castle.ex`, `atlassian_transport.ex`, …);
  `docs/claude/diataxis/reference/actuation-and-semantics.md:270-280` (refusal
  table citing `eu_ai_act_admission.ex:141-180`); AIRo pin test
  `test/xaas/semantics/airo_vendored_pin_test.exs:11-12`;
  `docs/claude/diataxis/README.md` reference section (read lines 24-31).

## What the page covers

Closed status set (8 members, code-cited) · ALIVE-requires-execution ·
standing-vs-state distinction on registry rows · `REFUSED_` refusal-atom
convention with closed condition sets and the AIRo mapping pointer
(`eu-ai-act-semantics.md` + `priv/semantic/airo/airo.ttl`) · enforcement
table with file:line sites · See Also. Lines ≤100 chars; H1 matches filename.

## Standing vocabulary (self-application)

- Page content courts (code citations match live files at a0723bf6):
  **PARTIAL_ALIVE** (read-verified, not execution).
- Page as a capability: **ALIVE gated on observed execution** — i.e. until a
  consumer-run renders/greens against it, it stays PARTIAL_ALIVE by its own law.
- No falsifier run beyond file-on-disk verification (Write tool success);
  this is a docs lane, no test surface added.

## Honest disclosure

First Write of the reference page had a garbled tail (truncated table rows);
overwritten clean in place before this receipt. Content of record is the
second version.

## Replay

```
cd /Users/sac/xaas
sed -n '32,55p' lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex
# expect: the 8-member vocabulary + both typed refusal branches
grep -c "standing-vocabulary" docs/claude/diataxis/README.md
# expect: 1 (index line present)
```
