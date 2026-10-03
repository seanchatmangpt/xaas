# Changelog

Reconstructed 2026-09-26 from `git log v26.9.22..HEAD` (this file did not previously
exist in the repository). Every entry traces to a witnessed commit or merge; anchors
supplied without a witnessed commit are marked UNKNOWN.

## [v26.10.2]

- Live SemanticJiraBridge on hex ggen_igniter 26.10.1 (`2517f626`, `7dc90027`): the
  post-G1 seam is real — mix.exs drops the post-G1 git pin for
  `{:ggen_igniter, "~> 26.10.1"}` (hex ships public `event_digest/1` +
  `legacy_event_digest/1`, the snapshot-bound descriptor contract carrying
  `admitted_work_order`/`digest_form`, 3-key requires, receipts-v2 law); the compile
  guard requires only the current digest function — `derives?/1` probes the
  deprecated `legacy_event_digest/1` at run time (`function_exported?/3` +
  `apply/3`), so pre-v26.10.1 logs still verify inside the shrinking window and
  refuse typed (`legacy_digest_rule`) after it closes; the echoed bridge map
  full-aligns to ggen's
  ten-key list (`snapshot_digest` → `source_snapshot_digest` in the bridge map only —
  the receipt-contract key is unchanged); `verified_events/1` converts TransitionLog
  refusals into `{:log_untrusted, _}` instead of raising; 101-test bridge suite green.
- fleet-R v2 execution keys in RProjection (`a3613404`): receipts now carry
  `work_order_id` (same resolution as identity.subject), `origin_authority` (mirror of
  authority), `provider`, and `provider_execution_id` (native run_id, fail-closed to
  the ext native run_id); `native/court` moved under `provider_ext.xaas`, no legacy
  fallback; laws V2-1..V2-4 each with a typed refusal and a mutant test; the three
  committed episode `.r.json` fixtures hand-extended (epochs gone from both fabric
  DBs — regeneration would falsify the reference; seal chains intact), fleet
  validator ADMITTED x3 (was REFUSED x3).
- plan-next (`ff40f495`, `4b848624`): a promote event drives one real
  `AshA2A.Replan.Loop` over the ash_pplan FOND port. `Xaas.Ultracode.SemanticDrive.PlanNext`
  is pure across `domain/1`, `plan/2`, and `to_work_order/2`; the `admit/2` seam is
  the opt-in bounded-consumption step (`SemanticJira.admit_work_order/1` + optional
  SHACL) — the drive does not call it; the drive's `:plan_next` step stays
  journal-only (`plan_next.json` + `PolicyCandidateEmitted` OCEL event, emitted never
  auto-admitted), underdetermined candidates refuse, non-progressable to-standings
  refuse. `mix xaas.episode --plan-next` is default OFF — committed episodes reproduce
  bit-identically.
- crown binds `:snapshot` (`2928abd4`): `@descriptor_binding :graph` → `:snapshot` —
  the pinned emitter (ggen_igniter e9c7afa) carries `admitted_work_order` +
  `digest_form` on every descriptor, so XaaS now refuses a descriptor rewritten
  between emission and materialize (the hole `:graph` left open); ticket-dir nil now
  raises the named `{:ticket_dir_missing, ...}` error (nil is deliberate under
  MIX_ENV=test — no config default).
- semantic-crown CI job (`bd7c0ad9`): weekly `.github/workflows/semantic-crown.yml` —
  the full crown loop (observe → SHACL admit → frontier → descriptor → Run/Epoch →
  worker → real fabric court → sealed receipt → ledger transition → dependent
  eligibility → fresh-OS-process replay) runs to standing ALIVE on real
  infrastructure, plus the negative control: a claimed-ALIVE vacuous candidate is
  sealed build_broken, refused by the reconciler, and leaves the work order on the
  frontier.
- env-honest drive tests (`eb5928eb`): `@foreign` now mirrors `build_erts/2`'s actual
  resolution (pin-first, then first ascending install holding `releases/<otp>` +
  executable `bin/erl` — never newest); cargo-absent skip arms with named reasons
  added to the two gated module conds — an under-provisioned runner yields a named
  skip, never a fake red (46 tests: 1 failure → 0).
