# W716 — ferroplan bridge deepening (courts over doc claims)

- **Subject**: /Users/sac/xaas @ `a0723bf61a1c6058bdcd2d0202c9519840182a5e` (branch `feat/playwright-surface`), lane W716, build root `_build-laneW716` (deleted after run).
- **Standing**: ALIVE (local, exact head, observed execution in this lane's own test run).
- **Deliverable**: `test/xaas/bridges/ferroplan_deepening_test.exs` (new, 278 lines) — no lib changes, no commit (per lane contract).

## What the courts cover

1. **(a) Digest verification at load** — the pinned artifact passes at the canonical
   path (independent sha256 re-derivation over the real bytes); a corrupted temp
   copy (bit-flipped tail byte) and a truncated copy both refuse through the
   bridge's own gate (`Ferroplan.verify_bytes/1` — the exact gate `artifact/0`
   applies to disk bytes) with the exact typed refusal
   `:ferroplan_artifact_digest_mismatch`, expected/observed digests asserted,
   never a degraded pass. A vacuity guard proves the gate is not refusing everything
   (real pin still passes) — W603-style anti-vacuity.
2. **(b) Runtime seam truthfulness** — compile-time split on the real load probe
   `runtime_available?/0` (no mocking). In this lane's vm the probe is
   `true` (observed via `mix run -e`), so the executed branch asserts the honest
   inverse: `validate/0` **succeeds** through the pinned engine (observed execution
   of `fond_validate`). The `:ferroplan_runtime_unavailable` branch is compiled
   out in this vm — recorded below as a typed gap.
3. **(c) SELECT-only** — real observable state before/after `metadata/0`,
   `validate/0`, `invoke(%{"op" => "version"})`, `Registry.all()`: the artifact
   file bytes are unchanged and the only permitted `:persistent_term` write on
   bridge-owned keys (`{Xaas.Bridges.Ferroplan, _, _}`) is the documented
   compiled-module cache entry `{Ferroplan, :compiled, @pinned}`. All terminals
   lawful (`{:ok,_}` / `{:refused,%{code:_}}`), `authority_ceiling` stays `:none`,
   `receipt_ref` nil on the ok envelope. Environment noise (opentelemetry /
   prim_socket persistent_term writes by other OTP apps) is out of scope by key
   shape, asserted so.
4. **(d) Registry standing honesty** — `Xaas.Bridges.Registry` ferroplan row:
   exactly one row, `capability == {:bridge, Xaas.Bridges.Ferroplan}`, `state
   :bridge`, `standing == "UNKNOWN"`, `authority_ceiling :none`, `receipt_ref`
   nil, `evidence_ref` nil, correct subject, claim names the sha256 pin; no
   absence row covers ferroplan; and standing stays honestly `"UNKNOWN"` even
   after an observed successful `validate/0` (no standing fabricated without a
   receipt — R8 discipline).

## Real gate output (tail)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW716 \
  mix test test/xaas/bridges/ferroplan_deepening_test.exs

..........
Finished in 3.1 seconds (0.00s async, 3.1s sync)

Result: 10 passed
```

Runtime probe: `runtime_available=true` (`mix run -e` under the same lane build root).

## Commands / exits

| command | exit |
|---|---|
| `mix test test/xaas/bridges/ferroplan_deepening_test.exs` (3 runs: 1 fix of the SELECT-only terminal check for `Registry.all/0` returning a list; 1 fix of `:persistent_term.get/0` being a list, not a map) | 0 (final) |
| `mix run -e 'runtime_available?()'` | 0 |

## Standing vocabulary

- ferroplan bridge `artifact/0` gate: **ALIVE** (observed on the real pinned artifact).
- `verify_bytes/1` fail-closed gate: **ALIVE** (bit-flip and truncate mutations both refused typed).
- `validate/0` observed execution: **ALIVE** (envelope returned, `engine_sha256 == pin`, observed in this run).
- `:ferroplan_runtime_unavailable` refusal path: **UNKNOWN→typed gap** (compile-time branch not exercisable in a runtime-present vm without a double; existing `ferroplan_test.exs` carries the same conditional).
- Registry ferroplan row standing: honestly **"UNKNOWN"** (as declared — static entries claim no evidence).

## Typed gaps

- **G1**: `:ferroplan_runtime_unavailable` branch is not exercised in this run —
  the vm loads wasmex transitively. Forcing it would require a double (banned by
  default) or a runtime-less vm. Honest options: run the suite in a vm without
  wasmex on path, or accept the compile-time conditional as the seam.
- **G2**: `artifact/0` reads a compile-time-pinned path (`@artifact_path`), so
  "corrupted artifact on disk" is exercised through `verify_bytes/1` (the same
  gate), not through an on-disk mutation of the sibling checkout. Making the
  path an opt-in override is a coordinator seam, not a lane edit.
- **G3**: envelope `standing` stays `"UNKNOWN"` even on the observed successful
  `validate/0` — `Xaas.Bridges.envelope/3,4` is called with the default standing
  and no receipt is attached (`receipt_ref` nil). Per doctrine (checkpoint ≠
  crown; receipt = observed execution + bound identity) this is honest, but it
  means the observed execution in this run is not yet bound into a standing-
  raising receipt by the bridge itself.

## Notes

- No `@moduletag :eu_ai_act` — the ferroplan bridge is a planner capability
  bridge with no EU-AI-Act Art-line tie.
- No mocks, no interaction-only assertions; all assertions on real terminal
  state (`{:ok,_}` / `{:refused,_}` envelopes, real digests, real
  `:persistent_term` and file-byte state).
- Lane lease honored: `_build-laneW716` deleted after the final run.
