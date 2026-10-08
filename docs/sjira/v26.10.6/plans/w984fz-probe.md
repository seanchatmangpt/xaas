# W984fz — architecture-overview.md truth refresh (docs deepening)

Lane: W984fz, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`.
Docs-only lane: no commit, no build root, no lib/ edits. Sibling edits to the target
file untouched.

## Before (excerpts, as-read at lane start)

- Intro paragraph ended at "read this first, then follow the links for depth on any one
  topic." — no dated landed-note; no mention of SpgGate, `Xaas.Compat.Otp29MapUpdate`,
  or the sa2a `Execute` authority-evidence flow anywhere in the file.
- "Reactor Actuation" bullet stopped at the Ultracode lease kernel sentence.
- Cross-cutting list ended at the OCEL telemetry bullet.

## After (excerpts, on disk, verified by re-read/grep at lines 10, 137, 197, 207)

1. **Dated landed note (line 10)** — "Landed 2026-10-07" paragraph after the intro
   citing:
   - SPG identity gate `f0321df2` (receipts `docs/sjira/v26.10.7/plans/w650h22-commit.md`,
     `w650h33c-commit.md`, matching the convention already used in
     `actuation-and-semantics.md:5-8`),
   - OS-20 compat guard `c6bf5bbc` (receipt `w984ee-probe.md`),
   - sa2a Execute repair `1ac2ad42` (receipt `w984es-repair.md`),
   - graphlaw digest-pinned Wasmex host: linked, not re-derived, to
     `actuation-and-semantics.md` "Graphlaw WASM host" (W984eg, `w984eg-probe.md`).
2. **Reactor Actuation bullet extended (line ~137)** — fail-closed SpgGate identity
   admission: all four identity fields + admitted state, typed refusals
   (`:spg_identity_required`, `:spg_not_admitted`), gate grants no authority, BRCE path
   exclusive (`lib/xaas/actuation.ex:639-660`, single caller `admit_spg/1`).
3. **Two new cross-cutting bullets (lines 197, 207)** — OS-20 guard
   `Xaas.Compat.Otp29MapUpdate` (present-key-arm-only fun application, court
   `test/xaas/compat/otp29_map_update_court_test.exs`) and sa2a `Execute`
   authority-evidence flow (before_transaction hook, `Bridge.execute` evidence map,
   `1ac2ad42`).

## Code-verified claims (all re-read from disk this session)

- `lib/xaas/actuation/spg_gate.ex` — `admit/1` requires `[:graph_id, :graph_version,
  :node_id, :edge_id]` + state in `[:admitted, "ADMITTED"]`; typed errors
  `:spg_identity_required` / `:spg_not_admitted`; moduledoc: "It grants no authority;
  the existing XaaS Actuation/BRCE authority path remains exclusive."
- `lib/xaas/actuation.ex:639-660` — `admit_spg/1` is the gate's single caller; nil
  `:spg` key = opt-in no-op; refusal `{:error, {:spg_gate_refused, reason}}`; "Present =
  SpgGate.admit/1 must open ... fail-closed".
- `lib/xaas/compat/otp29_map_update.ex` — moduledoc names OS-20, applies `fun` only in
  the explicit present-key arm, court
  `test/xaas/compat/otp29_map_update_court_test.exs`. Landed in `c6bf5bbc`
  ("feat(semantics/compat): ... W984ee OTP-29 Map.update compat module").
- `lib/xaas/sa2a/changes/execute.ex` — moduledoc: before_transaction hook, refusal must
  not roll back the outer actuation transaction sealing the `:refused` receipt,
  authority evidence map into `Bridge.execute`. Repair commit `1ac2ad42` confirmed via
  `git show --stat` (touches `lib/xaas/sa2a/changes/execute.ex` +
  `test/sa2a/changes/execute_deepening_test.exs`, receipt `w984es-repair.md`).
- Graphlaw Wasmex host documented by W984eg in
  `docs/claude/diataxis/reference/actuation-and-semantics.md` (digest-pin → compile →
  WASI-allowlist pipeline, lines 180-218); overview links only.
- GraphQL excision: zero `graphql` occurrences in
  `docs/claude/diataxis/explanation/architecture-overview.md` (grep-verified) — the
  excision is reflected; the W984et-confirmed live exception (vkg.ex `graphql/2` via
  ash_r2rml) is not described in this file, so nothing to correct.

## Standing

ALIVE (docs surface): file re-read on disk post-edit; no commit per lane contract.