- chore(release): ggen_igniter hex floor `~> 26.10.1`; VERSION 26.10.2 (`7dc90027`).

## [Unreleased]

- In-process sequenced drain (`4daf2f98`): `mix xaas.ultracode.drain` runs the
  `SequencedDrain` Reactor — wave → merge into the canonical checkout → verify →
  next wave, typed stop on conflict, build break, or test failure — replacing the
  removed `scripts/ultracode_sequenced_drain.sh` (verify compiles in
  `MIX_ENV=test`, `f2ebfde6`).
- OCPM analysis over OCEL 2.0 logs (`c249c00d`): `Xaas.Ocel.Ocpm` +
  `mix xaas.ocel.ocpm` compute object-type interactions and per-object-type
  activity frequency over one OCEL 2.0 JSON log (interaction/frequency only — no
  Petri-net synthesis).
- SA2A bridge `admit/3` admits optional semantic evidence before transport
  (`7ea89055`, `3730d761`): `Xaas.Sa2a.SemanticEvidence.admit_optional/1` runs
  first and only admitted evidence attaches to the wire request as
  `semantic_evidence` — malformed evidence is a typed refusal, never a transport
  attempt. Typed consumer-refusal corpus: provenance digest (`bc9b5ed8`),
  canonicalization (`27f341c7`), contract revision (`a2224dc9`).
- `Xaas.Fabric` module family (`7f0ac93d`, `eab1920a`): thin facade +
  `Fabric.Plane` behaviour over five plane adapters (projection, process, law,
  evidence, actuation) and the CASTLE bridge, `Fabric.Failure` taxonomy, derived
  standing (`:evidenced`/`:refused`/`:unknown`); `ash_graphlaw`/`ash_affidavit`
  join as dev/test path deps.
- Stale-plan gate (`382bb9f7`): `Xaas.Sa2a.Court.admit/2` can pre-check a plan's
  preimage fence (`admitted_preimage_hash`/`preimage`, fingerprinted via
  `Xaas.Planning.StalePlanGate.fingerprint/1`) before any port call, refusing
  `:stale_plan_refusal`; fenceless plans are unaffected (opt-in).
- `run_suspended` OCEL event (`2a7d80df`, `67f46392`): ultracode OCEL egress
  projects `Run.suspended_at` as a `run_suspended` event.

## [v26.9.28] — Integration (branch `claude/serene-wozniak-jwnj94`)

Requirements: `docs/rfc/REQUIREMENTS-v26.9.28.md`.

- Merged 28 of 37 unmerged remote branches into the integration line (20 clean, 8 with
  `-X ours`, HEAD winning conflicting hunks). Ledger of the 9 not merged, with reasons, is
  in the requirements doc (3 unrelated histories; 4 stale early-Sept branches; `backup/*` skipped).
- `runtime/v26.9.28-execution-closure-r14` replaced the stub `research_runtime` files
  already on HEAD (add/add) with its 55-file formatted implementation.
- Integration repair: machine-generated syntax slips (FOND, provider_fabric, trimtab,
  provider_mesh, sjira), `do: case` parenthesization, `Checkpoint.migrate/2` header,
  `EngineerWorkflow` guard, `SteeringPolicy` with-clause, `Snapshot` enforce_key vs default,
  `Lease.@refused_consequence_tools`, `WaveLoop` ClosureController alias.
- Guard: `test/xaas/release/tree_parse_guard_test.exs` (all sources parse; no fused `ident!=`).

## [v26.9.27] — In Progress (branch `v26.9.27/closure-runtime`, draft PR #90)

- Lease-reclaim kernel merged (`68315314`, from `origin/feat/v26.9.27-lease-reclaim-kernel`):
  `Lease.reclaim_epoch/4` is the single reaper for WaveLoop, Engine, Autonomic.
- Dispatch wedge guard (`68315314`): supervised `Xaas.Ultracode.TaskSupervisor` +
  `async_stream_nolink` (a linked stream made the DOWN reclaim path unreachable),
  `on_timeout: :kill_task` -> typed `:dispatch_timeout` reclaim + requeue, serialized
  Run/Epoch construction, Dispatch `:deadline_at_ms` bounding failover retries.
