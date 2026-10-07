# W227 — ultracode dir verification receipt (v26.10.6 convergence)

- Repo: /Users/sac/xaas (branch feat/playwright-surface, working tree as found)
- Lane: integration lane W227, combined ultracode-dir verification
- Env: `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test`
- Command: `mix test test/xaas/ultracode`
- No fixes, no git operations.

## Runs

| run | scope | result |
|---|---|---|
| 1 | full dir | 1402/1405 passed (6/6 doctests, 1396/1399 tests), 5 invalid, 27 excluded — Failed: 3 (output truncated, names not captured) |
| 2 | full dir (rerun) | CRASHED pre-test: build-dir lock contention (PIDs 28548/28126/29801) → `Postgrex.Error 42701 duplicate_column "spg_graph_id" on actuation_intents` during test-DB migration race. Not a test failure. |
| 3 | full dir (rerun) | KILLED at 600s SIGKILL (exit 137) — harness timeout, not a test result. |
| 4 | full dir, 2h timeout, full log | Finished in 1131.4s. **1407/1411 passed (6/6 doctests, 1401/1405 tests), 27 excluded. Failed: 4** — `/tmp/w227-run4.log` |
| 5 | isolation rerun of the 4 failures | **1/5 passed, 4 failed — all 4 reproduce in isolation.** Genuine, not contention-flaky. `/tmp/w227-run5.log` |

Run 4 is the receipt-bearing run (full log on disk). Note run 1 vs run 4 count drift
(1411 vs 1405 tests) reflects the 5-invalid/6-doctest accounting and possibly drift between
runs; run 4's verbatim line is authoritative for this receipt.

## Verbatim summary (run 4)

```
Finished in 1131.4 seconds (72.3s async, 1059.1s sync)

Result: 1407/1411 passed (6/6 doctests, 1401/1405 tests), 27 excluded
Failed: 4 tests
```

## Failure classification (all 4 reproduce in isolation — none contention-flaky)

1. `test/xaas/ultracode/semantic_drive_test.exs:113` — SemanticDriveTest "a prepared episode
   drives EP-A to ALIVE..." — expected `{:ok, summary}`, got
   `{:refused, ..., reason: "fabric_court_build_broken", standing: BUILD_BROKEN}`.
   Fabric court's `mix format --check-formatted` fails on the sandbox gall checkout of
   ggen_igniter (`~/.cache/tmp/xaas-drive-drive-runs-*/gall-ggen_igniter-*/lib/ggen_igniter/semantic_jira/execute.ex`):
   line 134 `hop("frontier", Reconciler.frontier(...))` kept on one line, formatter wants it
   split. **Source file in /Users/sac/ggen_igniter @ 7dbcdb3a is clean and formatted** — the
   drift is introduced inside the test's sandbox copy, not in the fixture repo.
2. `test/xaas/ultracode/semantic_drive_test.exs:357` — same suite, "no drift is REFUSED(no_delta)" — same
   `fabric_court_build_broken` / BUILD_BROKEN on the identical format diff in the sandboxed
   execute.ex. Same root cause as (1).
   *(Typo in heading: line is `semantic_drive_test.exs:357`.)*
3. `test/xaas/ultracode/machine_experience_test.exs:1303` — "candidate that resolves only by
   overrunning time_s is exhausted..." — `attempt["standing"]` is `nil` where the test asserts
   `"ALIVE"`; machine_experience_test.exs:1326.
4. `test/xaas/ultracode/machine_experience_test.exs:1162` —
   "episode 1 UNKNOWN -> bounded exploration -> admitted MachineExperience..." —
   `run/2` returned `{:unknown, %{reason: "exploration_budget_exhausted", exhausted: "candidates_exhausted",
   attempts: [{capability: "recipe:mix-format", refused: REFUSED(reconcile_refused) / promotion_refused(evidence), ...}]}`
   where `{:ok, s1}` was expected. Exploration path refuses promotion at reconcile with
   `R_not_fed_back` / `promotion_refused(evidence)`.

## Named-opinion note (outside classification)

Failures 1-2 share one root cause (sandbox format drift in the drive's gall checkout of
ggen-lane content); 3-4 share the MachineExperience exploration/promotion path. Two root causes,
four tests. No fixes applied per lane mandate.

## W310 machine_experience adjudication (2026-10-06, lane W310)

**Verdict: NOT REPRODUCIBLE / already resolved on the current tree.** Neither of W227's
machine_experience failures (root cause 2, items 3-4) reproduces. No test edit, no lib edit.

