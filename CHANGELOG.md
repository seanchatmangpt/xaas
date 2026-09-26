# Changelog

Reconstructed 2026-09-26 from `git log v26.9.22..HEAD` (this file did not previously
exist in the repository). Every entry traces to a witnessed commit or merge; anchors
supplied without a witnessed commit are marked UNKNOWN.

## [v26.9.26] — In Progress

- Yolo dispatch posture courts merged into the wave base (merge `dd32425`,
  `origin/weekend/zcode-yolo-dispatch-v26.9.26`): pin legacy zcode dispatch to yolo
  (`0ce6d97`), keep failover worker in yolo mode (`1978954`), falsify non-yolo zcode
  dispatch (`3b4e193`), court shell dispatcher yolo posture (`428f258`), bind shell
  court to observed worker id (`9b565b5`).
- Autonomy audit/egress/stress tasks + OCEL egress module (`ccc84db`).
- Docs: land wave-2 diataxis residue — fabric scope, cancel_work, route conservation,
  config keys, cold replay (`96d03e1`).
- Whole-tree AST-preserving mix format (`051fba3`); ontology import closure declared
  then reverted (`398ca22`, reverted by `d436f94` — net zero).
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
