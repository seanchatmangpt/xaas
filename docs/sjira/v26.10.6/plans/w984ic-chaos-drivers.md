# W984ic — chaos-pack positive driver queries (receipt)

- Lane: W984ic on `/Users/sac/ggen-marketplace` @ `ba21c22a4` (pack `packs/ash-pplan-chaos-pack`)
- Date: 2026-10-07
- Command env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ic` (in `/Users/sac/ggen_igniter`)
- References: `w984hl-reconcile.md` (typed this work order), `w984hd-repin.md`
- Commit: NONE (per dispatch); all edits left in the ggen-marketplace working tree.

## 1. Design decision

The upstream rework @ ba21c22a put FILTER NOT EXISTS **violation gates** in
`gates/` while the templates' `for_each:` still binds to those same gate
stems. Per `GgenIgniter.GateVerify` doctrine (its own moduledoc: "an
offender-shaped query placed in `gates/` scores inverted — ship it in
verify/"), and given that `for_each` names resolve ONLY from `gates/*.rq`
stems (`Pack.discover_queries/1`), the lawful shape is:

- `gates/*.rq` = positive driver SELECTs (one row per complete entity),
- violation/refusal-shaped queries live in `verify/` (zero-rows-is-pass
  companions).

The pack already ships finer-grained per-fact census companions
(`verify/*.unbound.rq`), which subsume the violation-gate semantics; the
violation-gate bytes were preserved intact by relocation, not deletion:

```
gates/010_harness.rq      -> verify/010_harness.violation.rq   (bytes unchanged)
gates/020_invariants.rq   -> verify/020_invariants.violation.rq (bytes unchanged)
gates/030_kill_phases.rq  -> verify/030_kill_phases.violation.rq (bytes unchanged)
```

New positive drivers written for the SAME stems (`harness`, `invariants`,
`kill_phases`), so template `for_each:` bindings and `verify/cardinality.json`
keys are UNCHANGED — no template rebind needed:

- `gates/010_harness.rq` — 1 row per complete Harness row, projecting
  `?harness ?testNamespace ?generatorsModule ?harnessModule ?invariantsModule ?sabotageModule ?runsEnv`, ORDER BY ?testNamespace
- `gates/020_invariants.rq` — 1 row per complete Invariant × harness join,
  projecting `?invariantId ?title ?seed ?order ?testNamespace ?runsEnv`, ORDER BY ?order
- `gates/030_kill_phases.rq` — 1 row per complete KillPhase × harness join,
  projecting `?phaseId ?nth ?seed ?testNamespace ?runsEnv`, ORDER BY ?nth ?phaseId

The cardinality anchors (`testNamespace` / `order` / `nth`) align with the
driver projection exactly, so the ROWS contracts now agree: harness 1,
invariants 6, kill_phases 4.

## 2. BEFORE (real output, unmodified ba21c22a pack bytes)

Direct-template render (`mix ggen_igniter.sync --pack-dir PACK --template
templates/invariant_property.exs.eex --out ".../<%= invariantId %>_property_test.exs" --json`):

```json
{"data":{"drifted":[],"drifted_count":0,"lines":[],"mode":"sync","notices":[]},
 "exit_code":2,"ok":false,
 "refusal":{"code":"INVOCATION","detail":"--for-each \"invariants\" returned 0 rows -- nothing to render (a direct --template run requires a driver query that selects >= 1 row on valid data; check that the query named by for_each is a row-selecting driver, not a violation gate"},
 "standing":"UNKNOWN","task":"sync"}
```

0 files written. This is W984hl's typed fail-closed refusal (that lane's
in-lane ggen_igniter fix is live in the checkout); pre-fix ggen_igniter
surfaces the deep `reconcile_opts[:targets] must not be an empty list`
ArgumentError instead.

## 3. AFTER (real output)

Same invocations, updated pack:

- invariant template: **exit 0, 6 files** — at_most_once, replay_identity,
  terminal_absorbing, no_lost_wakeup, standing_unique, cancel_sticky
  (`..._property_test.exs` under `/Users/sac/ggen_igniter/tmp/w984ic/after/`)
- kill-phase template: **exit 0, 4 files** — kill_after_claim, kill_after_record,
  kill_after_park, kill_before_release_claim
- `mix ggen_igniter.verify --pack ... --json` → **exit 0**:
  gates pass 3/3 (`harness`, `invariants`, `kill_phases`), unbound census
  `findings: []`, cardinality contracts pass (3 gates under contract).
- Determinism: second invariant render byte-identical (diff of the 6 common
  files empty). `mix format` over all 10 rendered files → exit 0 (full Elixir
  parser pass).
- Full pack-dir mode note: pack-dir sync writes `to:` paths relative to cwd,
  so the falsifier used the per-template `--template/--out` form into a
  project-root scratch (absolute /tmp out-paths refuse: "resolves outside the
  authorized project root" — typed refusal, expected).

## 4. Cleanup

- `/Users/sac/ggen_igniter/tmp/w984ic` render scratch: **deleted** (exit 0).
- `/Users/sac/ggen_igniter/_build-laneW984ic`: **deleted** (exit 0) — unlike
  W984hd's denial. Two OTHER lanes' residue remains on disk (not this lane's):
  `_build-laneW619`, `_build-laneW686`.

## 5. Standing

- ALIVE for the pack fix: refusal reproduced on before-bytes, positive
  drivers render 6+4 targets exit 0, gates/census/cardinality verify green,
  deterministic + parseable output.
- Out-of-lane work orders (unchanged from w984hl):
  1. ash_pplan: `pack_chaos_court_test.exs` / `pack_protocol_court_test.exs`
     fixtures still assert old positive-gate row counts (1/6/4) — but note the
     courts can now pass again against the FIXED pack once the vendored copy
     is refreshed from this pack (violation companions moved to verify/).
  2. Same-rework packs (tokyo-depeg etc.) likely carry the identical
     violation-gate-as-driver bug — unverified, separate lane.
- NO commit made. Files touched (all under packs/ash-pplan-chaos-pack):
  gates/010_harness.rq, gates/020_invariants.rq, gates/030_kill_phases.rq
  (rewritten as positive drivers); verify/010_harness.violation.rq,
  verify/020_invariants.violation.rq, verify/030_kill_phases.violation.rq
  (relocated violation bytes, intact).
