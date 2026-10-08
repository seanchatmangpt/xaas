# W984ey — Art. 14.x (human oversight) corpus deepening (3 courts, 6 lines)

Lane W984ey · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; **no commit** per
dispatch). Build root `_build-laneW984ey` — cold compile, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims`), `MIX_ENV=test`.

## Gap-inventory provenance

W984ec's receipt (`docs/sjira/v26.10.6/plans/w984ec-probe.md`) lists the
remaining court-free evidenced lines including "14.1/14.2/14.3.a–b
(quiescent/oversight dedicated deepening)". The live `deepening_map`
(`test/eu_ai_act/title_iii_test.exs`) was re-read on disk: 14.1/14.2/14.3/
14.3.a/14.3.b carry only `[:quiescent_typed]` (± `:margin_gate`) inside the
generated per-line test bodies; no dedicated deepening file takes any 14.x
line. Already-courtered lines, NOT duplicated:

* 14.4.b — `test/xaas/semantics/automation_bias_countermeasure_test.exs`
  (+ `[:briefing]` deepening kind)
* 14.4.c — `test/xaas/semantics/counterfactual_test.exs` (+ shapley kinds)
* 14.4.d / 14.4.e — `test/xaas/actuation/quiescent_stop_test.exs`
* 14.4.a — deepening kinds `[:counterfactual, :audit_chain]` in
  title_iii_test bodies; this lane adds only a dedicated durable-monitoring
  leg, not a duplicate.
* 14.4, 14.5, 14.5.s2 — `:not_applicable` in the corpus (connector clause /
  absent biometric scope); no court possible, classified upstream.

## Courts (test/eu_ai_act/art14x_oversight_deepening_test.exs)

Real oversight seams: `Xaas.Actuation.QuiescentStop` (real Ash kernel over
sandboxed Postgres), `Xaas.Semantics.RobustMargin`, `Xaas.Semantics.
Counterfactual`, `Xaas.Semantics.OversightGovernance`.

| line(s) | Art. 14 requirement | court | mutation rationale |
|---|---|---|---|
| 14.1 / 14.3 / 14.3.a | oversight measures BUILT IN and EFFECTIVE; halt to a safe state | court 1: a named human authority drives a REAL stop DO on a real `Xaas.Marketplace.Provider` (subject → `:suspended`, typed receipt `target: :quiescent`, `%DateTime{}` stopped_at, authority echoed); the oversight act is durable as an `ActuationIntent` claim row carrying the assigned authority; no-authority stop is refused `:REFUSED_STOP_AUTHORITY` BEFORE any DO (subject untouched, no claim row); the attractor is monotone (fresh-key stop on the stopped subject refuses `:REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT`, safe state kept) | a stop surface that never landed a DO, an unassigned-authority pass-through, or a non-monotone attractor fails; generic shape tests still pass |
| 14.2 | oversight prevents/minimises risk | court 2: the margin gate binds at the EXACT measured boundary (`RobustMargin.admit` ADMITTED at margin == penalty `l_h·l_e·eps`, `{:error, :REFUSED_ROBUST_MARGIN}` one notch below); the typed oversight refusal is a recourse variable — recorded as a W506 decision record whose check list contains a real `human_oversight` authority check + the real margin gate, the counterfactual repair (margin restored) flips the decision to `:admitted`, `changed?` true, causal explanation naming `robust_margin` | a gate with a non-strict/non-inclusive boundary fails; a refusal not attributable (changed? false or explanation not naming the margin check) fails, while generic ADMITTED/REFUSED shape tests still pass |
| 14.3.b | deployer-implementable oversight procedures as usable material | court 3 leg 1: `OversightGovernance.fria_oversight_description/0` + `ai_literacy/0` return structured data whose every cited path (controls + measure evidence_paths + `cited_paths/0`, union, uniq) exists on disk at test time | a governance surface citing non-existent paths fails; prose-only material has no structured data to enumerate |
| 14.4.a | overseer can understand/monitor | court 3 leg 2: after a REAL stop DO, the sealed receipt is durable and inspectable — `ActuationReceipt` row with `resource_module == inspect(Provider)`, `subject_id` match, `action == "actuate_status"`, `status == :succeeded` | a stop without a durable monitorable receipt fails the leg |

Typed NOT-BUILT dispositions: none within 14.x evidenced range — every
evidenced 14.x line is either courtered by this lane, already courtered
upstream (listed above), or `:not_applicable` upstream. `lib/` untouched;
no corpus edits; no line flips.

## Verification (real outputs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ey \
  mix test test/eu_ai_act/art14x_oversight_deepening_test.exs --include eu_ai_act
```

- Run 1: `2 passed, 1 failed` (court 1 asserted `claim.authority ==
  authority_map`; the ledger serialises authority as a STRING-KEYED map —
  real storage contract, court repaired to assert the string-keyed
  round-trip). Run 2 (post-repair): `Result: 3 passed` — exit 0.

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ey \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Census attempt 1: exit 1 — compile abort in ANOTHER lane's in-flight
  `test/eu_ai_act/art26x_postmarket_deepening_test.exs` (`misplaced
  operator ^k`, file mtime 20:10). Per the compile-freeze SLA I did not
  touch another lane's file; the owning lane repaired it. Real census:
  `Result: 1388 passed, 1 excluded` — exit 0, 0 failures
  (1388 ≥ the dispatch's 1355 floor; +3 over the pre-lane 1355 = this
  lane's three courts, witnessed standalone).
- Mock gate: `grep -nE "Mock|patch\(|\.expect\("` over the new file →
  zero hits (exit 1).

## Tagging convention

`@moduletag :eu_ai_act` only; no `eu_ai_act_open_gap` tags — no line
flipped; this lane deepens already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  3/3 standalone + census 1388/0/1, real commands + real exits. The census
  is a shared moving surface; counts are as-of these runs (receipt-cited
  counts re-read at use time).
- Not done (typed): no line flips, no lib edits, no corpus edits — test/
  + receipt only, per this lane's contract.
- Cleanup: `rm -rf /Users/sac/xaas/_build-laneW984ey` was DENIED by the
  permission system in this session (same denial class as W984ds2b's
  receipt). The lane build-root lease is therefore still on disk and must
  be deleted by the coordinator at integration, per the fanout cleanup
  law.
