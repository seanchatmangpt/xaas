# W984fc — Art. 9.x (risk-management) corpus deepening wave (7 courts)

Lane W984fc · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; **no commit** per
dispatch). Build root `_build-laneW984fc` — cold compile, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims`), `MIX_ENV=test`.

## Gap-inventory provenance

W984ec's receipt (`docs/sjira/v26.10.6/plans/w984ec-probe.md`) and the live
`deepening_map` (`test/eu_ai_act/title_iii_test.exs`) were re-read on disk.
Taken 9.x lines excluded: 9.4, 9.5.s3 (both W322 zero-config). The W984ec
remaining-range listed 9.1/9.2.a–d/9.5/9.8 as court-free. A real seam exists
in-repo: `Xaas.Semantics.AiroRiskMapping` (AIRo risk ontology projection over
the real refusal ledger) + `Xaas.Bridges.Ferroplan` (digest-pinned inverse-
reachability safe-set engine). No ferroplan-sibling reachability.rs edits; the
cross-repo source is read live at
`/Users/sac/ferroplan/crates/ferroplan/src/reachability.rs`, same convention
as `deepen_kind(:ferroplan_reachability)`.

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 9.1 | RMS = "continuous iterative process" running over live inputs | LIVE LEDGER LIVENESS: `risk_graph/0` runs twice over the real refusal-ledger file and is byte-deterministic; every ledger variant appears as an `airo:RiskSource, airo:Hazard` node with its exact `ex:refusalVariant` and a `ex:xaas-system airo:hasRisk` edge | `test/eu_ai_act/art9x_risk_management_deepening_test.exs` (court 1, test 1) | a graph built from a frozen fixture or non-enumerating variant pass would fail the per-variant node/edge asserts while generic shape tests still pass |
| 9.2.a | identify known and foreseeable risks | IDENTIFICATION: every ledger variant is a `REFUSED_`/`BLOCKED_` typed atom with ≥1 real enforcing site and a fixture | same file (court 1, test 2) | a ledger with unattributed variants fails the per-variant site assert |
| 9.2.b | estimate and evaluate the risks | ESTIMATION: `risk_concept_for/1` is deterministic (double call equal over every real variant) and family-sensitive (MANIPULATIVE→RISK_TO_INFORMED_CHOICE, FACIAL_SCRAPING→PRIVACY_RISK, DIGEST→RECEIPT_DIGEST_MISMATCH, unknown→typed default UNADMITTED_TRANSITION, never raising) | same file (court 1, test 3) | a hardcoded or raise-on-unknown mapping fails the default/sensitivity legs while single-mapping tests still pass |
| 9.2.c/9.2.d | evaluate + adopt targeted measures | TARGETED MEASURES: every `risk_controls/0` entry cites a path that exists on disk and a module that really loads (`Module.concat` + `Code.ensure_loaded?`), mitigates ≥1 typed concept, and the graph links exactly `length(controls)` `airo:isRiskControlFor ex:xaas-system` edges with per-concept `mitigatesRiskConcept` lines | same file (court 2, tests 1–2) | a control descriptor citing a missing module or path fails the load/existence legs; a graph that drops a control node fails the edge-count assert |
| 9.5/9.5.a/9.5.b | residual-risk adequacy via the inverse-reachability safe-set | DIGEST-PINNED BRIDGE: real artifact bytes at the canonical ferroplan path verify against the pin-court digest; independent sha256 math over the same bytes matches; `metadata/0`'s envelope carries `authority_ceiling: :none` / `standing: "UNKNOWN"` and the fp exports | `test/eu_ai_act/art9x_risk_management_deepening_test.exs` (court 3, test 1) | a bridge that trusted unverified bytes would pass the independent-digest leg only by coincidence; a wrong pin fails both digest legs |
| 9.8 | the RMS is tested / reverified | REVERIFICATION + FAIL-CLOSED: one flipped first byte refuses typed `:ferroplan_artifact_digest_mismatch` with observed≠expected digest through `verify_bytes/1`; the reachability decision functions (`BackwardSafeSet`, `is_safe`, `unsafe_count`) are cited live from the cross-repo source; the metadata envelope holds no authority | same file (court 3, test 2) | a fail-open bridge admits the mutated bytes and fails the typed-refusal leg; a stale source citation fails the symbol asserts |

Overlap discipline: 9.4/9.5.s3 (W322) not duplicated; the audit-chain and
dataset-gate deepenings (prior waves) own their 9.2 legs — this lane courts
the AIRo risk-mapping and ferroplan safe-set seams, which no prior court
bound to Art 9.

## Verification (real outputs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fc \
  mix test test/eu_ai_act/art9x_risk_management_deepening_test.exs --include eu_ai_act
```

