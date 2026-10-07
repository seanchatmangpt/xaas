# W625 — Authority-Channel Registry (73.x / 3.49 / 27.1.f seam)

Lane: W625 · Repo: /Users/sac/xaas @ feat/playwright-surface · 2026-10-06

## Verdict

PARTIAL_ALIVE — the registry, the envelope, and the two real (EVIDENCED)
channels are real and green; wire transmission to a market surveillance
authority remains typed OPEN by construction (operator endpoint data,
no code change).

## Mapping (19-item inventory family → this seam)

| Inventory family | Gap | Closed by this lane as |
|---|---|---|
| corpus 73.x (Art 73(1) serious-incident notification to market surveillance authority) | no authority transmission endpoint | `:art73_market_surveillance` — typed OPEN authority channel |
| corpus 3.49 (transparency / incident seam family) | same missing endpoint | `:corpus_3_49_transparency_family` — typed OPEN authority channel |
| corpus 27.1.f (Art 27(1)(f) FRIA notification seam) | same missing endpoint | `:art27_1f_fria_notification` — typed OPEN authority channel |
| (real) internal escalation | was implicit in W538 | `:internal_escalation_receipt_corpus` — EVIDENCED, `IncidentReport.build` → the witnessed receipt corpus, cited paths |
| (real) board / audit fiduciary | was implicit | `:board_audit_fiduciary` — EVIDENCED, the CRO evidence pack over `lib/xaas/witness/`, cited paths |

Every `:OPEN` channel carries the typed basis
`"corpus 73.4-73.5 — no authority endpoint exists"` and the report format
`"Art 73 envelope per Xaas.Semantics.IncidentReport"`.

## Honest scope note

**Real**: the registry as structured data (5 channels, deterministic,
zero-config — `Application.get_env` never consulted); the Art 73 envelope
(`IncidentReport.build/2`); internal escalation and the board/audit
fiduciary channel, which record for real (`:RECORDED` against cited,
disk-verified paths); the operator seam (`with_endpoint/3` /
`registry/1` accept endpoint and channel data; unknown ids are refused
`:REFUSED_UNKNOWN_CHANNEL`).

**Typed OPEN**: wire transmission to an actual market surveillance
authority. `transmit/2` on any authority channel returns
`{:ok, %{status: :PREPARED_NOT_TRANSMITTED, endpoint: ..., reason: ...}}`
— prepared, never silently "sent". Upgrading to real transmission =
operator supplies endpoint data; no code change. `transmit/2` still
never opens a socket: the transport act remains outside the module even
with an operator endpoint bound.

Degradation guard: EVIDENCED channels cite repo-relative paths verified
at call time; a missing path flips the channel to typed `:OPEN` with a
basis naming the missing paths — a drifted path cannot keep an EVIDENCED
claim standing silently.

## Files (contract)

- `lib/xaas/semantics/authority_channel.ex` — `registry/1`,
  `with_endpoint/3`, `transmit/3`
- `test/xaas/semantics/authority_channel_test.exs` — 15 tests
- this plan file

## Verification ladder (real output)

Test gate, real currently-passing run (2026-10-06, exit 0):

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW625 \
      mix test test/xaas/semantics/authority_channel_test.exs

    Running ExUnit with seed: 463305, max_cases: 32
    ...............
    Finished in 0.1 seconds (0.1s async, 0.00s sync)
    Result: 15 passed
    EXIT=0

Strict compile gate, real currently-passing run (2026-10-06, exit 0):

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW625 mix compile

    ==> xaas
    Compiling 926 files (.ex)
    Generated xaas app
    EXIT=0

(Cold lane build compiled the full dep tree + app clean; the only
warnings during the test run were pre-existing environmental noise —
Grafana upload nxdomain, autofde not on PATH, AshA2A memory receipt
store — none from this lane's files.)

## Falsifier status

- registry structure complete (5 channels, sorted, full shape): EVIDENCED
- every :OPEN carries its typed basis + report format: EVIDENCED
- internal channel records for real (:RECORDED + cited paths on disk): EVIDENCED
- board channel records for real: EVIDENCED
- authority channels honestly PREPARED_NOT_TRANSMITTED: EVIDENCED
- determinism (pure functions of inputs): EVIDENCED
- typed refusals (unknown channel; evidence-less report): EVIDENCED
- wire transmission to a real authority: OPEN (operator endpoint data)