Evidence:
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/ultracode/machine_experience_test.exs`
- Real output: `Finished in 125.7 seconds ... 21 passed, 4 skipped` — zero failures.
  (Only noise: pre-existing `Path.join(nil, ...)` type warning at test line 1118 setup;
  AshA2A/Grafana/autofde runtime warnings unrelated to this suite.)

Why W227's signatures no longer match:
- The current test file no longer contains the described assertions. Around :1162 the
  episode-1/2 test (`git log` subject eb5928eb lineage) asserts the current contract;
  around :1290+ the file pins typed refusals — `{:refused, %{"reason" =>
  "experience_admission_invalid", detail.invalid[].reason == "admission_digest_mismatch"}}`,
  `route.json decision == "REFUSED"`, and three `exploration_budget_exhausted`
  pins (:841, :1315, :1402), including the overrun test W227 item 3 named —
  i.e. the W116/W125 typed-refusal pinning is already in place for both cited tests.
- The overrun test W227 flagged (`attempt["standing"] nil where "ALIVE" asserted`) is now
  the "candidate that resolves only by overrunning time_s is exhausted, not resolved:
  receipted UNKNOWN naming the drive's head, no experience" test and PASSES.
- `git log -6 -- test/xaas/ultracode/machine_experience_test.exs`: latest subjects
  eb5928eb (env-honest drive tests), 795153d6, 0ddb308f, ffbbee05, d19623ed (V23-M
  repairs: typed applicability, post-drive budget meter, re-verified routing) — the
  refusal paths W227 saw were the pre-repair behavior these subjects replaced.
- Working tree: lib/xaas/ultracode/{autonomic,semantic_drive,plan_next}.ex carry other
  lanes' uncommitted edits; the suite passes WITH them present, so no regression is
  introduced there either.

Adjudication per the lane decision rule: refusal-correct-and-already-pinned (no STOP).
No reconcile/promotion lib defect observed on this subject. Standing: ALIVE for
`mix test test/xaas/ultracode/machine_experience_test.exs` on the current working tree;
falsifier: the same command going red.

## W309 sandbox format fix

Lane W309, 2026-10-06, subject `/Users/sac/xaas` @ feat/playwright-surface (uncommitted),
test file `test/xaas/ultracode/semantic_drive_test.exs` only.

**Root cause (reproduced, W227 hypothesis 2 confirmed).** The `ggen-igniter-format`
fabric court pins its toolchain to Elixir 1.18.4-otp-27
(`TargetSuites.elixir_format_suite` -> `elixir_env/3` PATH pin). The ggen_igniter
checkout under judgement (`GGEN_IGNITER_DIR=/Users/sac/ggen_igniter` @ 7dbcdb3a) is
formatted by a newer formatter (clean under 1.19.5 and 1.20.2). Mix 1.18.4's
formatter folds the `{:ok, front} <- hop("frontier",
Reconciler.frontier(work_orders, events, authority_opts))` one-liner at
`lib/ggen_igniter/semantic_jira/execute.ex:134`, so every epoch worktree
(`gall-ggen_igniter-*`) was BORN unformatted under the court's own toolchain and the
court step `mix format --check-formatted` failed (exit 1) before the drive could even
classify a provider refusal:

```
"output_tail" => "...** (Mix) mix format failed due to --check-formatted.
The following files are not formatted:
/Users/sac/.cache/tmp/xaas-drive-drive-runs-13635/gall-ggen_igniter-94c193f8daec8f753041/lib/ggen_igniter/semantic_jira/execute.ex"
"reason" => "fabric_court_build_broken", "standing" => "BUILD_BROKEN"
```

Reproduction (pre-fix): `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=... MIX_ENV=test
mix test test/xaas/ultracode/semantic_drive_test.exs:357` -> 1 failure
(`BUILD_BROKEN` at `semantic_drive_test.exs:365`, court `Mix 1.18.4 (compiled with
Erlang/OTP 27)`).

**Fix.** Court-prep normalization in the test's `setup_all`: after the subject clone,
checkout the base head and run the court's OWN toolchain `mix format` (write mode,
PATH taken from `Mix.Tasks.Xaas.Episode.court_suite().env["PATH"]`), commit the result
with a fixed identity, and use that sha as the episode `base_sha`. The court is hence
deterministic regardless of which formatter produced the upstream checkout; the drift
commit still touches only `cli.ex`, so the drift contract
(`git diff --name-only subject_sha head == cli.ex`) and the revert falsifier (the
`defmodule  X  do` drift is unformatted under every formatter version) are preserved.
Comment citing W227 is inline at `normalize_formatter!/2`.

**Verification (real output).**
- `mix test .../semantic_drive_test.exs:357` (post-fix): `1 passed, 20 excluded` (was: 1 failure BUILD_BROKEN).
- `mix test .../semantic_drive_test.exs:113`: see below.
- Standing: PARTIAL_ALIVE until the :113 run lands green; falsifier: either command red.
- **Second blocker found and fixed (W309):** after the format normalization the
  :114/:357 court passes but reconcile refused `promotion_refused [evidence]`:
  the drive's `step(:reconcile)` called `mix semantic_jira.xaas_receipt` WITHOUT
  `--work-orders`, so ggen_igniter's `required_evidence` lookup (cli.ex:186)
  got nil and fell back to `bridge.requires.evidence` — absent, because the
  descriptor bridge carries exactly the three lists
  courts/acceptance/falsifiers (descriptor.ex:554, AdmissionBinding law). The
  receipt's `evidence_types` could therefore never witness the work order's
  required evidence IRI. Fix: pass `["--work-orders", ctx.work_graph]` in the
  `xaas_receipt` argv (`lib/xaas/ultracode/semantic_drive.ex`, one argv pair +
  W227 comment). Note: this edit touches semantic_drive.ex, which carries other
  lanes' uncommitted edits — coordinator should reconcile at integration.
- **Final gate (real output):**
  `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter
  MIX_ENV=test mix test test/xaas/ultracode/semantic_drive_test.exs`
  -> `21 passed, 0 failures, 0 skipped` (81.3s), plus post-format confirm
  `:357 -> 1 passed, 20 excluded`. Standing: ALIVE for both W227 BUILD_BROKEN
  targets on the current working tree. Files owned/changed:
  `test/xaas/ultracode/semantic_drive_test.exs`,
  `lib/xaas/ultracode/semantic_drive.ex` (one argv pair),
  this receipt. No git operations performed.
