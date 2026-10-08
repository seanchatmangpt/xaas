# W984eg — docs deepening: actuation-and-semantics + http-api-surface (probe/receipt)

Date: 2026-10-07. Docs-only lane; no code, no build root, no commit.

## Subject

- `docs/claude/diataxis/reference/actuation-and-semantics.md` (already
  modified by other lanes in the working tree; appended only)
- `docs/claude/diataxis/reference/http-api-surface.md` (inspected; no change
  needed — see below)

## Code-verified claims (all read from the working tree this session)

1. `lib/xaas/actuation/spg_gate.ex` exists; `SpgGate.admit/1` requires
   `[:graph_id, :graph_version, :node_id, :edge_id]` non-empty and state
   `:admitted`/`"ADMITTED"`; `fingerprint_token/1` guard head returns
   `{:error, :spg_fingerprint_atom_keyed}` for string-keyed input (moduledoc
   cites W650x → W984dq5 F2).
2. `lib/xaas/actuation.ex:345` `:ok <- admit_spg(args.authority)` inside
   `do_admit/2`, after `admit_authority/2`; opt-in atom `:spg` key; nil key
   no-op; string-key ignored; gate refusal surfaces as
   `{:error, {:spg_gate_refused, reason}}` (defp at `actuation.ex:642`).
3. Commit `f0321df2` = "test(actuation): W650h22 — land W984dq6 SpgGate
   integration (F2 guard + single-funnel seam + courts)" (verified via
   `git log`/`git show --stat`).
4. `lib/xaas/semantics/graphlaw_wasm.ex`: digest pin file
   `priv/graphlaw.wasm.sha256` = `fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38`
   (read from file on disk); admission pipeline digest pin → compile → WASI
   allowlist → required exports; W637 artifact imports exactly 7
   `wasi_snapshot_preview1` functions (moduledoc, witnessed W644/W984dh);
   `@wasi_allowlist` is a disclosed 12-entry superset; `@call_timeout_ms 15`
   watchdog.
5. GraphQL excision: the ONLY remaining graphql mention in either reference
   doc was `actuation-and-semantics.md:140` "no HTTP/GraphQL/RPC surface"
   (an absence claim); fixed forward to "no HTTP/RPC surface".
   `http-api-surface.md` has zero graphql mentions (grep confirmed).

## Edits (before → after excerpts)

### actuation-and-semantics.md

1. Head (after intro paragraph) — added:

   > Landed 2026-10-07: the SPG identity gate (`f0321df2`, receipts
   > `docs/sjira/v26.10.7/plans/w650h22-commit.md`, `w650h33c-commit.md`) and
   > the graphlaw WASM host (`2f2748b3`, `781f7d53`; W638/W644) are now part
   > of this contract — see "SPG identity gate" and "Graphlaw WASM host"
   > below.

2. New section "SPG identity gate (fail-closed, opt-in)" before "Provider
   lifecycle contract": seam `admit_spg/1` after `admit_authority/2`, opt-in
   `:spg` atom key, no string-key fallback, typed refusals
   (`:spg_identity_required`, `:spg_not_admitted`,
   `{:spg_gate_refused, reason}`, `:spg_fingerprint_atom_keyed`), courts
   `test/xaas/actuation/spg_gate_test.exs` + `spg_integration_test.exs`
   (8 cases).

3. Line 140: "no HTTP/GraphQL/RPC surface" → "no HTTP/RPC surface"
   (graphql fix-forward).

4. New section "Graphlaw WASM host (`Xaas.Semantics.GraphlawWasm`)" before
   "Graphlaw bridge admission gate": digest pin `fc23a292…cb38` via
   `priv/graphlaw.wasm.sha256`, 7 witnessed WASI imports against a 12-entry
   allowlist superset, 15ms watchdog, no authority.

### http-api-surface.md

No edit. Verified: zero graphql mentions; SPG gate and the graphlaw WASM host
introduce no new HTTP route, mount, or auth surface (both are admission/host
surfaces behind the existing actuation/semantics boundaries), so the HTTP
surface doc has nothing stale to fix forward.

## Receipt provenance note

The task named receipts `w650h22-commit.md` / `w650h33c-commit.md`; on disk
they live under `docs/sjira/v26.10.7/plans/` (not v26.10.6). Doc note cites
the v26.10.7 paths.

## Standing

Docs brought to truth with landed code; all doc claims re-verified against
source on disk this session. Verification = `grep` receipts above; no tests
run (docs-only lane).