- Run 1: `5/7 passed, 2 failed` (control-local-name needle used `_`-joined
  module atoms; the lib's `safe_local` PRESERVES dots —
  `ex:riskControl-Xaas.Actuation.QuiescentStop`, not `Xaas_Actuation_...`)
- Run 2: `5/7 passed, 2 failed` (String.to_atom on a dotted alias string
  produces the atom WITHOUT the `Elixir.` prefix → `:nofile`; repaired to
  `Module.concat([c.module])`; mitigates-per-concept assert loosened to
  line-scoped since the edge lists concepts on one joined line)
- Run 3 (post-repair): `Result: 7 passed` — exit 0

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fc \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Census run 1: first attempt `1388 passed, 1 failed, 1 excluded` — the one
  failure was in the sibling lane's `art15x_robustness_deepening_test.exs`
  (expected `{:error, {:tampered, 0}}` while the real AuditChain contract
  with `expected_head:` returns `{:error, {:tampered, :head}}`). Disclosed,
  not repaired by this lane: re-read on disk showed the OWNING lane had
  already landed its own repair between my runs; my second census run found
  the file fixed on disk. No cross-lane edit was made.
- Census run 1 (post sibling repair, default seed): `Result: 1388 passed, 1 excluded` — exit 0
- Census run 2 (seed 469313): `Result: 1388 passed, 1 excluded` — exit 0

(1388 ≥ the dispatch's 1355 floor; +7 over the 1381 pre-lane state = this
lane's seven courts, witnessed standalone.)

## Disclosed repair history (real contract facts learned)

1. `AiroRiskMapping.risk_controls/0` local names in the emitted graph keep
   dots (`ex:riskControl-Xaas.Actuation.QuiescentStop`) — `safe_local/1`'s
   regex `[A-Za-z0-9_.-]` preserves them; test needles must use the same
   local-name law.
2. `String.to_atom/1` on a dotted alias string yields a NON-alias atom
   (missing `Elixir.` prefix) → `Code.ensure_loaded?` returns `:nofile`;
   the lawful conversion is `Module.concat/1`. This is why all nine control
   modules initially read as not-loadable.
3. `airo:mitigatesRiskConcept` emits all concepts on ONE joined line, so a
   per-concept substring needle must be line-scoped, not exact-substring.

lib/ untouched.

## Cross-lane disclosure

Per the compile-freeze SLA: census run 1 hit the sibling lane
W984?? `art15x_robustness_deepening_test.exs` failing
(`{:error, {:tampered, :head}}` vs `{:tampered, 0}` under `expected_head:`).
NO edit was applied by this lane — on-disk re-read showed the owning lane
had already repaired it (the `expected_head:` call was gone). Census runs 1
(post-repair) and 2 are clean.

## Mock gate

`grep -nE "Mock|patch\(|\.expect\("` over the new file → zero hits
(exit 1). Chicago: real `Xaas.Semantics.AiroRiskMapping` executions over the
real refusal-ledger file, real `Xaas.Bridges.Ferroplan` digest verification
over the real pinned artifact bytes, real File/Code reads of the cited
seams; assertions on final returned state only; zero mocks, zero
application-env knobs.

## Tagging convention

`@moduletag :eu_ai_act` only; no `eu_ai_act_open_gap` tags — no line
flipped; this lane deepens already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  7/7 standalone + census 1388/0/1 ×2 (default seed and 469313), real
  commands + real exits. The census is a shared moving surface; counts are
  as-of these runs (receipt-cited counts re-read at use time).
- Remaining-range estimate: 9.x is now fully courted on its evidenced
  lines (9.1, 9.2.a–d, 9.4, 9.5, 9.5.a, 9.5.b, 9.5.s3, 9.6, 9.8); remaining
  court-free evidenced lines include Title VI–XIII lines plus any
  partially-covered lines flagged by future waves (10.2.f/g purpose leg).
- Not done (typed): no line flips, no lib edits, no corpus edits, no
  cross-lane file edits — test/ + receipt only, per this lane's contract.