- Provider recovery (`045de008`, `3f3a3c95`): typed failure classes, per-provider
  circuit breaker, registry skips open providers, half-open admits exactly one probe.
- Capability court execution (`b6faa86a`, `68efe7fa`): unconfigured SA2A no longer
  blocks; `:reuse` executes as `:known_replay`; `:generate`/`:compose`/`:extend` run
  the marketplace qualification harness (real `ggen sync run` x2) via `PackGenerator`.
- Self-dogfood (`b6faa86a`): `mix xaas.self_digest` + daily `SelfDigestWorker`
  admit recurring frontier clusters as UltraCode self-work orders.
- FOND recovery policy (`ae522613`): WaveLoop chaining is an ash_pplan strong-cyclic
  policy admitted at compile time (`Xaas.Ultracode.RecoveryPolicy`).
- OCEL 2.0 tick evidence (`328f0b8f`): validated per-tick events related to step, run,
  epoch, receipt, provider.

## [v26.9.26] — In Progress

- Yolo dispatch posture courts merged into the wave base (merge `dd32425`,
  `origin/weekend/zcode-yolo-dispatch-v26.9.26`): pin legacy zcode dispatch to yolo
  (`0ce6d97`), keep failover worker in yolo mode (`1978954`), falsify non-yolo zcode
  dispatch (`3b4e193`), court shell dispatcher yolo posture (`428f258`), bind shell
  court to observed worker id (`9b565b5`).
- Autonomy audit/egress/stress tasks + OCEL egress module (`ccc84db`).
- Per-epoch `XAAS_LEASE_ID` keyed lease paths: gate + `xaas-lease.mjs`
  resolve the `-<id>-`-suffixed path first, legacy per-cwd fallback
  (`0a3e5d7`).
- Opt-in `XAAS_SWEEP=1` typed read-only sweep profile for fleet-wide
  inventory gates (`360a867`).
- Dispatch lifeline, work-conserving chaining, adaptive width;
  `:ultracode_pool_capacity` default 5→10 (`e12e117`).
- Docs: land wave-2 diataxis residue — fabric scope, cancel_work, route conservation,
  config keys, cold replay (`96d03e1`).
- Whole-tree AST-preserving mix format (`051fba3`); ontology import closure declared
  then reverted (`398ca22`, reverted by `d436f94` — net zero).
- Wave loop concurrency upgrades (`a8e055fc`): [1302] adaptive setpoint
  (grow +1 per clean 10-minute pressure window, hold on 1-2 rate-kill
  signatures, drain −4 at ≥3, floor 1; opt-in ceiling
  `:ultracode_wave_loop_concurrency_max`, setpoint persisted beside the
  loop telemetry) plus work-conserving batch dispatch (all ready steps per
  tick via `Task.async_stream`, serial settles, dead dispatch tasks typed
  `:construction_refused`).
- Event-driven semantic wave (`541fe5ce`): an admitted frontier transition
  enqueues its dispatch immediately (`SemanticWaveTrigger.enqueue/1` rides
  `SemanticWork.materialize/2`'s transaction; one pending wave per
  `graph_digest`/`repository_identity` pair, Oban uniqueness
  `period: :infinity`); the `*/30 :semantic_wave` cron demoted to watchdog.
