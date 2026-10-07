# Refusal Ledger v26.10.6 — Canonical Anti-Vacuity Ledger

README for `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`
(RFC 8785-style canonical JSON: sorted keys, no whitespace; round-trip verified).
Lane W401, CRO-loop Stage-3 artifact, generated 2026-10-06.

## What the ledger attests

Subject: `/Users/sac/xaas @ feat/playwright-surface`, head
`d1db2b03179975213c14663b9dbd86b5ac2a14cf` (2026-10-06).

- **62 distinct `REFUSED_*` variants** declared in `lib/` (token census
  `grep -rhoE 'REFUSED_[A-Z_]+' lib/ | sort -u` = 62), each with its real
  `file:line` site(s) and a real fixture token in `test/` — per-variant
  grep = 62/62 covered, delta 0, matching the w202 authoritative token
  recount recorded in `_CLOSURE_PLAN.md` §2.1.
- **1 typed blocked tuple** — `BLOCKED_CASTLE_TRANSPORT`
  (`lib/xaas/castle.ex:950`, `{:error, {:BLOCKED_CASTLE_TRANSPORT, %{...}}}`),
  fixture at `test/xaas/castle_refusal_negative_batch4_test.exs:94-113`;
  w321 REFUTED the earlier "untyped shape" claim. Total variant entries:
  63 (62 `REFUSED_*` + 1 `BLOCKED_*`).
- **2 structurally unreachable refusal clauses** (typed, call-graph-proven):
  `REFUSED_VKG_EMPTY_CATALOG` (w378 dead-clause proof,
  `lib/xaas/semantics/vkg.ex:52`) and `REFUSED_UNKNOWN_ATTRIBUTE` (w185/w202
  reclassification). Counted inside the 62; their fixtures are dead-clause
  witnesses, not reachable-path kills.
- **Mutant-kill evidence**: 6 mutants constructed and run (w320), 4 killed,
  2 survived. Only `REFUSED_XAAS_PROJECTION_MISMATCH`,
  `REFUSED_REQUIRED_FIELD`, and `REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY`
  carry `mutant_killed: true`. Every other variant carries
  `mutant_killed: null` — honest meaning: **no witnessed mutation run**;
  its coverage is fixture/token presence, not mutant-kill. The 2 w320
  survivors: `REFUSED_VKG_EMPTY_CATALOG` (reclassified structurally
  unreachable, w378) and the actuation
  `external_admission_identity_mismatch` clause (witnessed as dead via
  `test/xaas/actuation_refusal_negative_test.exs:194`; foreign input is
  caught earlier by `external_receipt_intent_mismatch`, `actuation.ex:537`).

## How to re-verify

### 1. Coverage gate (corpus run)

Exact 12-file command from `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`:

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

Expected (w236, verbatim): `Result: 86 passed`, 0 failures, 0 skipped.

### 2. Mutation protocol (w320)

Per mutant: one-line minimal edit → run the single refusal-negative test
file on a private build root
(`MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW320 mix test <file>`) →
record pass/fail → revert by re-applying the inverse edit (`git checkout`
FORBIDDEN); `git diff --stat` must return to baseline. Full 6-mutant
receipts: `docs/sjira/v26.10.6/plans/w320-anti-vacuity-audit.md`.
VKG dead-clause proof: `docs/sjira/v26.10.6/plans/w378-vkg-kill.md`.
Note: `plans/w382-anti-vacuity-r2.md` does not exist on disk; the w320
round-2 follow-up was w378 plus the actuation dead-clause witness test.

### 3. Token recount (w202 method)

```bash
comm -23 \
  <(grep -rhoE 'REFUSED_[A-Z_]+' lib/ | sort -u) \
  <(grep -rhoE 'REFUSED_[A-Z_]+' test/ | sort -u)
```

Expected: empty output (delta 0, coverage 62/62).

## Subject binding

- repo: `/Users/sac/xaas`
- branch: `feat/playwright-surface`
- head: `d1db2b03179975213c14663b9dbd86b5ac2a14cf`
- The JSON `subject` block is authoritative; re-verify with
  `git -C /Users/sac/xaas rev-parse HEAD` before replaying gates.

## Honest scope note

In-repo courts only. Per `docs/sjira/v26.10.6/plans/w385-conformance-court.md`
(ash_a2a @ 07180bd3, 26/26 in-repo courts PASS), the conformance corpus is
the pinned in-repo court set — **NOT the official A2A TCK**;
TCK-certified remains UNSUPPORTED. Ledger coverage = fixture/token presence
(w202 delta 0, 62/62) plus 6 witnessed mutation runs (w320, 4 killed, 2
survived with typed dispositions) — not official external TCK
certification, and not a per-variant mutant-kill guarantee for the 60
variants without a witnessed kill.
