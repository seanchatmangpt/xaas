# v26.10.5 fleet wiring fan-out — X7 red team risk register

Lane X7, 2026-10-06. Read-only except this file. Findings grounded in on-disk inspection
(`.tool-versions`, `mix.exs`, `playwright.config.cjs`) of the fleet checkouts. No git, no
builds. Ranked S0 (mission-invalidating) → S2 (watch).

## S0 — Mission-invalidating

**R1. "Playwright validation of every fleet repo" is unfalsifiable for 12 of 13 repos.**
Only `~/xaas` has a `playwright.config.cjs` or `e2e/` surface. ferroplan (planner library),
ggen (Rust CLI), zcode-cli (CLI), wasm4pm, ggen-marketplace, etc. have no browser surface at
all. As written, "feature complete" has no observable for most of the fleet — the milestone
can be asserted but never falsified, violating claims-require-execution. Mitigation: X6 must
redefine acceptance per repo class. Playwright validates the xaas *served* surface
(`/ash_surface` static projection, per the `ash_surface:` alias in xaas mix.exs); libraries
and CLIs validate through their own gates (`mix test`, `cargo test`, `tsc`/CI). Otherwise
lanes will either invent browser tests for non-web repos or claim completion by assertion.

**R2. Six distinct toolchains across the fleet; OTP-27/28/29 split.** Measured
`.tool-versions`:
- xaas: elixir 1.20.2-otp-28 / erlang 28.5.0.2
- ash_surface: elixir 1.20.3-otp-28 / erlang **28.3** (differs from xaas even between the
  two central repos)
- ggen, ash_a2a, ash_pplan, beam4pm: elixir 1.20.4-otp-29 / erlang 29.1.1
- ggen_igniter: 1.19.5-otp-27 / 27.2.4
- autofde-lab: 1.18.4-otp-27 / 27.2.4

Known failure class (xaas CLAUDE.md warning + memory "no dev compile during campaign — dev
compile under live phx crashes both"): compiling under a non-pinned toolchain corrupts
`_build` and 500s the live server. With 20 lanes the probability of at least one bare `mix`
under the Homebrew elixir 1.19.5 that shadows asdf (per memory) is near 1; one bare `mix`
corrupts the shared `_build` for everyone. Wave 2 makes it certain unless per-lane
`MIX_BUILD_ROOT=_build-lane<N>` is contracted from the start. Live evidence of prior
failure: `~/ash_surface` still contains residual lane build roots
(`_build-fleet-ash_surface`, `_build-nsprefix`, `_build-pub`, `_build-tdb-surface`,
`_build-w16-11`) — the cleanup law was violated last fan-out and nothing structural prevents
a repeat.

## S1 — Likely to break the wave

**R3. beam4pm (lane R9) is the largest hazard lane.** Two independent hazards:

1. 2,462 dirty files = no exact-SHA subject; any beam4pm completion claim is structurally
   unreceiptable (a receipt requires identity; dirty tree = identity UNKNOWN). R9's
   "classify + propose split commits" deliverable pressures the agent toward staging, which
   lanes are forbidden from doing. Contract line required: R9 produces a machine-readable
   classification artifact only (path → class NDJSON); the coordinator performs all git
   transitions from that artifact.
2. Hard wiring boundary: beam4pm pins OTP-29 while xaas runs OTP-28. OTP-29-compiled .beam
   files do not load on an OTP-28 node, so beam4pm cannot be a path dep of xaas until
   toolchains align. This is a wiring impossibility, not a cleanup item.

**R4. Version-skew trap: xaas consumes pins; the lanes audit checkouts.** xaas mix.exs
consumes `ash_a2a` @ git ref `3325032d`, `ash_pplan` @ git ref `b9da1ad7`,
`ggen_igniter` hex `~> 26.10.1`, `ash_surface` path `../ash_surface` — and
`~/ash_surface/mix.exs` declares `@version "26.10.1"`. Plans written against checkout HEAD
describe subjects xaas does not load; the integration wave would wire to subjects absent
from the xaas closure. Every R-lane plan must state the pinned-ref-vs-checkout-HEAD delta.
Consequence: **"v26.10.5" is currently a name, not a state** — the central dependency is
literally 26.10.1.

**R5. Playwright flakiness under 20-lane concurrency.** From `~/xaas/playwright.config.cjs`:
`reuseExistingServer: true` + fixed port 4000 means every lane's run attaches to ONE shared
dev server backed by real Postgres (Chicago-style tests write real records). Parallel runs
pollute each other's data; a dev compile under the live server crashes it (documented
campaign crash class) and takes every lane's E2E red at once — misread as a fleet-wide
wiring defect. No `workers` cap, no `retries` configured; fixed 30s test timeout under
compile-under-load latency. Result is both false positives (flake → specs edited-to-pass,
corrupting the validation corpus) and false negatives (data pollution). Contract required:
serialized coordinator-run E2E on a dedicated port via `PLAYWRIGHT_BASE_URL`, `workers`
capped, `retries: 1`, `fullyParallel: false` (real-Postgres state).

