# Changelog

Reconstructed 2026-09-26 from `git log v26.9.22..HEAD` (this file did not previously
exist in the repository). Every entry traces to a witnessed commit or merge; anchors
supplied without a witnessed commit are marked UNKNOWN.

## [v26.10.8] — Released (tag `v26.10.8`; release campaign, branch `release/v26.10.7`)

Recorded 2026-10-07 by lane W619, grounded in receipts on disk under
`docs/sjira/v26.10.7/plans/` (each read before citing). Items marked
IN FLIGHT have no landed receipt yet; nothing here claims landed for an
unlanded lane.

### Removed

- GraphQL surface removed by operator directive ("no GraphQL", fix-forward):
  `/api/graphql` router scope, `Xaas.GraphqlSchema`, AshGraphql/absinthe deps
  and config, and `graphql do` blocks across 88 resource/domain files
  (receipt `docs/sjira/v26.10.6/plans/w984ao-graphql-removal.md`, ALIVE).
  The `/api` catch-all forward now absorbs `/api/graphql` with
  404 `no_route_found` (w984ao; pinned by the rewritten probe in
  `route_castle_run_surface_test.exs`).

### Added

- OS-16 provenance headers (IN FLIGHT, w605): new `x-prov-o` response header
  plug (`lib/xaas_web/plugs/prov_origin_header.ex`) wired to `/a2a` and `/api`
  scopes only (`lib/xaas_web/router.ex:29,211-213,322`); PROV-O
  `wasGeneratedBy`/`actedOnBehalfOf` constant config-driven identity
  (EU AI Act Art. 50(2) machine-generated disclosure). Standing UNKNOWN,
  pending court + mutation runs (`docs/sjira/v26.10.7/plans/w605-prov-o-plug.md`).
- PEP seam spec (w613, PARTIAL_ALIVE, spec-only): fail-closed
  agentgateway PEP filter over the eyerun_wasi wire — UDS NDJSON, 15 ms
  watchdog, lease authority (`REFUSED_LEASE_ABSENT`), five falsifier
  cases (`docs/sjira/v26.10.7/agentgateway/pep-eyerun-filter-spec.md`).
- Prompt-injection fuzz harness (w614, PARTIAL_ALIVE):
  `tests/goose_mutation_harness.py` + `tests/w614_stub_agent.py`; real
  localhost HTTP socket, 10-case corpus, gate log
  `docs/sjira/v26.10.7/plans/w614-gate-log.json` (10/10 `all_ok: true`,
  interception 1.0 on non-conforming candidates; GOOSE-ABSENT — agent leg
  pluggable via `AGENT_CMD`).

### Changed

- OS-20 four-repo Map.update sweep verdicts (w606-609 rubric; receipts
  w608/w609 on disk, w606/w607 no receipt yet):
  - `~/ash_a2a` (w608): probe on the pinned toolchain (OTP 29.1.1,
    Elixir 1.20.4) shows **documented standard semantics** — the OS-20
    deviation does NOT manifest in this repo; 42 sites classified, 0
    patches (honest no-manifestation finding).
  - `~/ash_pplan` (w609): deviation **confirmed live** on the same
    pinned toolchain; 6 residual sites classified, one class-(b)
    invariant left + disclosed (synthesis.ex:217); court 12 passed,
    0 failures (second-fresh-root gate open).
  - The two verdicts are per-repo and recorded as written; both lanes
    claim the same toolchain identity, and the disagreement is disclosed
    rather than reconciled here.
- Fleet version bump to 26.10.7 (w618, PARTIAL_ALIVE, uncommitted):
  ash_pplan, ash_a2a, gymact, ggen (Cargo.toml + ggen.toml),
  ggen_igniter, wasm4pm (package.json), ash_graphlaw
  (ontology.ttl + projection mix.exs); ferroplan/zcode-cli/
  ggen-marketplace deliberately untouched (own cadence).
