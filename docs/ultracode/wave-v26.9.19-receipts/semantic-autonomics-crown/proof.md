# Semantic autonomics crown — receipts as the clock (live proof)

**Date:** 2026-09-21 (run window 00:07:41Z–00:27:50Z, 20m09s).
**Subject:** `seanchatmangpt/agile-protocol-specification` @ `5c31d9d05fe36dc1eca3a26c9eb5cd267a2cf625`.
**XaaS:** branch `feat/semantic-autonomics-crown`, stacked on xaas#56 `4812714`.
**Graph side:** `ggen_igniter` `feat/semantic-jira-descriptor-bridge` @ `92cd993`
(on `feat/semantic-jira-receipt-reconciler` @ `34a6e6e`).

## Standing

**ALIVE for one narrow claim:** with no ticket edited and no human input after the trigger
(`mix xaas.semantic.crown --ggen-igniter-dir … --live --controls`), a verified receipt moved the
canonical work graph, and the moved graph — not a person — made the next work order eligible:

1. an observed repository condition became a SHACL-admitted candidate WorkOrder (`SJ-CROWN-A`);
2. the frontier projected it as an XaaS descriptor; XaaS materialized a Run/Epoch/worktree;
3. a real `zai/glm-5.3-flash` worker leased exactly that Epoch and committed a test file;
4. the `aps-dod` court, run by the fabric, sealed it `alive`;
5. the sealed receipt was exported, mapped, and reconciled into an append-only ledger event (seq 1);
6. `SJ-CROWN-B` (depends on `SJ-CROWN-A`'s receipt) became eligible *only then*; its first live
   attempt was **refused** (organic failure, see below), its second passed (seq 2);
7. the final state was replayed from the ledger + work orders alone, in a fresh OS process and a
   fresh directory, and matched.

It is **not** a proof of open-ended or long-horizon autonomy (see Non-claims).

## What ran

| Step | Component | Evidence |
|---|---|---|
| Observe | `aps_backlog.py` at the exact APS sha → `finding.json`; `mix semantic_jira.observe` | `seed/finding.json`, `seed/candidate.json`; SHACL conforms, 113 focus nodes, 9 shapes |
| Admit | kernel `admit_work_order` + SHACL over the canonical ontology (+2 nodes, see Non-claims) | `crown-events.ndjson` (`observed`) |
| Frontier | `mix semantic_jira.frontier` | only `SJ-CROWN-A` eligible at start; `SJ-CROWN-B` blocked on its receipt |
| Descriptor | `mix semantic_jira.descriptor` (exact `SemanticWork.admit/1` key set + `bridge`) | `attempts/*/descriptor.json` |
| Materialize | `SemanticWork.materialize/2`; `bridge` stored opaque on the Run (`semantic_bridge`) | Run rows in Postgres |
| Execute | hardened dispatcher `--epoch` → `gall-work --lease` → headless zcode `/xaas` prompt, gated (`XAAS_WORKER=1`) | executors below |
| Seal | `Lease.close/4` → `Xaas.Ultracode.Verifier` → `aps_dod_court.py` (fabric, not worker) | `court-receipts/*.json` |
| Export | `Xaas.Ultracode.SemanticReceipt.export/1` (+ `ApsDod` adapter) | `attempts/*/xaas-receipt.json` |
| Map + reconcile | `mix semantic_jira.xaas_receipt`, `mix semantic_jira.reconcile` | `attempts/*/reconciler-receipt.json`, `standing-ledger.ndjson` |
| Replay | `mix semantic_jira.frontier` on a copy of ledger + work orders | `crown-report.json` (`replay.equal: true`) |

Timeline (`crown-events.ndjson`, UTC): sensed 00:07:41 · observed 00:07:44 · A materialized 00:08:01 ·
A worker returned 00:13:03 (5m02s) · A transition 00:13:05 · B attempt 1 materialized 00:13:07 ·
B worker returned 00:19:01 · B attempt 1 refused 00:19:18 · B attempt 2 materialized 00:19:23 ·
B worker returned 00:27:29 · B transition 00:27:32 · report 00:27:50.

## Independent verification (not the crown's own report)

Read back after the run from Postgres, git and APS's own tools:

| Epoch | Work order | State | Executor (`leased_to`) | Final head | Sealed outcome | Fabric verifier | `head_verified` |
|---|---|---|---|---|---|---|---|
| `b832b89a` | SJ-CROWN-A | completed | `zcode-dispatch-Mac-b832b89a-91445` | `e34c526fff6d…` | alive | pass | true |
| `47d8f82c` | SJ-CROWN-B attempt 1 | completed | `zcode-dispatch-Mac-47d8f82c-7725` | `1396ff2d4bcb…` | **build_broken** | fail | true |
| `072770fe` | SJ-CROWN-B attempt 2 | completed | `zcode-dispatch-Mac-072770fe-17511` | `f3afb9facab8…` | alive | pass | true |

- Three distinct worker ids, each leased exactly its own epoch (directed claim).
- In the two kept worktrees: `git rev-parse HEAD` equals the sealed final head; tree clean; the diff
  against the APS base is exactly one new file each (`tests/test_contract_standing.py`,
  `tests/test_contract_evidence_receipt.py`); `python3 -m unittest discover -s tests`: A **10 tests OK**,
  B **13 tests OK**; mock grep over the changed files: **0 matches**.
- Ledger: 2 events, chain `event_digest` verified by a fresh `mix semantic_jira.frontier` on a copy:
  standings `{A: ALIVE, B: ALIVE}`, tail `sha256:5d7f2109b1e1628e…`, eligible `[]`.
- B's descriptor carries A's ledger receipt digest as its dependency
  (`attempts/SJ-CROWN-B-*/descriptor.json`).
- The operator APS clone was not pushed to; nothing was pushed to APS.

## Falsifiers (live)

1. **Organic refusal.** `SJ-CROWN-B` attempt 1: the GLM worker committed a test module that did not
   run (`unittest.loader._FailedTest.test_contract_evidence_receipt`). The court sealed `build_broken`
   (`CHI-CANONICAL`, `CHI-MUTATION` failed); the exported receipt mapped to target `BUILD_BROKEN` with
   the court result `passed: false`, every acceptance result false and the falsifier `unobserved`;
   `reconcile` refused
   `promotion_refused [courts, evidence, acceptance, falsifiers, receipts]`; the ledger did not move; the
   crown re-materialized and attempt 2 passed. (`court-receipts/B-attempt1-refused.json`,
   `worker-tests/SJ-CROWN-B.attempt1-refused…py`, `attempts/SJ-CROWN-B-1-0/`.)
2. **Crafted control over the real HTTP MCP surface** (`--controls`): a vacuous-test candidate claimed
   `alive` against the running server on :4000. Sealed `build_broken`, failed gates `CHI-ASSERT` +
   `CHI-MUTATION`; mapping succeeded (exit 0), `reconcile` refused (exit 1, same
   `promotion_refused` list); fresh ledger stayed at 0 events; `SJ-CROWN-A` stayed on the frontier.
   (`control/`, `court-receipts/control-refused.json`, `crown-report.json` → `controls`.)
3. **Tampering.** One field of the first ledger event changed in a copy → `mix semantic_jira.frontier`
   exits refusing `["ledger_invalid", ["event_digest_mismatch", 1]]`.

## Mutation-checked machinery

Each of these turned the Chicago tests red and was restored byte-identical (`cmp`): the `ApsDod`
adapter reporting acceptance without the gate verdicts (2 red); the court alias always reporting
`pass` (1 red); the exporter always claiming `alive` (1 red in `semantic_receipt_test`, and the crown
test red).

## Defects found on the way (all fixed forward on this branch unless noted)

- The first live launch failed within 2 s: the CLI checkout with a runtime (main `1aceb47`) has no
  `gall-work` command (it exists only in zcode-cli PR #3, `Unknown option '--lease'`); the run then used
  `shim/zcode.js` (see Non-claims).
- `scripts/xaas-glm-failover-dispatcher.sh` wrote the semantic lease file with a literal `\n`
  (`"\\n"` inside the single-quoted `node -e`), so `gall-work --lease` could never parse it; the second
  live launch failed within 3 s on that. Fixed to `"\n"` on this branch.
- The five `semantic_work`/`semantic_wave` tests already failed on the base (no `Xaas.Repo` sandbox
  checkout); they now check it out.
- The graph-side SHACL shape requires every `sj:requiresCourt` / `sj:requiresEvidence` to be an
  absolute IRI typed in the graph; the crown therefore admits against a work copy of the canonical
  ontology that carries two extra nodes (`sj:court-aps-dod`, `sj:aps-dod-court-receipt-evidence`).
- A `System.cmd` on a graph-side `mix` process hung indefinitely (no live child, nothing to
  reap); graph-side calls now write to a file, close stdin and run under a perl `alarm` deadline.
- Not fixed here: `SJ-CROWN-B`'s retry re-runs the identical descriptor, so the refusal reason is not
  fed back to the worker (the ticket `history` is, the goal text is not).

## Gates

`mix format --check-formatted` exit 0; `mix compile --warnings-as-errors` exit 0 (test and dev);
`test/xaas/ultracode` + `test/xaas/zcode_plugin`: 175 passed by default (15 subprocess-tagged excluded), and
180 passed with `--include subprocess` (10 excluded by other tags), exit 0; new tests: `semantic_receipt_test` 14, `semantic_crown_test` 1 (real `mix semantic_jira.*`
processes, real APS clone, real court, scripted protocol worker replaying the tests recorded in
`aps-autonomic-3e46cf.bundle`). Mock grep over the new tests: 0 matches.

## Reproduce

```bash
cd /path/to/xaas && git checkout feat/semantic-autonomics-crown
MIX_ENV=dev mix ecto.migrate            # additive: ultracode_runs.semantic_bridge
export INTERNAL_API_TOKEN=…             # from the plugin user config; never committed
ZCODE_CLI_DIR=/path/with/gall-work \
MIX_ENV=dev mix xaas.semantic.crown --ggen-igniter-dir /path/to/ggen_igniter --live --controls
```

Prerequisites: the XaaS dev server on the same database with the `aps-dod` suite registered, the
plugin installed from `priv/zcode_plugin/marketplace`, a local APS clone at `~/xaas-worktrees/repos/aps`,
and a ggen_igniter checkout carrying `semantic_jira.{observe,descriptor,xaas_receipt,reconcile,frontier}`.

## Non-claims

- One repository, one model, one bounded family (add Chicago tests for an APS contract schema). It
  shows the loop closes with receipts as the clock; it does not show generalization or open-ended
  autonomy.
- `SJ-CROWN-A` was observed and SHACL-admitted; `SJ-CROWN-B` was **seeded by the crown** and only
  kernel-admitted, its dependency edge is not in the SHACL graph.
- The two ontology nodes above exist only in the work copy of the canonical ontology; they are not in
  `ggen_igniter`'s repository ontology, and the ggen_igniter branches are unmerged.
- The live worker ran the `gall-work --lease` branch of the dispatcher through
  `shim/zcode.js`, which builds the same invocation `src/gall-work.ts` (zcode-cli PR #3) builds and
  runs it through the real CLI (`zcode-app-cli 3.12.3-26`, main `1aceb47`, runtime `0.16.5`). PR #3 is
  not merged into a checkout that has a runtime; the shim is a stand-in, not the PR.
- Standing is fabric-only evidence (ceiling `repository-local`): no hosted CI, no release identity, no
  independent second verifier beyond the court; not a production or reference-implementation claim.
- The running server on :4000 belongs to another session and runs that session's code; the crown
  node ran this branch's code against the same database. Interaction with that server's own 30-minute
  wave was not observed either way.
- The ledger hash chain detects edits, reordering and removal of non-final events; it does not detect
  tail truncation or a consistent full rewrite, and it is not a signature.
- `human_inputs: 0` is structural (no code path reads input) plus the single trigger, not an audit of
  the operator's machine. One Z.AI `1302` rate-limit response occurred during B attempt 1 and the
  worker recovered.
- The shared dev database received one additive nullable column (`ultracode_runs.semantic_bridge`).

## Files

`crown-report.json`, `crown-events.ndjson`, `standing-ledger.ndjson`, `work-orders.json`, `seed/`,
`attempts/`, `control/`, `court-receipts/`, `worker-tests/`, `shim/zcode.js`.
