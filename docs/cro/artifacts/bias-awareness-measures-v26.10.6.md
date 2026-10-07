# Bias-Awareness Measures — v26.10.6

Lane W423, 2026-10-06. Operator-facing bias-awareness measures document for
human-oversight personnel (EU AI Act Art. 14(4)(e)). Closes doc-class gap
`GAP(NO_BIAS_AWARENESS_DOC)` (`docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md`,
Art. 14(4)(e) row; OS-15). Subject: `/Users/sac/xaas` @ `feat/playwright-surface`,
HEAD `d1db2b03`. Document only — every assertion cites a path or is a typed
limitation. Method: real grep over `lib/`, no invented claims.

## 1. Why automation bias is structurally contained here

This system is not a probabilistic recommender. Its consequential actions pass
through deterministic, typed admission gates before any DO executes:

- Every consequential actuation is admitted or REFUSED with an exact atom;
  no silent-proceed branch exists — every external-mismatch branch returns
  `{:error, atom}` with no fallback-to-proceed
  (`lib/xaas/actuation.ex:537-547,770`; fixtures `test/xaas/actuation_refusal_negative_test.exs`).
- The full refusal vocabulary is closed and counted: **62 distinct `REFUSED_*`
  variants + 1 typed blocked tuple** (`BLOCKED_CASTLE_TRANSPORT`,
  `lib/xaas/castle.ex:950`), each with a real `file:line` site and a fixture in
  `test/` — 62/62 covered, delta 0
  (`docs/cro/artifacts/refusal-ledger-v26.10.6.README.md`, §"What the ledger attests").
- **Bias propagation consequence**: because admitted transitions are replayable
  (w236 capstone: 86 tests / 12 files / 0 failures, delta 0, verbatim run output;
  `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`) and refused intent is
  typed and inspectable, a systematic bias — if present — cannot propagate
  silently. It surfaces either as a repeated typed refusal (visible in the
  ledger) or as a replayable admitted transition whose inputs can be re-derived.
  A biased-but-admitted decision is still fully attributable to its recorded
  inputs; nothing fades into an unlogged heuristic.

The safety posture is zero-config: no flag can disable a gate
(`docs/sjira/v26.10.6/plans/w322-zero-config-posture.md` — verdict "HELD", zero
category-(c) findings). An operator cannot be nudged by a config toggle that
quietly weakens oversight; gates fire with no configuration at all
(`lib/xaas_web/plugs/require_internal_api_token.ex:95-154` fail-closed 503 when
env unset; actuation gates read no `Application.get_env` on the gate path).

## 2. What the oversight operator can observe

| Surface | Path / command | What it shows |
|---|---|---|
| Refusal corpus (canonical) | `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` (README sibling) | 63 typed variants, per-variant sites/fixtures/unreachable reasons, mutant-kill evidence, HEAD-pinned `d1db2b03` |
| Per-actuation event trace | `lib/xaas/telemetry/ocel_ndjson.ex` (+ `ocel_ash_emitter.ex`, `ocel_envelope.ex`, `ocel_forwarder.ex`, `zcode_ocel_validator.ex` in `lib/xaas/telemetry/`) | Machine-readable OCEL NDJSON event log of system events (Art. 12(1)) |
| Conformance corpus run | 12-file `mix test` command in ledger README §"How to re-verify" §1 (exact file list from `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`) | Gate behavior as of now: expected `Result: 86 passed`, 0 failures |
| Token recount (drift check) | `comm -23 <(grep -rhoE 'REFUSED_[A-Z_]+' lib/ \| sort -u) <(grep -rhoE 'REFUSED_[A-Z_]+' test/ \| sort -u)` (ledger README §3, w202 method) | Any refusal token that lost its fixture — empty output = coverage intact |
| Mutation protocol | Ledger README §2 (w320 method, private `MIX_BUILD_ROOT`, revert-by-inverse-edit) | Whether refusal branches are killed by negative fixtures, not merely named |
| Authority floor | `lib/xaas_web/plugs/require_internal_api_token.ex` (401 wrong token, 503 unset env) | Fail-closed auth — no path opens the API floor without the credential |

## 3. Typed limitation: what this system does NOT measure

**LIMITATION(NO_DEMOGRAPHIC_BIAS_DETECTION).** The system measures *process*
conformance (refusals, admissions, replay), not *outcome* fairness. Specifically:

1. **No demographic or feature-level bias detection exists.** Grep over `lib/`
   for `fairness|demographic|disparate` yields exactly one hit, and it is a
   planning-theory comment ("under the fairness assumption every reachable…",
   `lib/xaas/ultracode/recovery_policy.ex:17`) — strong-cyclic policy
   terminology, not a fairness metric. No fairness metric, no protected-attribute
   handling, no disparate-impact analysis exists anywhere in `lib/`.
2. **No bias-mitigation machinery.** No reweighing, threshold adjustment, or
   counterfactual testing. The gates constrain *how* actions are admitted, not
   *whether the admitted distribution is fair*.
3. **A biased-but-admitted transition is EVIDENCED-as-replayable, not
   EVIDENCED-as-fair.** Replay proves identity and consequence, not equity.
4. **OCEL telemetry is event-shaped, not outcome-shaped.** The NDJSON surface
   records system events; it does not classify outcomes by any population
   segment.
5. **Ledger mutant-kill coverage is partial.** Only 3 of 63 variants carry
   `mutant_killed: true`; the rest carry `null` — honest meaning: no witnessed
   mutation run; coverage is fixture/token presence, not mutant-kill
   (ledger README, "mutant_killed" disclosure).

## 4. Compensating oversight protocol

Because the limitation above is typed, the compensation is a cadence, not a
claim:

1. **Corpus review (each oversight cycle):** read the refusal ledger against
   HEAD; confirm subject pin matches the deployed HEAD
   (`refusal-ledger-v26.10.6.README.md`, subject line).
2. **Re-verification gate (each oversight cycle):** run the exact 12-file corpus
   command (ledger README §1); require `86 passed, 0 failures`. A deviation is
   an oversight finding, not a footnote.
3. **Coverage drift check (each oversight cycle):** run the §3 `comm` recount;
   empty output required.
4. **Mutation spot-check (each oversight cycle, ≥1 variant):** per ledger README
   §2 protocol, kill-verify one previously `mutant_killed: null` variant and
   record the result. Monotonically converts `null` → witnessed.
5. **Escalation rule:** any repeated typed refusal of the same intent shape, or
   any corpus/deviation finding, routes to the CRO loop
   (`docs/cro/CRO-LOOP.md`) as a demand, not to individual judgment.
6. **Residual statement for oversight personnel:** if a fairness question about
   *outcomes* is in scope for a deployment, the honest answer today is
   LIMITATION(NO_DEMOGRAPHIC_BIAS_DETECTION) — that question requires
   capability that does not exist in this codebase and must be answered outside
   it (typed UNSUPPORTED(fairness-capability), not waived).

## 5. Standing

OS-15 flip: `GAP(NO_BIAS_AWARENESS_DOC)` → closed at doc class. Art. 14(4)(e)
verdict in the coverage map moves from PARTIAL (doc-class gap) to EVIDENCED
(doc-level), with the typed limitation in §3 carried forward unchanged — the
doc closes the *documentation* gap only. Code-level evidence
(`actuation.ex:537-547,770` + 6/6 fixtures) was already EVIDENCED.
