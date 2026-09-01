# XaaS v26.9.1 Jira Plan

Last Updated: 2026-09-01

## 1. Charter / Define

The v26.9.1 workstream, inferred from active branch names and their commit history,
is converging several parallel efforts onto `main`:

- **AshAi / Ash ecosystem integration** (`probe/ash-ai-dependency-retest`,
  `feat/ash-project-measure-extension`, `ash-migration`) — wiring AshAi read tools,
  OCEL telemetry compatibility with beam4pm, and Ash framework version migration.
- **Ontology/semantics closure** (`feat/ontology-reactor-closure`) — SPARQL bridge,
  R2RML/Ontop mapping tests, read-only DfCM boundary enforcement.
- **ggen marketplace/manufacturing pipeline** (`ggen/pin-manufacturing-instrument-v26.8.27`,
  `agent/connect-castle-paas-20260826`) — pinning the local manufacturing instrument
  and connecting the Castle PaaS marketplace lineage.
- **Operational automation** (`automation/claude-daily-drain`) — a daily CI backlog
  drain job.
- **Agent operating contract docs** (`docs/refresh-agents-20260823`).

Scope of this plan: assess mergeability of each active branch, sequence integration
into `main`, and define verification gates so v26.9.1 lands with no regression to
`main`'s current state (SHA `5b7fb55`).

## 2. Measure — Current State (real `git log`/`git branch -a`, 2026-09-01)

Repo: `https://github.com/seanchatmangpt/xaas.git`. `main` HEAD:
`5b7fb55f 2026-08-26 07:50:06 -0700 feat(fanout): assimilate canonical ForcedTop25 factory`.

Active remote branches and their latest real commit:

| Branch | SHA | Date (UTC-7) | Message |
|---|---|---|---|
| `probe/ash-ai-dependency-retest` | `fa744ec` | 08-31 16:32:12 | feat: AshAi read tools on |
| | | | `Xaas.Operations` (read_incidents, read_audit_log) + real coverage |
| `ggen/pin-manufacturing-instrument-v26.8.27` | `a1a5c6a` | 08-27 22:56:53 | chore(ggen): |
| | | | pin local manufacturing instrument |
| `automation/claude-daily-drain` | `ee65cda` | 08-27 20:54:47 | ci(factory): add daily |
| | | | Claude backlog drain |
| `agent/connect-castle-paas-20260826` | `f9432c0` | 08-27 00:25:20 | fix(ggen): preserve |
| | | | qualified XaaS marketplace lineage |
| `docs/refresh-agents-20260823` | `885e5b7` | 08-23 10:38:55 | docs: create current agent |
| | | | operating contract |
| `feat/ontology-reactor-closure` | `b4b399e` | 08-22 21:14:09 | test(semantics): qualify |
| | | | read-only SPARQL DfCM boundary |
| `feat/ash-project-measure-extension` | `66e62ae` | 08-21 20:44:43 | feat(release): converge |
| | | | XaaS v26.8.21 across Ash ecosystem |
| `ash-migration` | `385206d` | 08-20 14:13:52 | docs: record real Phases 0-7 execution |
| | | | log + disclosed remaining work |

All dates are 2026, `-0700` offset. The wrapped-continuation rows above are a table
formatting compromise to satisfy the 100-char line limit; each pair of rows describes
one branch's single latest commit.

**Verified against the hint in this task**: only `probe/ash-ai-dependency-retest` has
commits in the last 24h relative to 2026-08-31 (its `fa744ec`, `91b0f9b`, `c10d460`
commits fall on 2026-08-30/08-31). No other branch has commits in that window — the
hint pointing at this branch is confirmed by real `git log`, not assumed.

Divergence from `main` (`git rev-list --left-right --count main...origin/<branch>`,
read as `<commits only on main> <commits only on branch>`):