**R6. Coordinator seam bottleneck; mix.lock is an unnamed shared seam.** All 20 lanes'
deliverables terminate in coordinator edits to the same 3–5 seam files (mix.exs, config/,
router.ex, package.json, playwright.config.*). mix.lock is a shared seam the lane partition
does not name — any lane's dep-change proposal implies lockfile churn, i.e. a collision the
partition misses. Expect the audit wave to finish and integration to stall serially.
Mitigation: lanes submit line-level seam edits; coordinator batches per commit; mix.lock
declared coordinator-only.

## S2 — Watch items

**R7. Dirty state UNKNOWN for the uncounted repos.** _LANES.md counts dirty files only for
beam4pm (2,462), zcode-cli (18), ferroplan (4). Every other repo's dirty state is unknown,
and plans whose preconditions cite checkout state reference moving subjects. Fix: the
coordinator takes a 13-repo dirty-tree inventory before wave-2 dispatch; all plans cite it.

**R8. The v26.10.5 acceptance definition does not exist yet.** `docs/sjira/v26.10.5/plans/`
did not exist before this file (X7 created it); X6's frontier ledger and acceptance
definition are absent while lanes dispatch. Lanes without a published acceptance definition
improvise one — integration then discovers 20 different definitions. X6's acceptance
definition must be a dispatch precondition for the implementation wave.

**R9. Prior-fan-out cleanup-law residue (concrete).** The residual `_build-*` directories in
`~/ash_surface` are unrecovered leases from a previous same-checkout fan-out. The cleanup
law (coordinator deletes every lane build root at integration) was violated once already;
make lane-build-root deletion a required integration checklist item, not a norm.

## Summary table

| id | sev | risk | one-line mitigation |
|---|---|---|---|
| R1 | S0 | Playwright validation unfalsifiable for 12/13 repos (no browser surface exists) | X6 redefines acceptance per repo class; PW validates xaas served surface only |
| R2 | S0 | 6 toolchains, OTP-27/28/29 split; one bare `mix` corrupts shared `_build` | per-lane MIX_BUILD_ROOT contracted; asdf shim PATH prefix in every lane prompt |
| R3 | S1 | beam4pm: 2,462 dirty files (unreceiptable subject) + OTP-29-vs-OTP-28 hard wiring boundary | R9 = classification artifact only, no git transitions; toolchain alignment is a wiring precondition |
| R4 | S1 | xaas consumes git/hex pins, lanes audit checkouts; ash_surface @version = 26.10.1 | each plan states pinned-ref vs checkout-HEAD delta; "v26.10.5" is a name until ash_surface bumps |
| R5 | S1 | shared :4000 dev server + reuseExistingServer under 20-lane load → pollution + crash-cascade flake | serialized coordinator-run E2E, dedicated port, capped workers, retries: 1 |
| R6 | S1 | coordinator seam bottleneck; mix.lock is an unnamed shared seam | line-level seam edits batched by coordinator; mix.lock declared coordinator-only |
| R7 | S2 | dirty state UNKNOWN for uncounted repos → plans reference moving subjects | 13-repo dirty-tree inventory as wave-2 dispatch precondition |
| R8 | S2 | v26.10.5 acceptance definition absent while lanes dispatch | X6 acceptance definition = dispatch precondition for implementation wave |
| R9 | S2 | residual `_build-*` in ash_surface proves prior cleanup-law violation | lane-build-root deletion is a required integration checklist item |

## Standing

X7 register — artifact exists at
`/Users/sac/xaas/docs/sjira/v26.10.5/plans/x7-risk-register.md`. Findings grounded in
on-disk inspection of `.tool-versions`, `mix.exs`, and `playwright.config.cjs` across the
fleet. Dirty-file counts beyond beam4pm/zcode-cli/ferroplan are UNKNOWN (git prohibited for
this lane). The OTP beam-file portability claim is documented BEAM semantics, not executed
here (no builds permitted).