- OS-20 dual-safe Map.update seal (w601p): ash_pplan main advanced by
  fast-forward to `6dbd3b0` (carries OS-20 commit `7eeaaa1`); wasm4pm
  branch pushed (`bf5d553b9`) but main advance BLOCKED(main-diverged,
  PR #659 merge-commit topology) — resolution left to operator.
- v26.10.6 sealed (w601q): gated commit `cf228da6` + annotated tag
  `v26.10.6` (tag not pushed); branch `release/v26.10.7` cut from
  the tagged subject.

### Verified (no edits needed)

- OS-13 `aex:fixtureOnly` marketplace markers (w610, PARTIAL_ALIVE):
  all three named families already marked on disk in `~/ggen-marketplace`
  (ash_r2rml, audit_trail, notification_extension); lane made zero edits
  (`docs/sjira/v26.10.7/plans/w610-fixtureonly-markers.md`).

### In flight, no receipt on disk yet

- OS-18 tautology repair (w601), OS-14 authority-ledger export (w603),
  OS-15 causal-anatomy operator surface (w604), OS-19 release-audit
  live-tag validation (w612), AIRO-SHACL compilation (w615),
  anti-vacuity ledger (w616), OS-20 rubric + remaining sweep lanes
  (w606, w607) — dispatched IN FLIGHT by the campaign dispatcher;
  their receipts are not on disk at record time, so no facts are
  claimed for them here.

## [Unreleased] — v26.10.6 (convergence, branch `feat/playwright-surface`)

Recorded 2026-10-06 at HEAD `d1db2b03179975213c14663b9dbd86b5ac2a14cf`
(`main` = `5fc56da2`), reconciled against `git log main..HEAD` (20 commits) and the
full working tree (`git status --porcelain`, 179 entries). Items listed are on disk
at record time; purely in-flight future work is deliberately absent.

### Added

- Six new Ash domains registered in `config :xaas, :ash_domains`
  (`config/config.exs:13-33`; 13 -> 19 domains, 98 -> 116 resources):
  `Xaas.A2a` (PW4, `bab0f861`), `Xaas.Conference` (XA1r, `9fb8f020` + XA4r
  projection pipeline `bedfa86e`), `Xaas.Graphlaw` (PW6, `cb65ce7b`),
  `Xaas.Igniter` (PW7, `5fee7516`), `Xaas.Security` (PW10, `84099b8f` +
  registration fix `01f4838f`), `Xaas.Witness` (PW5, `3508f427`).
- Certified-receipt witness surface (PW5, `3508f427`): `Xaas.Witness.CertifiedReceipt`,
  `Xaas.Witness.VerificationKey`, and the `Xaas.Witness.Catalog` ingest/verify context,
  plus `WitnessLive` (`lib/xaas_web/live/witness_live.ex`) and a repair migration
  (`priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs`).
- Marketplace catalog surface: catalog projection resource + ingest/search context
  (XL1, `0d948cd8`), `MarketplaceCatalogLive` browser route, and PW3 Playwright E2E
  (`d24d48a1`); graphlaw/pplan explorer surfaces (`2d0be133`, `cb65ce7b`).
- Playwright E2E surface over the real router: PW1 smoke (`b3dbdfaf`), PW8 cross-surface
  journey (`f3873049`), spec renames `*.spec.js` -> `*.spec.cjs`
  (`ash-admin-destroy`, `ash-admin-state-change`), and 16 new `.cjs` specs +
  `global-setup.cjs` in the working tree (a2a-v1, ash-admin-matrix, ash-surface-client,
  autofde-lab, chicago-pplan-deep, dev-routes, execution-fabric, ggen-workbench,
  internal-api, mcp-a2a, sparql-proxy, stripe-webhook, system-deep, witness,
  zcode-cli-fabric, next-read-ml/wd-fa-cs2 updates), run via `playwright.config.cjs`
  and a new `playwright-e2e` GitHub Actions workflow.
- Cross-repo bridge modules: `Xaas.Bridges.Ferroplan` (`lib/xaas/bridges/ferroplan.ex`)
  and `Xaas.Operations.GymactSurface` (`lib/xaas/operations/gymact_surface.ex`) with
  real-collaborator test suites (`test/xaas/bridges/`, `test/xaas/operations/`).
- `XaasWeb.A2A.NextReadAshAgent` (`lib/xaas_web/a2a/next_read_ash_agent.ex`) alongside
  the existing Next Read user-agent surface.
- Differential/oracle CI lane (`oracle-tests` job in `.github/workflows/ci_cd.yaml`):
  supplies `GGEN_IGNITER_DIR`, python3 rdflib, jq, and canonical ggen-marketplace /
  ash_atlassian checkouts so the conditionally-skipped differential suites stop
  skipping silently in CI; host-gated skips are disclosed in the job comment.
- Ash surface generation over `Xaas.Marketplace.Pack` (`8056957a`): `priv/ash_surface/`
  runtime artifacts, generated castle-bridge contract/edge modules
  (`lib/xaas/generated/`), drift guard + generator tests, and `ggen.lock`.
- `docs/sjira/v26.10.6/` plan/receipt directory (untracked) and
  `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`.
- Refusal-typing negative-court batches: `castle_refusal_negative_test.exs` plus
  batches 2-5, `actuation_refusal_negative_test.exs`, `vkg_refusal_negative_test.exs`,
  and `xaas_refusal_render_test.exs`.
- `closure-gates.yml` CI workflow (DoD 2 / P2-2 prod-compile + sync-drift gates;
  `.github/workflows/closure-gates.yml`,
  `docs/sjira/v26.10.6/plans/w327-ci-gates-draft.md`).
- Digest manifest `priv/semantic/generated/MANIFEST.json` over the machine
  registries (P2-5, `docs/sjira/v26.10.6/plans/w336-digest-manifest.md`).
- Vault prod fail-closed guard (OS-17, `w393`/`w394` class): `Xaas.Vault`
  refuses to boot in prod on the committed placeholder `CLOAK_KEY` — typed
  `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}`; dev/test
  fallback unchanged. Source pin in `test/xaas/vault_env_guard_test.exs`
  (`docs/sjira/v26.10.6/plans/w349-cloak-key-guard.md`,
  `w393-cloak-prod-wiring.md`).

### Changed

- Version advanced 26.10.2 -> 26.10.6 (`VERSION`).
- Dependency pin advances (`mix.exs`/`mix.lock`): `ash_a2a` 3325032d -> 86214551,
  `ash_r2rml` 36f25a30 -> 0d5320f6, `ex4pm` 17e7761f -> 9f7aecda,
  `ash_pplan` b9da1ad -> 5f10c97 (ref advanced 2026-10-06, v26.10.6 convergence);
  `ash_graphlaw`/`ash_affidavit`/`ex4pm` marked `override: true`.
- `config/dev.exs`: `ultracode_repos` `autofde-lab` and `gymact` paths repointed from
  `~/xaas/worktrees/repos/<repo>` (stale worktree layout) to the canonical checkouts
  `~/autofde-lab` / `~/gymact`.
- Docs truth repair (v26.10.6 vector 6): HTTP-surface recount (62 -> 70 `base(...)`
  resources; `/marketplace-catalog` and sibling LiveViews added to the browser-surface
  enumeration), 13 -> 19 domain recount with a per-domain resource table in the
  diataxis reference and README, new Witness reference section.
- `playwright.config.cjs` derives the server port from a `PW_PORT` lane lease so
  concurrent PW lanes cannot collide on port 4000
  (`docs/sjira/v26.10.6/plans/w310-lane-ports.md`).
- Docs-truth backfill of the six-vector closure facts: EU-AI-Act e2e coverage
  map (P3-2, `docs/sjira/v26.10.6/plans/w342-e2e-coverage-map.md`), zero-config
  refusal/safety posture audit
  (`docs/sjira/v26.10.6/plans/w322-zero-config-posture.md`), ontop health-check
  typing (`docs/sjira/v26.10.6/plans/w174-ontop-health-typing.md`); ash_surface
  C'/C" standing/health fixtures are sibling-repo-side
  (`docs/sjira/v26.10.6/plans/w326-ash-surface-c-fixtures.md`).

### Fixed

- ash_surface prod-compile gates (EA34, `02ce3776`) and EA35 namespace plumbing that
  unblocked full-app generation (`d1db2b03`), plus repo-wide prod-compile warning
  cleanup across `lib/` (mix.exs elixirc paths, ~90 lib/test files touched).
- TrimTab test-suite alignment with the real ContextBudget/domain API (EA80,
  `995388a5`).
- Garbled ash_surface TODO paragraph repaired in the marketplace catalog LiveView
  (XL2, `f48d80ff`).
- `Xaas.Security` domain missing from `ash_domains` at first registration
  (`01f4838f`).

### Removed

- Legacy `*.spec.js` Playwright specs superseded by the `.cjs` rename
  (`e2e/ash-admin-destroy.spec.js`, `e2e/ash-admin-state-change.spec.js`).

### Adjacent (harness-side, not in this repo)

- Receipt schema validator work lives in the harness
  (`~/.claude/dfcm/receipt.schema.json` side), not this tree; noted here only as an
  adjacency marker for the v26.10.6 convergence.

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
