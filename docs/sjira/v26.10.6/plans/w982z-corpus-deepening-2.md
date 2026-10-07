# W982z — Corpus evidenced-line deepening wave 2 (2 lines, 6 courts)

Lane W982z · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per dispatch).
Build root `_build-laneW982z` — cold compile, pinned asdf toolchain
1.20.2-otp-28, `MIX_ENV=test`.

## Gap-inventory provenance

Newest inventory on disk: `w547-gap-flips.md` (13 flips; corpus at
`docs/eu_ai_act/corpus.json` drives per-line verdicts at compile time, so
the on-disk inventory is the live inventory). w547's flip table and W981t's
receipt (26.6 / 14.4.b / 15.5.s3, plus W704's 27.3) were read; the two
lines deepened here are all already **EVIDENCED**, had no deepening court
binding article text to real executed behavior, and do not overlap W704's
or W981t's lines:

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 26.7 | deployer-employer shall inform workers' representatives + affected workers before use | `Xaas.Semantics.OversightGovernance.worker_notification/0` claims the record IS the receipt corpus + OCEL stream; liveness witnessed through real `Xaas.Actuation.run/4` + real `Xaas.Library.Book` create/denial over real Postgres → real `OcelAshEmitter` appends to the real shared `priv/ocel/ash-actions.ndjson`, each line validated by the real `Xaas.Ultracode.Ocel.Validator` | `test/xaas/deepening/art_26_7_worker_notification_liveness_test.exs` (3 courts) | emitter stops writing real events (handler detached / fail-safe swallows every append / log path drifts from the `worker_notification/0` citation) → liveness + conformance courts fail while w537's structural path-existence courts still pass |
| 27.1.c + 27.1.d | affected persons/categories + specific risks of harm, machine-checkable FRIA | `Xaas.Semantics.OversightGovernance.fria/0` per-right evidence bases bound to EXECUTED contracts: all 8 Art. 5(1) atoms refused for real via `EuAiActAdmission.admit/1` + `describe/1` (executed set == declared set), `DatasetAdmission.admit/2` refuses `REFUSED_BIAS_THRESHOLD` / admits balanced (both directions), zero-PII invariance under injected undeclared PII fields | `test/xaas/deepening/art_27_1cd_fria_evidence_liveness_test.exs` (3 courts) | a cited surface's contract drifts from the FRIA's claimed basis (bias gate stops returning `REFUSED_BIAS_THRESHOLD`, an Art. 5 atom becomes unreachable, or undeclared fields start influencing verdicts) → evidence-liveness courts fail while structural FRIA courts (paths exist, nonempty text, determinism) still pass |

(Court 27.3 = W704; 26.6 / 14.4.b / 15.5.s3 = W981t; FRIA + worker-notification
STRUCTURE courts already in `test/xaas/semantics/oversight_governance_test.exs`
— duplication avoided by asserting liveness/causality properties those
structural courts do not.)

## Verification (real tails)

Cold-lane build; census command, run ×2 green (different ExUnit seeds):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982z \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Run A (two new files, seed 591063): `Result: 6 passed` — exit 0
- Run B (census, incl. W981t's 9): `Result: 15 passed` — exit 0
- Run C (census retry after a sibling-lane mid-edit): `Result: 15 passed` — exit 0

Disclosed non-lane failure (pre-existing to this lane, sibling-lane
mid-edit captured): one census attempt failed compiling
`lib/xaas/dev_seeds.ex` (a file this lane never touched; `M` in the shared
tree, compile-freeze SLA territory). Immediate retry compiled clean and the
census went green ×2 — same-command, fresh-run reproduction, not a lane
defect.

Mock gate: grep of the two new files → only prose "no mocks" lines; zero
`Mock`/`patch(`/`.expect(` usage. Chicago: real Ash actions over real
sandboxed Postgres + the real attached telemetry handler + the real shared
ndjson on disk (26.7); real deterministic modules over seeded populations
(27.1.c/d).

## Tagging convention

Both files carry `@moduletag :eu_ai_act` (corpus-article census); runs used
`--include eu_ai_act --exclude eu_ai_act_open_gap`, the census command. No
`eu_ai_act_open_gap` tags — no line was flipped; this lane deepens
already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  6/6 and 15/15, real commands + real exits, run ×2.
- `_build-laneW982z`: `rm -rf` permission-denied in this lane session
  (same fallback as W981t/W928b/W926/W980i) — **LEFT FOR COORDINATOR** per
  the fanout cleanup law.
- Real contract facts witnessed (worth retaining): actuation OCEL event
  type is `provider.actuate_status` with `outcome` `"ok"`/`"error"` and a
  class-level `provider` relationship object; a real `Ash.Policy.Authorizer`
  denial (Book create, actor nil) reaches the emitter and records
  `"error"` while attribute-validation failures never reach the telemetry
  span; `EuAiActAdmission.admit/1` is invariant under undeclared keys
  (zero-PII) and the executed atom set equals `refusal_atoms/0` minus
  `REFUSED_EUAIA_MALFORMED_CANDIDATE`.
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract.
