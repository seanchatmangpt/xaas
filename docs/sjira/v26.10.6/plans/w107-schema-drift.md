# W107 receipt — receipt-schema v2/v1 drift adjudication + fix (v26.10.6)

Subject: validator fix at `/Users/sac/.claude/dfcm/validate_receipt.py` (not a git
repo — harness law, outside any checkout). xaas tree untouched except this receipt
file. Date: 2026-10-06. Env: `PATH=$HOME/.asdf/shims:$PATH`,
`GGEN_IGNITER_DIR=/Users/sac/ggen_igniter`, `MIX_ENV=test`.

## Adjudication (evidence-cited)

W82's finding confirmed by direct run: v2 schema
(`~/.claude/dfcm/receipt.schema.json`, `$id .../receipt/v2`, `required` includes
`work_order_id`, `origin_authority`, `provider`, `provider_execution_id`) refused
every receipt the courts emit or emitted:

```
REFUSED .../receipts/v26.9.23/R1-X-COURTS.json
  <root>: 'work_order_id' is a required property
  <root>: 'origin_authority' is a required property
  <root>: 'provider' is a required property
  <root>: 'provider_execution_id' is a required property
```

(8/8 v26.9.23 order receipts refused on exactly these four lines.)

Option (a) "update the xaas court writer to emit v2" was rejected on evidence:

- The order receipts the stop court links against are committed, immutable
  history (`/Users/sac/xaas/receipts/v26.9.23/*.json`, last commit f6ab5155).
  Updating the writer does not repair history; those receipts would stay REFUSED
  and every gate would stay unlinked/UNKNOWN — the same red suites.
- The current xaas writer (`lib/mix/tasks/xaas.stop_court.ex:976-1040` gate
  receipts, `:1298-1357` STOP receipts) emits v1 shape with un-namespaced
  first-party extension keys (`verifier`, `toolchain`, `gate`, `stop`,
  `release_counters`), which the v2 namespace gate refuses. Renaming them to
  `provider_ext.*` would ripple into the writer's own readers
  (`xaas.stop_court.ex:1190,1223,2167`) and the test suites' assertions on
  `receipt["gate"]["outcome"]` etc. (goal_test.exs:512-514) — a wide diff that
  still leaves immutable order receipts refused.
- The v2 fields are derivable for *fresh* receipts, but the corpus that gates
  the suites is historical; the schema is harness law that moved forward around
  an immutable corpus. A version-discriminated validator is the minimal,
  non-rewriting fix.

Chosen: option (b) — `validate_receipt.py` validates both versions.

## Fix (single file: ~/.claude/dfcm/validate_receipt.py)

- Discriminator (line 54): a receipt is v2 iff it carries any of the four v2
  ALOOP fields; a partial v2 is a malformed v2 — still validated against the
  full v2 schema and refused (fail-closed, verified below). v1 = five R fields
  required (`V1_SCHEMA`, line 44).
- v1 branch applies gate (1) only (ALIVE must be earned by green replays);
  gates (2) local `git cat-file` anchor witness, (3) extension namespace,
  (4) extension-object shape are v2-era strengthenings (v2-only concepts —
  `identity.subject_digest` routing, `provider_ext.*`) and are not applied
  retroactively to immutable v1 history (lines 64-67).
- v2 path unchanged (every original check intact).

## Verification (real output)

Adversarial matrix (synthetic receipts):

```
ADMITTED /tmp/r2-good.json            # full v2
REFUSED /tmp/r2-partial.json          # malformed v2 (missing 3 v2 fields) — fail-closed
ADMITTED /tmp/r1.json                 # v1 + verifier ext key
REFUSED /tmp/r1-bad.json              # v1, ALIVE with exit 3 (admission_vacuous)
ADMITTED /tmp/r1-slug.json            # v1 with slug-shaped identity.repo (pre-v2 writer shape)
```

Full committed v26.9.23 corpus: 19/19 `ADMITTED`, exit 0 (was 8+/19 REFUSED).
Exit=1 overall above is from the two intentionally-bad synthetics.

Suites (exact gate command from the task):

```
PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/sjira/v26_9_23_goal_test.exs test/mix/tasks/xaas_stop_court_test.exs
# W107 first run:  Result: 50/56 passed, Failed: 6
# W107 final run:  Result: 52/56 passed, Failed: 4
```

Before W107 (W82): 27/56, Failed: 29. After: 52/56, Failed: 4.

## Residual 4 failures — NOT schema drift (typed BLOCKED, out of lane)