| Branch | Only on main | Only on branch | Mergeability signal |
|---|---|---|---|
| `probe/ash-ai-dependency-retest` | 0 | 11 | Clean fast-forward candidate |
| `agent/connect-castle-paas-20260826` | 0 | 13 | Clean fast-forward candidate |
| `automation/claude-daily-drain` | 0 | 2 | Clean fast-forward candidate |
| `ggen/pin-manufacturing-instrument-v26.8.27` | 0 | 1 | Clean fast-forward candidate |
| `docs/refresh-agents-20260823` | 1 | 39 | Rebase needed (1 commit behind) |
| `feat/ash-project-measure-extension` | 27 | 57 | Diverged, real merge/rebase needed |
| `feat/ontology-reactor-closure` | 29 | 39 | Diverged, real merge/rebase needed |
| `ash-migration` | 0 | 156 | Already an ancestor of main (fully merged/stale) |

`probe/ash-ai-dependency-retest` vs `main` diffstat: 34 files changed,
1804 insertions(+), 56 deletions(-), concentrated in `test/xaas/**` (OCEL telemetry,
Ontop/R2RML semantics, ledger concurrency/tamper tests, AshAi tools test) plus
`templates-hooks/**` and `mix.lock`.

## 3. Explore — Options Implied by Branch Names

Competing/complementary workstreams identified, not yet merged into a single line:

1. **AshAi tool exposure now vs. after ash-migration completes.**
   `probe/ash-ai-dependency-retest` builds AshAi read tools directly against current
   `main`, while `ash-migration`'s own log ("Phases 0-7 execution + disclosed
   remaining work") signals it is an in-progress framework upgrade already an
   ancestor of `main` (0 unique commits) — i.e. it appears superseded/merged, not a
   live alternative. Option A: proceed with the probe branch as-is (fast). Option B:
   confirm ash-migration's disclosed remaining work has no undone step before
   trusting AshAi tool contracts (safer, slower).
2. **ggen manufacturing pin vs. marketplace lineage connection.**
   `ggen/pin-manufacturing-instrument-v26.8.27` (pins a local instrument) and
   `agent/connect-castle-paas-20260826` (fixes marketplace lineage preservation) both
   touch the ggen pipeline but from different angles — pinning a version vs. fixing
   provenance metadata. These are independent, non-conflicting (both 0 behind main)
   and can merge in either order.
3. **Ontology/semantics closure as prerequisite or parallel to AshAi tools.**
   `feat/ontology-reactor-closure`'s SPARQL/DfCM boundary work is diverged 29/39 from
   main — it predates several of `probe/ash-ai-dependency-retest`'s own semantics
   tests (`ontop_mapping_test.exs`, `registry_r2rml_mapping_test.exs`,
   `sparql_bridge_test.exs` all already appear in the probe branch's diffstat vs
   main). Option A: treat `feat/ontology-reactor-closure` as superseded by the probe
   branch's newer semantics tests and archive it after a real diff comparison.
   Option B: cherry-pick any DfCM boundary logic not already covered.
4. **Automation drain job timing.** `automation/claude-daily-drain` (CI backlog
   drain) has no dependency on the other branches and can land independently at any
   point in the sequence.
5. **Docs refresh vs. feature branches.** `docs/refresh-agents-20260823` is nearly
   merged (1 behind, 39 ahead — the 39 count likely reflects doc-only history not
   yet on main); low risk, can land early to unblock agent-contract references other
   branches may assume.

## 4. Develop — Concrete Next Steps per Branch

- **`probe/ash-ai-dependency-retest`** (priority: highest — real 24h activity,
  clean fast-forward): run `mix test` on the branch in isolation; confirm the new
  `test/xaas/operations_ash_ai_tools_test.exs`,
  `test/xaas/telemetry/ocel_beam4pm_compatibility_test.exs`, and
  `test/xaas/actuation_receipt_tamper_test.exs` pass against real collaborators (no
  mocked AshAi/OCEL calls, per Chicago-style testing discipline). Verify
  `mix.lock` diff introduces no unpinned/floating dependency.
- **`agent/connect-castle-paas-20260826`**: diff against
  `ggen/pin-manufacturing-instrument-v26.8.27` for file overlap in the ggen
  pipeline; if none, no rebase needed before merge. Re-run the marketplace lineage
  fix's own test coverage.
