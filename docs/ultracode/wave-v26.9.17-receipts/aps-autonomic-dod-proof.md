# APS autonomic Chicago-TDD definition of done — live proof

**Date:** 2026-09-18. **Subject:** `seanchatmangpt/agile-protocol-specification`
@ `5c31d9d05fe36dc1eca3a26c9eb5cd267a2cf625`.

## Standing

**ALIVE for one narrow claim:** a closed loop, triggered by one command, took a backlog
derived from the repository itself to an integration branch whose canonical gates pass,
with six concurrent `zai/glm-5.3-flash` workers doing the construction and the XaaS
fabric — not the workers — deciding done. No human input occurred between the trigger
(`2026-09-18T22:12:18Z`, `mix xaas.autonomic.run --repo aps --capacity 6`) and the
terminal receipt (`22:20:10Z`, 7m49s).

It is **not** a proof of open-ended or long-horizon autonomy (see Non-claims).

## What ran

| Stage | Component | Evidence |
|---|---|---|
| Sense | `priv/verifiers/aps_backlog.py` at exact sha, in a throwaway worktree | 6 items (one per `contracts/*.schema.json` with < 3 negative fixtures), byte-identical on repeat |
| Plan | `Xaas.Ultracode.Autonomic` | 6 provisioned worktrees, 6 tickets outside the worktree, 6 Runs + Epochs |
| Act | hardened dispatcher, directed `--epoch` mode, gated headless zcode | 6 distinct workers, each claimed exactly its own epoch |
| Verify | `Lease.close/4` → `Xaas.Ultracode.Verifier` → `aps_dod_court.py` | every close sealed by the fabric with `evidence.fabric_verifier` |
| Repair | ticket history + attempt n+1 | not exercised by the live GLM run (all 6 passed first try); exercised by tests and controls |
| Promote | serial `--no-ff` merges into `aps-autonomic-3e46cf` | 6 merge commits, 0 conflicts |
| Verify again | canonical suite at the integration head | verify, unittest, ggen static, mdbook, simulate: all pass |
| Learn | ndjson ledger + terminal receipt | 34 events (`loop-ledger.ndjson`) |

## Independent verification (not the loop's own report)

Postgres, git and APS's own tools, queried after the run:

| Item | Epoch | Worker id | Receipt outcome | Fabric verifier | Court standing |
|---|---|---|---|---|---|
| contract-actuation-intent | completed | `zcode-dispatch-Mac-e41e65bf-…` | alive | pass | ALIVE |
| contract-evidence-receipt | completed | `zcode-dispatch-Mac-0a270c05-…` | alive | pass | ALIVE |
| contract-knowledge-contract | completed | `zcode-dispatch-Mac-7e34ae0a-…` | alive | pass | ALIVE |
| contract-process-event | completed | `zcode-dispatch-Mac-c8bd2bc0-…` | alive | pass | ALIVE |
| contract-reconstitution | completed | `zcode-dispatch-Mac-1e440bae-…` | alive | pass | ALIVE |
| contract-standing | completed | `zcode-dispatch-Mac-ed0fcb0f-…` | alive | pass | ALIVE |

- Six distinct `leased_to` values; every `head_verified` is `true`.
- A fresh re-run by hand at integration head `1d485ed`: `verify.py` exit 0; `unittest
  discover -s tests -v` **65 tests OK** (baseline: 4); `verify_ggen_ecosystem.py` exit 0;
  `mdbook build -d <tmp>` exit 0; `simulate_fortune500.py` exit 0; `git status` clean.
- Mock grep over the integration `tests/` and `tools/`
  (`unittest.mock|Mock(|MagicMock|patch(|monkeypatch|mocker|import mock`): **zero matches**.
- Each court receipt re-validated by hand against the base tree's
  `contracts/evidence-receipt.schema.json` (jsonschema 4.23.0): **6/6 valid**; every one has
  7/7 gates passing (EXACT-HEAD, INDEPENDENT, SCOPE, MOCK, ASSERT, CANONICAL, MUTATION),
  mutant kill ratio 1.0, 5–13 new tests, and `executorRef` ≠ `verifier.identity`.
