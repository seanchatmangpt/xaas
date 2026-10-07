# W982v — LimitGate Doc Reconcile Receipt

- Lane W982v, xaas v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface` (uncommitted; coordinator owns commits).
- Docs-only lane: no mix commands run, per lane contract.

## Task

The LimitGate surface grew after W981m documented it (W981k wired
`max_request_bytes`, `n3_max_term_bytes`, `n3_max_total_bytes` at the
`do_assess` seam). Reconcile the diataxis LimitGate section against the
current surface; verify the SPEC-30 section against the router.

## Sections touched

1. `docs/claude/diataxis/reference/actuation-and-semantics.md`
   — "Graphlaw bridge admission gate (`Xaas.Graphlaw.LimitGate`)" section
   (was lines 174-201). Rewrite folded into one coherent passage:
   - the 3 new byte-limit wires with their exact seams and engine truths
     (`max_request_bytes` abi/16 MiB on the rendered request JSON;
     `n3_max_term_bytes` n3/64 KiB on the largest N-Triples line;
     `n3_max_total_bytes` n3/256 MiB on total facts bytes), citing
     `w981k-registry-limits-seams.md`;
   - the full 15-row registry disposition (4 enforced with named seams —
     `max_json_depth` W976 + the 3 byte limits W981k; 11 unmeasured with
     no xaas consumer, gateable via `enforce/2`, no artificial
     plumb-through; disclosed gap: `Registry.engine_limits/0` is still
     abi-only);
   - the W976 fail-open semantic with its DB-independence rationale
     (dead-host court pins the gate's verdict as never a database
     verdict; row-absent ⇒ admit, monitored gap).
   - `test/xaas/graphlaw_limit_seams_test.exs` added to the court list,
     with W981k's 48/51 first-run first-defect catch recorded.
2. `docs/claude/diataxis/reference/http-api-surface.md` — SPEC-30 section
   NOT modified (verdict: consistent, see below).

## Consistency verdicts

- **SPEC-30 vs router: CONSISTENT, no correction.** Read fresh:
  `lib/xaas_web/router.ex:302-309` — `scope "/api/graphql"` with
  `pipe_through([:require_internal_api_token, :api])` and
  `forward("/", Absinthe.Plug, schema: Xaas.GraphqlSchema,
  json_codec: Jason)`; registered before the catch-all
  `forward("/api", XaasWeb.ApiRouter)` at line 336; `{:absinthe_plug,
  "~> 1.5"}` at `mix.exs:148`. Every claim in W982l's SPEC-30 passage
  matches the live router (the doc cites no line numbers, so W982l's
  receipt line range `302-313` vs today's `302-309` is not doc drift).
- **LimitGate section vs code: GROUNDED.** Wiring verified on disk before
  writing: `lib/xaas/bridges/graphlaw.ex` `gate_engine_limits/3` at
  lines 106/146-160 (three `LimitGate.enforce/2` calls, first refusal
  wins), `lib/xaas/bridges/registry.ex:67-68` `engine_limits/0`.
  Claims about engine truths and registry row count are cited from the
  W981k receipt (operator-admitted O*), not re-derived from the graphlaw
  repo in this lane.

## Standing

- LimitGate doc passage: PARTIAL_ALIVE (matches the surface's standing —
  4/15 limits measured at true seams, 11 unmeasured-no-consumer).
- SPEC-30 doc section: ALIVE (consistent with router, unmodified).
- Diataxis reconcile: DONE (docs-only, no falsifier run — the underlying
  courts were run and disclosed by w976/w981k; this lane cites, does not
  re-run).

## Files

- Modified: `docs/claude/diataxis/reference/actuation-and-semantics.md`
- Created: `docs/sjira/v26.10.6/plans/w982v-limitgate-doc-reconcile.md`
- No commit made (per lane contract).