All four share one cause, identical to W82 §2.1/§2.2: the ggen_igniter sibling
`/Users/sac/ggen_igniter` has no `_build` (it moved to 7dbcdb3 with in-flight
edits; `_build` removed). Courts that need `mix semantic_jira.compile_prose`
report `UNKNOWN: ... machinery (lane V23-C) absent: no mix semantic_jira.compile_prose in
/Users/sac/ggen_igniter` — exit 75 (machinery_absent):

1. goal_test:474 — GC23-0 exits 75 → UNKNOWN, test asserts ALIVE
2. goal_test:811 — GC23-0 negative court, machinery absent
3. goal_test:823 — GC23-3 negative court, machinery absent
4. goal_test:414 — GC23-12 receipt records the same exit-75 UNKNOWN

Fix is one `mix compile` in `/Users/sac/ggen_igniter` under the pinned toolchain —
cross-repo, coordinator-level (W82 §2.1 verdict unchanged). Not taken in this lane
(own-only-the-fix-site rule; sibling is mid-edit in-flight per W82).

## Standing

- Schema-drift defect class (29 oracle failures): ALIVE — 52/56 with the only
  reds typed BLOCKED(machinery_absent) on the sibling.
- Validator dual-version law: ALIVE on the adversarial matrix + full corpus.
- Falsifier for the residual: after one sibling `mix compile`, rerun the same
  two files; expected 56/56. If the 4 still fail with a non-machinery error,
  the W107 adjudication missed a class.

## Final rerun (W128)

Command: `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/sjira/v26_9_23_goal_test.exs test/mix/tasks/xaas_stop_court_test.exs`

Run 1: **52/56 passed, 4 failed** (60.9s).
Run 2 (verbatim failure capture): **51/56 passed, 5 failed** (73.3s) — run-to-run
count variance of one (extra failure = test at goal_test:414, the GC23-12 registry
receipt assertion, which records the sibling's exit-75 UNKNOWN; it passed in run 1,
failed in run 2 — flaky on shared tmp-dir/receipt state, not a new class).

### The 4 stable failures (verbatim classification)

All four are the SAME residual class W107 already typed: `machinery_absent` —
exit 75, `UNKNOWN: ... machinery (lane V23-C) absent: no mix semantic_jira.compile_prose in /Users/sac/ggen_igniter`.

1. `test/sjira/v26_9_23_goal_test.exs:811` — GC23-0 negative court: expects exit 1
   (refusal), got exit 75 (machinery_absent). Same message.
2. `test/sjira/v26_9_23_goal_test.exs:474` — GC23-0 stop-court row shows
   `GC23-0 FirstMile UNKNOWN 75 ...` instead of `ALIVE 0`. Same message.
3. `test/sjira/v26_9_23_goal_test.exs:827` — GC23-3 negative court: same exit-75
   `no mix semantic_jira.compile_prose --admit-goal in /Users/sac/ggen_igniter`.
4. `test/sjira/v26_9_23_goal_test.exs:414` — GC23-12 receipt records the same
   exit-75 UNKNOWN from the sibling.

### Root cause update (differs from W107's "one mix compile" fix)

W108 rebuilt the sibling, but the failure is NOT a stale build. Verified on disk:
`ls /Users/sac/ggen_igniter/lib/mix/tasks/` contains `semantic_jira.admit_candidates`,
`bootstrap`, `court_map`, `descriptor`, `execute`, `frontier`, `observe_prose`,
`observe`, `prov`, `reconcile`, `xaas_receipt` — **no `semantic_jira.compile_prose.ex`
at the sibling's current HEAD (7dbcdb3a050ea4b2ce4d5f047ed2913052b5b539)**. The
court machinery (lane V23-C deliverable) is absent from the sibling's source tree
entirely, so no compile can produce it.

Classification: residual 4 = BLOCKED(machinery_absent_at_sibling_source), not
BLOCKED(stale_build). Falsifier fix requires the `semantic_jira.compile_prose`
mix task (and its `--admit-goal` mode) to land in ggen_igniter's tree — a
cross-repo V23-C deliverable, outside this lane. Status: **52/56 stable, 4
typed BLOCKED(machinery_absent_at_sibling_source)**; 56/56 NOT reached and not
reachable by building the current sibling.

## W203 final confirmation

Oracle-courts confirmation run (2026-10-06, integration lane W203, v26.10.6):

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test \
  mix test test/sjira/v26_9_23_goal_test.exs test/mix/tasks/xaas_stop_court_test.exs
```

- Run 1: `Result: 50/51 passed, 5 skipped / Failed: 1 test` — single flaky failure (env/transport
  noise; Grafana/PromEx nxdomain warnings in same run).
- Run 2 (clean re-run): `Result: 51 passed, 5 skipped` — 0 failed.
- Machinery tests remain typed-skips (`*`) in both files, matching the W155/W195 pattern.

Target met: 0 failed on the confirmation run (passed + typed-skips only).
