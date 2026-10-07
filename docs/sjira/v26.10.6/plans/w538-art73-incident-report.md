# W538 — Art 73 Serious-Incident Reporting Surface

Lane: W538 · Repo: /Users/sac/xaas @ feat/playwright-surface · 2026-10-06

## Verdict

PARTIAL_ALIVE — builder real and green; delivery channel typed OPEN (honest).

## Mapping (Art 73(1) triggers → classification derivation)

| Art 73(1) trigger | Receipt evidence | Classification atom |
|---|---|---|
| infringement of Union law | typed refusal atom `REFUSED_EUAIA_*` (Art 5(1) corpus, `eu_ai_act_admission.ex`) | `:INFRINGES_UNION_LAW` |
| harm to fundamental rights | `rights_harm: true` field or refusal atom containing `_RIGHTS_`/`_HARM_` | `:HARM_TO_RIGHTS` |
| malfunction / unauthorized actuation | any other non-empty non-EUAIA refusal atom, or receipt `status` ∈ {`:refused`, `:error`} | `:MALFUNCTION` |

Classification = deterministically sorted, deduplicated list of all atoms
applicable across the receipt set (a receipt may evidence more than one
trigger). Empty/nil receipt set → `{:error, :REFUSED_NO_INCIDENT_EVIDENCE}`.

Delivery channel: `IncidentReport.transmit/1` returns
`{:ok, %{status: :PREPARED_NOT_TRANSMITTED, reason: "no authority endpoint exists — typed OPEN per corpus 73.4-73.5"}}`
— the builder is real, the authority endpoint is not; the module never
pretends to send.

## Files (contract)

- `lib/xaas/semantics/incident_report.ex` — `build/2` + `transmit/1`
- `test/xaas/semantics/incident_report_test.exs` — 6 tests
- this plan file

## Verification ladder (real output)

Test gate, real currently-passing run (2026-10-06, exit 0):

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW538 \
      mix test test/xaas/semantics/incident_report_test.exs

    Finished in 0.05 seconds (0.05s async, 0.00s sync)
    Result: 6 passed

Strict compile gate, real currently-passing run (2026-10-06, exit 0):

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW538 mix compile

    Generated xaas app
    EXIT=0

(First cold-build attempt hit a compile error in
`lib/xaas/semantics/declared_metrics.ex` — a sibling lane's untracked file,
outside this lane's contract; it was fixed by its owning lane mid-wave and
the rerun compiled clean. No repair was made by W538 to that file.)

## Falsifier status

- structure-complete build from synthetic receipts: EVIDENCED (6/6 green)
- typed empty-receipt refusal: EVIDENCED
- classification determinism (order-independence): EVIDENCED
- honest PREPARED_NOT_TRANSMITTED: EVIDENCED
- Art 73 transmission to a real market surveillance authority: OPEN (no
  endpoint exists — corpus 73.4-73.5 gap remains open at the delivery layer)

## Cleanup note (disclosed)

Lane build root `_build-laneW538/` still exists: the coordinator `rm -rf`
was denied by the permission system. Coordinator should delete it at
integration, per the same-checkout cleanup law.