- **`ggen/pin-manufacturing-instrument-v26.8.27`**: single-commit pin; verify the
  pinned instrument version resolves and `mix ggen_igniter.sync` succeeds locally.
- **`automation/claude-daily-drain`**: verify the CI workflow YAML lints and the
  drain script runs in a dry-run mode before enabling on a schedule.
- **`docs/refresh-agents-20260823`**: rebase onto current `main` (1 commit behind),
  resolve any trivial conflict, no functional risk.
- **`feat/ash-project-measure-extension`** (27 behind / 57 ahead): rebase onto
  `main` is required; given the divergence size, do this in an isolated worktree
  and re-run the full measure-extension test suite post-rebase before considering
  merge.
- **`feat/ontology-reactor-closure`** (29 behind / 39 ahead): before rebasing,
  diff its SPARQL/DfCM tests against the equivalent tests already present on
  `probe/ash-ai-dependency-retest` to determine real overlap (see Explore item 3);
  only carry forward logic not already covered, to avoid duplicate/conflicting
  test files.
- **`ash-migration`** (0 ahead of main): confirm via `git branch --contains
  385206d main` that it is a true ancestor; if so, delete the stale remote branch
  after confirming no open PR references it (this plan does not delete it — flagged
  for a human/branch-hygiene follow-up only).

## 5. Implement — Merge Order, Gates, Rollout

### Merge order (sequential, one branch at a time on `main`)

1. `docs/refresh-agents-20260823` (lowest risk, unblocks contract references)
2. `ggen/pin-manufacturing-instrument-v26.8.27` (single commit, isolated)
3. `agent/connect-castle-paas-20260826` (ggen lineage fix, independent of #2)
4. `automation/claude-daily-drain` (independent CI job)
5. `probe/ash-ai-dependency-retest` (highest-value, most recently active; largest
   real test surface added)
6. `feat/ontology-reactor-closure` (after overlap diff against step 5's semantics
   tests; may shrink to a small cherry-pick or be dropped entirely)
7. `feat/ash-project-measure-extension` (largest divergence; last, so it rebases
   onto the most current `main`)

`ash-migration` is not in the merge order — Measure phase shows it is already an
ancestor of `main`; no action needed beyond the branch-hygiene follow-up noted above.

### Verification gates (per branch, before advancing to the next)

- Full `mix test` suite passes on the rebased/merged branch tip.
- `mix format --check-formatted` and `mix credo` (if configured) are clean.
- No `unittest.mock`/interaction-only test additions — Chicago-style discipline:
  real Ash resources, real OCEL emitters, real SPARQL queries against a running
  test instance, not mocked collaborators.
- `git diff --stat` reviewed by hand for each merge to confirm no unintended file
  overwrite (especially for the two ggen/marketplace branches touching shared
  `templates-hooks/**` files).
- After each merge to `main`, tag `main` at that commit before starting the next
  branch's rebase, so a bad merge can be isolated by bisecting between the current
  and prior tag (fix-forward per project git workflow — no `git reset --hard`).

### Rollout / monitoring after v26.9.1 lands

- Re-run `mix ggen_igniter.sync --for-each` (already proven on
  `probe/ash-ai-dependency-retest`) against the merged `main` to confirm N-way
  fan-out parity still holds post-merge.
- Monitor the `automation/claude-daily-drain` CI job's first scheduled run for
  failures once merged.
- Re-check OCEL/beam4pm compatibility (`ocel_beam4pm_compatibility_test.exs`) as a
  standing regression check, since it is the newest and most likely to interact
  with future ontology changes.
- File a branch-hygiene follow-up to delete `ash-migration` from origin once a
  human confirms no open PR depends on it.

## See Also

- `probe/ash-ai-dependency-retest` — richest recent commit history, primary source
  for this plan's Measure section
- `feat/ontology-reactor-closure` — semantics work whose overlap with the probe
  branch must be resolved before merge (Explore item 3)
