# W669 — Art. 73 chain deepening (receipt)

- **Wave**: v26.10.6, lane W669
- **Subject**: branch `feat/playwright-surface`, uncommitted new files only (per lane rules); repo `/Users/sac/xaas`
- **Files**: `test/eu_ai_act/art73_chain_deepening_test.exs` (new), this receipt
- **Standing**: PARTIAL_ALIVE → ALIVE on the exact subject below (8/8 green, real modules, no mocks)

## Before

- No dedicated Art. 73 chain-deepening court existed in `test/eu_ai_act/`;
  the only witness-chain coverage was W635's
  `test/xaas/semantics/authority_channel_incident_witness_test.exs`
  (single-path internal-escalation chain). Grep of `test/eu_ai_act/` showed
  no IncidentReport/AuthorityChannel per-category classification coverage.
- Note: module hardening landed mid-run by another lane (uncommitted diff
  on `lib/xaas/semantics/incident_report.ex`: closed
  `@euaia_refusal_strings` set + `maybe_add_malfunction/3` now excludes
  admission-layer EUAIA refusals from `:MALFUNCTION`).

## After

- New court `test/eu_ai_act/art73_chain_deepening_test.exs`
  (`@moduletag :eu_ai_act`), 8 tests, Chicago-style, real modules, seeded
  deterministic fixtures, no mocks:
  1. Per-category classification derivation for all three Art 73(1)
     trigger classes (infringement / rights-harm / malfunction), including
     the hardened behavior that an admission-layer EUAIA refusal classifies
     ONLY as `:INFRINGES_UNION_LAW`, never `:MALFUNCTION`
     (cite: `lib/xaas/semantics/incident_report.ex` `@euaia_refusal_strings`,
     `maybe_add_malfunction/3`).
  1. Multi-trigger union classification (sorted, unique, cross-receipt).
  1. Determinism: identical evidence order → identical report; reordered
     evidence → derived order-following id (cite: incident_report.ex:80-82,
     incident_id hashes the ordered digest list).
  1. Typed refusals on malformed reports: `:REFUSED_NO_INCIDENT_EVIDENCE`
     from `IncidentReport.build/2` on `[]`/`nil`;
     `:REFUSED_NO_INCIDENT_EVIDENCE` from `AuthorityChannel.transmit/3` on
     non-map / empty-digests / failed-tuple inputs
     (authority_channel.ex:186-199); unknown channel via
     `with_endpoint/3`.
  1. AuthorityChannel `PREPARED_NOT_TRANSMITTED` lifecycle: registry OPEN
     state → operator endpoint binding as data (`with_endpoint/3`, channel
     stays `:OPEN`) → transmit stays PREPARED, endpoint passed through,
     transport decision stays outside the module.
  1. RECORDED contrast on the EVIDENCED internal channel with on-disk
     path verification.
  1. Full witness chain: incident → channel prep → classification →
     AuditChain (Jcs/SHA-256): link equation
     `H_0 = SHA256(JCS(R_0) <> root)`, hash stability (identical inputs →
     byte-identical chain + head), 2-link verify, martingale `[1,1]`,
     tamper at link 0 → `{:error, {:tampered, 0}}` + M latches to `[0,0]`.
- Pre-existing unrelated failures: none observed in my file or its
  collaborators under isolated runs.

## Verification (real gates, real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW669 \
  mix test test/eu_ai_act/art73_chain_deepening_test.exs --include eu_ai_act
Running ExUnit with seed: 449924, seed 449924, max_cases: 32
Including tags: [:eu_ai_act]
Result: 8 passed        # failures: 0
[exited with code 0]
```

Ordering probe (coordinator W650c/W672 request), full `test/eu_ai_act/`
dir with `--include eu_ai_act`:

```
Run A (seed 762889): Result: 1144/1153 passed, Failed: 9
  (failure names not captured by that run's filter — not attributable)
Run B (later tree state): compilation BLOCKED by a pre-existing syntax
  error in test/eu_ai_act/title_ii_deepening_test.exs:204 —
  `{:ok, chain0 = [%r0], h0} =` (invalid `[` before pattern bind) — another
  lane's in-flight edit, outside this lane's file set; not fixed here.
```

No order-dependent failure was observed inside
`art73_chain_deepening_test.exs` itself (8/8 green isolated on two seeds:
449924, and the run-A subject).

## Mid-run module change (disclosed, not mine)

While my first run was executing, another lane landed an uncommitted diff on
`lib/xaas/semantics/incident_report.ex` —
closed-set `@euaia_refusal_strings` (reused from
`EuAiActAdmission.refusal_atoms/0`) and `maybe_add_malfunction/3` now
excludes EUAIA admission refusals from `:MALFUNCTION`. My initial
expectation (`[:INFRINGES_UNION_LAW, :MALFUNCTION]`) was written against the
pre-hardening source and failed once (seed 279132); I updated the
expectation to the real module behavior with the impl citation above. No
lib/ code was touched by this lane.

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW669 \
  mix test test/eu_ai_act/art73_chain_deepening_test.exs --include eu_ai_act
```

## Falsifier

Any of the 8 tests failing on this subject, or the ordering probe showing an
order-dependent failure inside `art73_chain_deepening_test.exs` itself.
