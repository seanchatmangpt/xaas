# W139 — E4 adjudication receipt (9 real regressions, w68b-full-suite)

- Lane: W139 integration, v26.10.6 convergence, repo /Users/sac/xaas (canonical checkout).
- Input: `docs/sjira/v26.10.6/plans/w68b-full-suite.md` E4 (failures 17–25), `/tmp/w68b_failures.log`.
- Lane rule held: test files + unsealed local fixtures only; zero lib edits; zero git state
  transitions (only read-only `git diff`/`status` to review my own diff).

## Root cause (single law, three surfaces)

`ggen_igniter` kernel head (`~/ggen_igniter` @ 7dbcdb3, AC-04 law) makes `origin_authority`
a required field of `admit_work_order/1` (`@required`,
`lib/ggen_igniter/semantic_jira.ex:29`), plus an IRI-shape check
(`invalid_origin_authority`). Pre-AC-04 work-order fixtures lawfully refuse with
`{:refused_work_order, {:missing_required_field, "origin_authority"}}`.

## Per-failure verdicts

### 17–23 — Xaas.Ultracode.SemanticReplayTest + SemanticCrownReplayTest — AC-04 law drift vs FROZEN corpus

- Reproduced: `mix semantic_jira.reconcile` against the frozen
  `docs/sjira/v26.9.23/episodes/fmt-1/work.json` returns
  `{"reason":["refused",["refused_work_order",["missing_required_field","origin_authority"]]],"status":"refused"}`
  (verified by manual run, 13:47 PDT).
