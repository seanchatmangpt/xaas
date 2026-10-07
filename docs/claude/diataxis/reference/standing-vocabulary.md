# Standing Vocabulary

The closed standing-status set enforced in code, the ALIVE-requires-execution
law, the standing-vs-state distinction, and the typed refusal-atom convention.
All facts are code-cited at the enforcement site; no fabricated standing.

## The closed status set

`CapabilityLivenessReceiptStatusGate` enforces a closed vocabulary at the
`:ingest` action of `Xaas.Operations.CapabilityLivenessReceipt`
(`lib/xaas/operations/validations/capability_liveness_receipt_status_gate.ex:32-41`):

```elixir
@standing_vocabulary ~w(
  ALIVE
  REFUTED
  BLOCKED
  UNKNOWN
  PARTIAL
  PARTIAL_ALIVE
  UNSUPPORTED
  BUILD_BROKEN
)
```

Any other value refuses typed `INVALID_STATUS_VOCABULARY`
(`capability_liveness_receipt_status_gate.ex:49-50`). The set is grounded in
the resource's real consumers: the regression detector keys on `"ALIVE"` vs
non-`"ALIVE"` (`lib/xaas/operations/capability_liveness_regressions.ex:44`);
the liveness suites exercise ALIVE/REFUTED/BLOCKED/PARTIAL and
UNSUPPORTED/BUILD_BROKEN (W768 receipt, Diff item 1). Enforcement is at the
admission boundary (`:ingest`) only, deliberately not a data-layer enum
migration; historical rows, read paths, and `detect/1` are untouched
(gate moduledoc, lines 20-22).

## ALIVE requires execution

`status == "ALIVE"` requires `executed == true`
(`capability_liveness_receipt_status_gate.ex:52-55`); otherwise the ingest
refuses typed `ALIVE_WITHOUT_EXECUTION`. Inspection, workflow presence, or a
named receipt are not execution: a receipt claiming ALIVE without observed
execution is structurally impossible at admission. Non-ALIVE statuses
(REFUTED/BLOCKED/UNKNOWN) with `executed: false` ingest unaffected
(W768 receipt, Diff item 3).

## Standing vs state (registry rows)

`Xaas.Bridges.Registry` (`lib/xaas/bridges/registry.ex`) carries two distinct
fields per row:

- `state`: `:bridge` (real bridge module) vs `:unsupported` (truthful absence;
  `registry.ex:96-104` over `@absences`, `registry.ex:15-31`).
- `standing`: `"UNKNOWN"` for every bridge row (`registry.ex:63-94`),
  `"UNSUPPORTED"` for every absence row. Standing becomes non-UNKNOWN only
  from real receipts bound to observed execution (R8): the registry has no
  mutation API — the export surface is exactly the 0-arity projections
  `all/0`, `ids/0`, `absences/0` (`registry.ex:34-59`) — so standing can only
  change by recompiling the literal entries, an admitted code transition,
  never a runtime silent upgrade (W767 receipt, court (d)).

Every row also carries the exact Chicago subject
`urn:chicago:agentic-payment:purchase-001`, `authority_ceiling: :none`,
`evidence_ref: nil`, `receipt_ref: nil` — no synthesized evidence
(W767 receipt, court (b)).

## Refusal-atom convention

Typed refusals are atoms with a `REFUSED_` prefix, each bound to a closed,
checkable condition set — never a prose reason. Canonical surface: the
EU-AI-Act admission moduledoc table (`lib/xaas/semantics/eu_ai_act_admission.ex:16-20+`),
e.g. `REFUSED_EUAIA_MANIPULATIVE` (no `:manipulate_behavior`/`:deceptive`/
`:subliminal` technique class), `REFUSED_EUAIA_SOCIAL_SCORING` (no join of
`:social_behavior` data into an unrelated decision context). Other enforced
examples across the tree: `Xaas.Castle` and `Xaas.Sjira.AtlassianTransport`
carry their own `REFUSED_*` atoms (grep-verified `REFUSED_` hits in
`lib/xaas/castle.ex`, `lib/xaas/sjira/atlassian_transport.ex`).

AIRo mapping pointer: the class-to-atom mapping for EU-AI-Act prohibited
practices (a)-(h) lives in
`docs/claude/diataxis/reference/eu-ai-act-semantics.md` (AIRo mapping section)
backed by the vendored AIRo ontology `priv/semantic/airo/airo.ttl`, pinned by
`test/xaas/semantics/airo_vendored_pin_test.exs:11-12`.

## Where each is enforced

| Law | Enforcement site (file:line) |
|---|---|
| Closed status set | `validations/capability_liveness_` `receipt_status_gate.ex:49-50` |
| ALIVE requires execution | `validations/capability_liveness_` `receipt_status_gate.ex:52-55` |
| Gate wired into `:ingest` | `operations/capability_liveness_receipt.ex` (W768 diff item 2) |
| Standing never silently upgraded | `lib/xaas/bridges/registry.ex:34-59` (0-arity only) |
| Truthful absences as typed data | `lib/xaas/bridges/registry.ex:15-31` (`@absences`) |
| Typed refusal atoms (EU-AI-Act) | `lib/xaas/semantics/eu_ai_act_admission.ex:141-180` |

Typed refusal regression courts: W768's deepening suite pins both gate
refusals non-vacuously (`test/xaas/operations/capability_liveness_deepening_test.exs`;
W768 receipt, Mutation rationale).

## Higher-level standing uses (v26.10.6)

Above the code-enforced gate, three v26.10.6 wave artifacts apply the
vocabulary at campaign level:

- **Receipt grading (PARTIAL_ALIVE → ALIVE)**: W842's priority e2e
  revalidation ran the 6-spec set fresh-boot at `a0723bf6` (24 passed /
  1 designed skip / 0 failed), upgrading W752's PARTIAL_ALIVE to ALIVE for
  the priority set and closing W822's fresh-boot UNKNOWN
  (`docs/sjira/v26.10.6/plans/w842-e2e-revalidation.md`).
- **Typed-gap register statuses**: W859's consolidated register grades 42
  disclosed gaps as OPEN (36, no repairing receipt), REPAIRED (4, a later
  receipt's real run closed them), or TYPED-OPEN (2, honest permanent
  disclosure) — each row cites both a disclosing and a status-bearing
  receipt (`docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`).
- **Census-minus-gate delta as the honest-gap measure**: W821's terminal
  census of the EU-AI-Act suite showed census (1348) − green-gate passed
  (1347) = exactly the one excluded typed open-gap test (49.3),
  deterministic across repeat runs — the delta is the measured honest gap,
  certifying ALIVE at census level
  (`docs/sjira/v26.10.6/plans/w821-terminal-census-2.md`).

## See Also

- [`reference/actuation-and-semantics.md`](actuation-and-semantics.md) —
  receipts, refusal contracts, EU-AI-Act refusal table.
- [`reference/eu-ai-act-semantics.md`](eu-ai-act-semantics.md) — refusal-atom
  corpus ids and AIRo mapping.
- `docs/sjira/v26.10.6/plans/w768-liveness-alive-gate.md` — gate receipt.
- `docs/sjira/v26.10.6/plans/w767-registry-deepening.md` — registry court
  receipt.
