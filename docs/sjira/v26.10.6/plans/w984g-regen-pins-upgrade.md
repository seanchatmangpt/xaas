# W984g — regen pin corrections + capital_census census upgrade receipt

Lane W984g, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`.
No commit, per lane contract. Standing: **ALIVE** for all three corrected pins
(each witnessed green for real before pinning) and the census upgrade; the
library.manufacture surface remains **BLOCKED(policy-floor-upgrade-pending)**
(owner decision, per lane contract item 3).

## Subject (files touched)

- `test/xaas/generated/registry_drift_guard_test.exs` (tracked, M) — 3 regen-command
  pins replaced with W983c's corrected lines. No sha256 pin values changed (all four
  relevant files byte-verified against their existing pins before edit; the surfaces
  themselves are untouched — regen --check proved unchanged).
- `lib/xaas/generated/regen_check.ex` (untracked, W982g's — SCOPE NOTE below) —
  capital_census/facts.ex upgraded `:disclosed_skip` → `:ggen_igniter_check`
  (argv with all four `--query` flags incl. mandatory `facts_spec`); the
  library.manufacture skip_reason rewritten from the refuted
  `UNSUPPORTED(renderer-escape-bug)` to `BLOCKED(policy-floor-upgrade-pending)`
  with the corrected actuation command recorded for the owner.
- `test/xaas/generated/regen_check_court_test.exs` (untracked, W982g's) — counts
  updated consistently: ggen surfaces 2→3, executed 3→4, skipped 8→7; skip-reason
  assertion now accepts `UNSUPPORTED(` or `BLOCKED(`; `@moduletag timeout:
  900_000` added.

**Scope note (typed disclosure)**: the lane contract said "write only
test/xaas/generated/ + receipt", but task items 2 and 3 explicitly direct edits to
the census, which lives at `lib/xaas/generated/regen_check.ex`. Those two edits were
made there as directed; no other lib/ file was touched.

## Per-pin before/after

### Pin 1 — `lib/xaas/generated/zcode_event_registry.ex`
- BEFORE: `mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack --template .../zcode_event_registry.ex.eex --out lib/xaas/generated/zcode_event_registry.ex`
  (W983c-witnessed failure: `ArgumentError: no *.rq files found in .../gates/` — discovery is gates/-only, queries live in `queries/`)
- AFTER: `mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack --query event_types=priv/packs/xaas_zcode_ocel_pack/queries/010_event_types.rq --query object_types=priv/packs/xaas_zcode_ocel_pack/queries/020_object_types.rq --query qualifiers=priv/packs/xaas_zcode_ocel_pack/queries/030_qualifiers.rq --query transitions=priv/packs/xaas_zcode_ocel_pack/queries/040_transitions.rq --template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex --out lib/xaas/generated/zcode_event_registry.ex --on-stale preserve`
- Green tail (this lane, real run): `{"data":{"drifted":[],"drifted_count":0,..."planned: skip lib/xaas/generated/zcode_event_registry.ex (unchanged) (engine: oxigraph, 4 queries, 63 total row(s))"},"exit_code":0,"ok":true,...,"standing":"ALIVE","task":"sync"}` exit 0.

### Pin 2 — `lib/xaas/telemetry/ocel_envelope.ex`
- BEFORE: `mix ggen_igniter.sync --pack-dir priv/packs/xaas_telemetry_pack --template .../ocel_envelope.ex.eex --out lib/xaas/telemetry/ocel_envelope.ex` (same gates/-only discovery failure)
- AFTER: `mix ggen_igniter.sync --pack-dir priv/packs/xaas_telemetry_pack --query envelope_fields=priv/packs/xaas_telemetry_pack/queries/001_envelope_fields.rq --template priv/packs/xaas_telemetry_pack/templates/ocel_envelope.ex.eex --out lib/xaas/telemetry/ocel_envelope.ex --on-stale preserve`
- Green tail: `{"data":{"drifted":[],"drifted_count":0,...,"(engine: oxigraph, 1 query, 4 total row(s))"},"exit_code":0,"ok":true,...,"standing":"ALIVE"}` exit 0.

### Pin 3 — `lib/xaas/generated/capital_census/facts.ex`
- BEFORE: `mix ggen_igniter.sync --pack-dir priv/ggen/ultracode-self-digest-pack --template templates/facts.ex.eex --yes` (cwd template-resolution miss; and even W982g's 3-query variant CompileErrors without the 4th query `facts_spec.rq`)
- AFTER: `mix ggen_igniter.sync --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl --query g_table=priv/ggen/ultracode-self-digest-pack/queries/g_table.rq --query facts=priv/ggen/ultracode-self-digest-pack/queries/facts.rq --query facts_spec=priv/ggen/ultracode-self-digest-pack/queries/facts_spec.rq --query frontier_outcomes=priv/ggen/ultracode-self-digest-pack/queries/frontier_outcomes.rq --template priv/ggen/ultracode-self-digest-pack/templates/facts.ex.eex --out lib/xaas/generated/capital_census/facts.ex`
- Green tail: `{"data":{"drifted":[],"drifted_count":0,...,"(engine: oxigraph, 4 queries, 20 total row(s))"},"exit_code":0,"ok":true,...,"standing":"ALIVE"}` exit 0. (W983c additionally proved full-render output byte-identical to tracked.)

### Pin 4 (NOT changed) — `lib/mix/tasks/xaas.library.manufacture.ex`
- Regen command string annotated, NOT actuated, per lane contract: skip stays
  `BLOCKED(policy-floor-upgrade-pending)` (was the WRONG `UNSUPPORTED(renderer-escape-bug)` —
  W983c refuted the escape bug; the drift is a policy-floor STRENGTHENING awaiting an
  owner decision). Recorded unblock step for the owner: run
  `mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack` (explicit in-repo
  scratch `--out` during any trial — bare form actuates the tracked surface), then
  re-pin `@expected_sha256`, then retire the skip.

## Verification (real runs, pinned toolchain, `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984g`)

- Fresh-cold lane build root: `rm -rf _build-laneW984g && mix compile` → exit 0.
- Pre-edit sha256 spot check (shasum): all four pinned files match existing
  `@expected_sha256` values — no pin-value changes needed.
- Lane incident (disclosed): first verification run hit a SyntaxError in
  `lib/xaas/conference/registration.ex` from ANOTHER lane's in-flight edit
  (compile-freeze collision, not this lane's file). Resolved by that lane within
  the SLA window; recompile exit 0. This lane did not touch that file.
- First full court run: 3/5 passed — the 2 failures were `ExUnit.TimeoutError`
  after 60000ms (the court now spawns 3 real ggen/oxigraph subprocesses per test,
  ~190s wall). Real infra gap; fixed with `@moduletag timeout: 900_000`.
- Run A: `mix test test/xaas/generated/registry_drift_guard_test.exs test/xaas/generated/regen_check_court_test.exs` → **5 passed**, exit 0.
- Run B (×2 requirement): same command → **5 passed**, exit 0.

## Standing

| item | standing |
|---|---|
| zcode_event_registry pin | ALIVE (corrected command witnessed exit 0, drifted_count 0) |
| ocel_envelope pin | ALIVE (witnessed exit 0, drifted_count 0) |
| capital_census/facts.ex pin + census `:ggen_igniter_check` | ALIVE (witnessed exit 0, drifted_count 0; byte-identical per W983c) |
| library.manufacture | BLOCKED(policy-floor-upgrade-pending) — owner decision; corrected command recorded |
| guard + regen_check court ×2 | ALIVE (5/5 passed, exit 0, both runs) |

Lane build root `_build-laneW984g` (450M) left in place for the coordinator: the
lane's `rm -rf` was denied by the permission system at close. It is a pure build
artifact — coordinator should delete it at integration per lane-lease law.