- CS2 fleet-contract bridge (PR #87): `cs2-fleet-contract/26.9.27` projection
  (`FleetContract` + `priv/cs2/fleet-contract.json`), `SemanticJiraBridge`
  consuming authority-free Semantic Jira candidates, `AshA2ABridge.from_a2a/1`,
  `EngineerWorkflow` — representation boundary only, never runtime authority.
- SelfDigest kernel + CapitalCensus — Ultracode as a work subject of itself
  (`4a2e9d11`, `a9e3fa04`, `0a4e1a0a`): self-gap generation from the wave
  loop's own telemetry, experience clusters and the route lattice, census
  tables + work orders in the existing Ultracode domain (migration
  `20260927203551`); work orders are the new work-subject surface.
- UNKNOWN: substitution-receipt-binding verification (operator anchor; branch already
  in main per dispatch contract, but no commit witnessed in this session's log).
- In progress: docs/contract/marketplace truth wave (no landed commit witnessed yet).
- Ops note (UNKNOWN, no commit witnessed): fabric server compile-state break restored
  2026-09-26.

## [v26.9.25]

- Qualify interchangeable providers and transports (#79, `a5b2e22`).
- Bounded WSS/HTTP tunnel wire admission court (#77, `810a9b1`).
- Unify relay ACK mutation with admission gates (#76, `6e43f17`).
- Bounded remote relay replay contract (#70, `dd1f2e1`).
- Bounded runtime fabric `/internal-api/fabric` (P4 B1+B2) (#72, `99de79b`,
  merge `c10cdab`).
- Provider registry + selection policy, candidate-list claims, registry-keyed
  defaults (`c338d02`).
- Cancellation verb through Lease + `cancel_work` MCP tool (`c1f6258`).
- Recurrence — the machine-queryable loop-closure edge + `xaas.autonomy.qualify`
  (`e4d88aa`).
- WD CS2 Semantic Case Study court + generated claims ledger A2-A6 (`e2d9b22`;
  PRs #68 `08553fc`, #69 `70f7ea7`, #71 freeze on merge sha `a742b7b`).
- wd-fa: freeze Sep 25 submission on `f9670f44` with court digest (`7eb82ca`);
  re-freeze on merge `70f7ea75` (A8) (`38f0df2`).
- wd-deck: `pres:lockOf` → `pres:blockOf` on slide-07 block-07 and slide-13 block-04
  (`be8cbf0`).
- sjira X1: origin-authority backfill; retire the compile_prose intake (`9202518`,
  PR #74 `2684305`); loosen crown builder specs for dialyzer (`2ee0832`).
- Receipts: AC-13 case-study-schema, AC-14/F-12 wd-evidence-ceiling, F-09
  cloud-runtime (`6a63d89`, PR #73 `e039967`); durable post-tag AC-13 re-run and
  artifact landing (`28a94c5`, `0249ca4`, PR #75 `4f176fd`).

## [v26.9.24]

- Tagged via PR #67 from `release/v26.9.24-tag` (merge `f1d42eb`); exact lightweight
  tag cut in CI (`a46729d`, `f0ba135`).
- STOGAF: human authority as a typed RDF subject (`ed80099`); specification finalized
  for v26.9.24 (`696f2af`); R-09 bound to MorningBriefView with browser-origin court
  (`ef5f195`); build LiveView assets before the browser court (`0afc314`).
- wd-deck: repin repaired semantic presentation pack (`e2da107`); bind final repaired
  presentation-pack subject (`0fe0d68`); repin durable presentation pack from one
  source (`e89b5b4`).
- wd-fa: split observation and learning OCEL object types (`6435824`); drop opaque
  MapSet membership in CapabilitySelector (`7c45782`); STOGAF modules mix-formatted
  (`95d1d29`).
- sa2a: keep main's full Xaas.Actuation forbidden-pattern court (`31f7503`).

## [v26.9.23]

- Full suite + dialyzer green under the xaas `.tool-versions` pin (R1-X-PIN)
  (`60972f8`); lane gate receipts at the exact heads (`1e2c373`, `fc6c133`).
- GC23-1 builds ggen_igniter under its own toolchain pin, not the caller's
  (`cb39912`).
- Courts and stop court default to the canonical checkouts, not the retired shadow
  tree (`6fd5958`).
- GC-26.9.23 evidence resealed from the owning stop court at the frozen subject
  (`d0b9921`).
- Repository topology is transport, never ontology (`812392e`).
- The release automation lives in its owning repository (`65466f8`).
- wd-fa: presentation regenerated through ggen igniter (`36bc01c`); September 25
  case-study submission added and routed (`a3e3c6b`, `299925a`); cost/storage
  tradeoffs documented (`1b6da57`); JSON context route made Phoenix-valid and
  guarded (`b45d463`, `ee6c3e3`, `1ebbaff`).
- Workflow-lock: portable default path; refuse instead of spinning (`d59e3cc`).