- Class: **AC-04-law-drift, typed refusal is LAWFUL**. The fmt-1 episode is a frozen
  corpus (`docs/sjira/v26.9.23/FROZEN-CORPUS.md`: read-only evidence, no in-place
  edits; "Replay requires regeneration through the current pipeline, not in-place
  edits"). In-place fixture migration prohibited.
- Fix: **pin the typed refusal** (W116 pattern). Adjudicated and applied by the
  concurrent W116 lane in `test/xaas/ultracode/semantic_replay_test.exs` (mtime
  2026-10-06 13:52:11, +72/−68, "W116 adjudication" comments naming ggen_igniter
  23c36c8). 17–20 assert the typed DIVERGED/divergence records; 21 pins
  `code == 1` + `"status":"refused"` + `origin_authority` + no ledger dir; 22 pins
  the non-equal empty-log replay; 23 pins the exact typed
  `{:frontier_failed, 1, ["ledger_refused", ["event_digest_mismatch", 1]]}`.
- Rerun: after the W116 edit landed I ran the three CrownReplay locations together:
  **3 passed** (`/tmp/crown3.log`). Full-file certification run launched 13:59 PDT
  (log `/tmp/full-replay.log`). Full-file rerun of `semantic_replay_test.exs`
  with the W116 pins: **13/13 passed** (171.1 s, exit 0, this session).
- Not a genuinely-new defect: no xaas lib change is warranted; the frozen corpus
  regeneration remains an open regeneration work order (freeze-and-annotate), not
  this lane.

### 24 — Mix.Tasks.Xaas.StopCourtTest gate-receipt binding — already fixed upstream of this lane

- Reproduce attempt `mix test test/mix/tasks/xaas_stop_court_test.exs:696`: **passed**
  (1 passed, 18 excluded, 2.6 s).
- Class: resolved before this lane by the W107 validator convergence
  (`~/.claude/dfcm/validate_receipt.py` v1/v2 discrimination: receipts with no v2
  ALOOP fields validate under the v1 subschema). The fixture court receipts are v1,
  so they admit. No test-side change needed.
- Rerun full file: **19/19 passed**.

### 25 — Xaas.Ultracode.SemanticJiraE2ETest — AC-04 law drift vs UNSEALED generator-owned fixture — FIXED by this lane

- Reproduced narrowly at the exact failing hop (no test run needed for the diagnosis):
  ran the real producer `docs/sjira/v26.9.21/e2e_project.exs` in `~/ggen_igniter`
  (elixir 1.19.5-otp-27 per its `.tool-versions`) over the committed SJ-001 order:
  `{"ok":false,"stage":"admit","reason":"{:refused_work_order, {:missing_required_field, \"origin_authority\"}}"}`.
- Class: **AC-04-law-drift; the v26.9.21 sJira dir is unsealed and generator-owned**
  (README: `generate.py` + `admit.exs` = the regeneration protocol; FROZEN marker
  absent). Fix = add the pinned origin_authority to the generator and regenerate
  through the real producer:
  1. `docs/sjira/v26.9.21/generate.py`: added `ORIGIN_AUTHORITY`
     (`https://ggen-igniter.dev/ontology/semantic-jira#objective-code-work-authority`,
     the pinned `sj:AuthorityTrustRoot` objective used by ggen_igniter's own
     reconciler test) as the default `origin_authority` of `wo()`.
  2. Regenerated the 12 order files (001–012) via `SJIRA_OUT=<tmp> python3 generate.py`
     and copied over — each diff is exactly the one added `origin_authority` line
     (000/013/index.json byte-identical, verified via git status).
  3. Regenerated the committed descriptor fixture
     `test/fixtures/semantic_work/sj-001-descriptor.json` via the real producer
     script (`mix run --no-start scripts/sj001_descriptor_fixture.exs`,
     `ok:true`, work_order_digest `sha256:04be3224…`): the descriptor delta is
     exactly `origin_authority`/`origin_observation`/`target_pack` plus the three
     derived digests; `requires`/courts/acceptance/falsifiers unchanged.
- Rerun: `mix test test/xaas/ultracode/semantic_jira_e2e_test.exs:115` →
  **1 passed** (242.7 s; real admit → materialize → receipt → replay plus both
  falsifier controls, real `mix compile` of the exact-head worktree).
- Sibling certification (descriptor-fixture consumers):
  `semantic_work_test.exs + semantic_work_falsifier_test.exs + order_probes_test.exs`
  → **41 passed**.

## Standing

- 17–23: ALIVE-as-pins — typed-refusal pins by the concurrent W116 lane; full-file
  rerun of `semantic_replay_test.exs` observed 13/13 passed (171.1 s, exit 0).
- 24: ALIVE (pre-existing fix; verified this session).
- 25: ALIVE — fixed by this lane (generator + orders + descriptor fixture
  regenerated through the real producers), e2e observed passing at the exact subject.
- Frozen fmt-1 corpus regeneration under the current AC-04 pipeline: not done here
  (out of lane; frozen corpus) — remains the open follow-up behind the 17–23 pins.
- Full-file reruns (this session, warm `_build/test`): stop_court 19/19;
  semantic_jira_e2e 1/1; descriptor-fixture siblings 41/41; crown-replay trio 3/3.
- Contention note: a `mix xaas.replay` subprocess inside SemanticReplayTest
  recompiles into the shared `_build/test`, which can transiently swap beams under
  the running test node ("module X is not available" UndefinedFunctionError for
  modules that exist and compile clean standalone). Same contention-flake family as
  W68b E6-4/5; do not re-diagnose as law drift.

## W285 E2E confirm

- 2026-10-06T21:49:55Z, integration lane W285, subject d1db2b03179975213c14663b9dbd86b5ac2a14cf
  (feat/playwright-surface, working tree).
- Command: `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test
  mix test test/xaas/sjira --include subprocess`
  → run 1: 94/107 passed, 13 failed; run 2 (no tree change): **107/107 passed** (10.7 s, exit 0).
  Run-1 failures are the documented contention-flake family above (concurrent
  `_build/test` recompile swapping beams under a running node); unchanged failure
  was not re-diagnosed, rerun on the same subject cleared all 13.
- SJ-001 E2E itself (not under `test/xaas/sjira`; not tagged `:subprocess`):
  `mix test test/xaas/ultracode/semantic_jira_e2e_test.exs`
  → **1/1 passed** (216.7 s sync, exit 0), including both falsifier refusals and
  the admit -> materialize -> receipt -> replay flow, under the current tree.
- W139 subprocess-tagged court confirmed ALIVE under the current tree; no fixes, no git.
