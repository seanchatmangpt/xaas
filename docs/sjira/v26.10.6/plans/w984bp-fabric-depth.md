# W984bp Lane Receipt — Execution Fabric Hook-Depth Court

- **Subject**: branch `feat/playwright-surface`, one new file
  `test/xaas_web/execution_fabric_hook_depth_test.exs` (5 tests). No `lib/`
  changes. Not committed (lane law: coordinator owns commits).
- **Controller under court**: `lib/xaas_web/controllers/execution_fabric_controller.ex`
  (read fresh this session; graphql-free, graphql-removal untouched).
- **Coverage gap (evidence)**: grep over the four existing fabric courts
  (`test/xaas_web/execution_fabric_controller_test.exs`,
  `test/xaas_web/execution_fabric_deepening_test.exs`,
  `test/xaas_web/quiescent_fabric_tie_test.exs`,
  `test/xaas_web/controllers/execution_fabric_surface_test.exs`):
  - `pre_tool_use` with-lease arms (200 allow + typed 403 deny) — NO coverage
    (only the no-lease 403 arm, controller_test line 277).
  - `user_prompt_submit` / `post_tool_use` / `post_tool_use_failure` hooks —
    NO HTTP coverage anywhere (0 grep hits outside this lane's file).
  - hook `stop` with-lease arms (200 closed; 200 not_closeable-with-token) —
    NO coverage (only the no-lease not_closeable arm, controller_test line 287).
  The w982g/w984as/w984w quiescent tie court owns the halt envelope
  (`actuate` quiescent intent) — avoided, per lane contract.
- **The 5 tests** (all real ConnCase HTTP behind the real
  `RequireInternalApiToken` bearer gate, real sandboxed rows, real
  `claim_next` claims; mutation rationale per test):
  1. pre_tool_use with live lease ALLOWS `Edit` — asserts exact
     `%{"decision" => "allow"}` (kills the Map.new atom→string
     normalization mutant and allow→refused arm flip).
  2. pre_tool_use with live lease DENIES `git_push` — exact typed 403 body
     `refused_no_authority:"git_push"` (kills deny→allow arm collapse and
     reason-drop mutants).
  3. post_tool_use + user_prompt_submit record 200 `%{"status" =>
     "recorded"}` with a live lease; `post_tool_use` without a lease is a
     typed 422 `{"decision":"deny","reason":":no_lease"}` — envelope
     divergence from pre_tool_use's 403 is asserted exactly (kills
     422→403 routing mutants and invented-token mutants).
  4. hook `stop` with a live lease closes: `%{"status" => "closed",
     "epoch_id" => epoch.id, "outcome" => "partial_alive"}` AND the Receipt
     is durably readable through the lawful
     `GET /internal-api/execution/epochs/:id/receipts` path (kills
     stop→not_closeable mutants and receipt-skipping mutants).
  5. hook `stop` with an unclosable token: stays 200
     `%{"status" => "not_closeable", "reason" => ...}` and seals NOTHING
     (receipt list verified empty through the lawful read) — the
     lease-expiry never-closure floor.
- **Commands / exits** (PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test,
  MIX_BUILD_ROOT=_build-laneW984bp):
  - Run 1 (11:42): 4/5 — one real assertion failure: wire `reason` was
    `":no_lease"` (`format_reason/1` inspect catch-all). Test updated to
    the observed contract; no `lib/` edit by this lane.
  - **Mid-flight collision (observed, disclosed)**: at 11:43 sibling lane
    W984ca landed an 8-line addition to the controller — a
    `format_reason/1` atom clause (`Atom.to_string/1` for bare-atom deny
    reasons) — flipping the 422 wire reason from `":no_lease"` to
    `"no_lease"` between my runs. This lane made NO `lib/` edits; the
    court was re-aligned to the live controller (the contract it courts)
    and re-run.
  - Runs 2-4 (x2 on the live controller, 11:46 and 11:50):
    `Result: 5 passed, 0 failures` both runs.
- **Standing**: ALIVE (observed execution on the exact subject, 5/5 ×2).
- **Build root**: `_build-laneW984bp` — deletion attempted at integration;
  if still present, left for coordinator per lane law.
- **Falsifier for this court**: any of the 5 tests passing after the
  corresponding arm in `handle_hook/3` is mutated (e.g. pre_tool_use deny
  flipped to allow, stop failure arm returning `closed`) marks the court
  non-vacuous-failing, i.e. it kills its named mutant classes; conversely
  a red run on the untouched controller is a court defect.