- Host gate (PreToolUse) logs per worker: 13–21 decisions each, exactly one `Write`, the
  rest `Read` and allowlisted `git`; the gate denied command chaining/redirection and
  `grep` (1–3 denials per worker) and the workers adapted.
- The operator APS clone is still at `5c31d9d` with a clean tree; nothing was pushed.

## Falsifiers: the court rejects bad work (live, over HTTP MCP)

`mix xaas.autonomic.controls` closes crafted candidates through the real HTTP MCP surface,
each claiming `alive`; the fabric sealed:

| Control | Sealed result | Typed reason |
|---|---|---|
| positive (good tests) | alive, verifier pass, court ALIVE | — |
| vacuous tests | build_broken | CHI-ASSERT (+ CHI-MUTATION) |
| `from unittest import mock` | build_broken | CHI-MOCK |
| edit to `contracts/standing.schema.json` | build_broken | CHI-SCOPE |
| extra file outside allowed paths | build_broken | CHI-SCOPE |
| tests that never assert ALIVE is accepted | build_broken | CHI-MUTATION (mutant survives) |
| uncommitted work | build_broken | `worker_left_uncommitted_changes` |
| claimed head ≠ worktree HEAD | build_broken | `head_verified: false` |

Report: `negative-controls.json`.

## Mutation-checked machinery

Each of these breakages turned the matching Chicago suite red and was restored
byte-identical: the verifier's spoof strip, fail-downgrade, containment, group kill and env
clearing; the controller's court check, repair history, merge, reaping and standing; the
gate's containment and `.git` rule; the projection drift test. Two real bugs were caught by
the tests during development (status aggregation compared atoms to strings; `Port.close` on a
closed port).

## Reproduce

```bash
cd /Users/sac/xaas
INTERNAL_API_TOKEN=... MIX_ENV=dev mix xaas.autonomic.controls      # falsifiers first
INTERNAL_API_TOKEN=... MIX_ENV=dev mix xaas.autonomic.run --repo aps --capacity 6
```

Prerequisites: the dev server on the current code, the plugin installed from
`priv/zcode_plugin/marketplace`, a local APS clone at `~/xaas-worktrees/repos/aps`, and the
`aps-dod` and `aps-canonical` suites in `config/dev.exs`.

## Files

- `loop-receipt.json`, `loop-ledger.ndjson` — the loop's terminal receipt and action log.
- `negative-controls.json` — the falsifier run.
- `aps-autonomic-3e46cf.bundle` — the integration branch as a git bundle over `5c31d9d`
  (`git fetch <bundle> aps-autonomic-3e46cf`); 12 commits, 6 new test files.

## Non-claims

- One repository, one model, one bounded backlog family (negative-fixture + mutation-kill
  tests per contract schema). This shows the loop closes; it does not show open-ended
  autonomy or generalization to arbitrary tasks.
- The live run did not need repair: all six passed on attempt 1. The repair, reaping,
  rate-limit and blocked paths are proven with a scripted protocol client and with the
  falsifier controls, not with organic GLM failures.
- Determinism was not measured across repeated live GLM runs.
- The verifier is a fenced runner, not an OS sandbox; candidate code executes with an env
  allowlist and a containment root only. Linux and the CI-pinned tool versions were not
  tested (local pyshacl 0.31 / mdbook 0.4.52 vs CI 0.40.1 / 0.5.4).
- ZCode subagent tool calls bypass the PreToolUse gate, so the gate denies `Agent`; subagents
  are therefore not part of this proof, and "done" is decided by the fabric alone.
- `human_inputs: 0` is structural (no code path reads input) plus the single trigger; it is
  not an audit of the operator's machine.
- The APS GitHub repository was never modified or pushed to.
