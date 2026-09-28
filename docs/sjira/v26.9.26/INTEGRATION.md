# v26.9.26 — Integration Inventory (PRE-MERGE)

Lane L2 point-in-time snapshot for the coordinator. Standing: PRE-MERGE INVENTORY —
no merge has been performed or witnessed; every claim below is from read-only git
observation in the canonical checkout.

## Base

- Base branch: `origin/main`
- Base SHA: `f1d42eb39a71d57787a05ab2e0f2a24f3806cff5`
- Wave branch: `feat/alooop-lane2-autonomic-loop`
- Unmerged commits: **36** (`git log --oneline origin/main..HEAD`)

## Unmerged commits (sha + subject, grouped by theme)

### Fabric / gate fixes (plugin + gall-work contract)

- `38289b4` fix(plugin): interpolate ${user_config.*} from the plugin's own options object
- `a6699cc` fix(plugin): gate resolves the xaas-execution server from the plugin manifest
- `600d3b6` fix(plugin): gall-work contract forwarded to canonical — drift resolved
- `7aed353` test(plugin): re-pin gall-work contract sha256 to forwarded contract 55157758
- `40d7035` docs(plugin): gall-work contract canonical sha + plugin recovery baseline (lane L4)

### Wave-loop features (ultracode autonomic loop)

- `c338d02` feat(ultracode): provider registry + selection policy, candidate-list claims, registry-keyed defaults
- `c1f6258` feat(ultracode): cancellation verb through Lease + cancel_work MCP tool
- `e4d88aa` feat(ultracode): Recurrence — the machine-queryable loop-closure edge + xaas.autonomy.qualify
- `ccc84db` feat(ultracode): autonomy audit/egress/stress tasks + OCEL egress module
- `b9ad68f` feat(ultracode): dispatch the canonical ~/zcode-cli with the OCEL tap on
- `1259fc7` feat(ultracode): dispatch generic workers with a stream-json output contract
- `9b97e3e` feat(ultracode): wave loop concurrency mode with provider-overload drain
- `a582340` fix(ultracode): settle honors the worker's typed verdict; gate evidence + clock
- `03fafc2` fix(ultracode): STATE-declared work surface becomes the loop epoch's worktree
- `f344fa4` fix(ultracode): carry the completed epoch's worktree into tick-constructed epochs
- `33d9a84` fix(ultracode): stop ordering workers outside their fence; allow worktree-confined sh
- `538081b` config(ultracode): wave loop concurrency 1 — per-cwd lease state serializes one work surface

### Yolo dispatch posture (weekend merge + fixes + courts)

- `dd32425` merge(origin/weekend/zcode-yolo-dispatch-v26.9.26): yolo dispatch posture courts into wave base
- `0ce6d97` fix(ultracode): pin legacy zcode dispatch to yolo
- `1978954` fix(ultracode): keep failover worker in yolo mode
- `3b4e193` test(ultracode): falsify non-yolo zcode dispatch
- `428f258` test(ultracode): court shell dispatcher yolo posture
- `9b565b5` test(ultracode): bind shell court to observed worker id

### Burn-in / wave scaffold + receipts

- `e9245af` docs(sjira): v26.9.26 wave scaffold — goal.ttl GC-26.9.26, runbook, receipts (lane L1)
- `da83d0e` docs(sjira): v26.9.26 burn-in wave record — census directive, lane map, L10 audit + 9 lane verdicts
- `1019052` receipts(sjira): GC-26.9.23 gate-0 receipt refreshed by stop court rerun (lane L7)

### Census / docs truth passes

- `d04456a` docs(diataxis): truth pass — lease verb census, domain-count VERIFY marker (lane L6)
- `16db687` docs: CLAUDE/README truth pass — toolchain pin warning, native-server reality (lane L3)
- `ae73e3f` docs: CHANGELOG.md reconstructed — v26.9.23..v26.9.26 entries from witnessed commits (lane L2)
- `96d03e1` docs: land wave-2 diataxis residue (fabric scope, cancel_work, route conservation, config keys, cold replay)
- `4f7c770` docs(config): dev.exs db comment reflects observed native postgres path (lane L5)

### Tree hygiene / merges / reverts

- `051fba3` style: mix format whole tree (AST-preserving)
- `670c340` chore(gitignore): ignore per-lane _build-* MIX_BUILD_ROOT dirs
- `b90460e` Merge origin/main (f1d42eb: v26.9.24 tag PR #67 + v26.9.25 WSS/relay/provider closures) into feat/alooop-lane2-autonomic-loop
- `d436f94` Revert "chore(ggen): declare ontology import closure (lane W9)" (reverts `398ca22`, which is therefore net-zero on the tree but still in the range)

## Dirty files from other lanes

`git status --short` at snapshot time (this lane's T1, before the VERSION/INTEGRATION.md
writes): **empty** — no in-flight uncommitted edits from other lanes were present at the
instant of capture. Other lanes may have dirtied or committed since; the coordinator
must re-run `git status --short` immediately pre-merge. Known collision seams by lane
map (docs/sjira/v26.9.26): census modules, `lib/xaas/ultracode/dispatch.ex`, `config/config.exs`.

## VERSION delta

- VERSION file: `26.9.22` → `26.9.26` (this lane, T2)
- Single source confirmed: `mix.exs:13` reads `File.read!("VERSION") |> String.trim()`
  (`@version` → `version: @version`). No divergent version literal in `config/` or `mix.exs`.
  CHANGELOG.md already carries v26.9.26 entries (commit `ae73e3f`, lane L2).

## Integration state

**integration state: PRE-MERGE INVENTORY** — nothing merged; this file is the
coordinator's merge map. Git transitions belong to the coordinator only.
