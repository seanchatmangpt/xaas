# v26.10.6 Convergence Audit — Vector 5: Resource Limits, Static Analysis & Complexity

Repos: `/Users/sac/xaas`, `/Users/sac/ash_surface`. Method: real greps of `lib/` and `test/`,
real `mix compile --warnings-as-errors` under `MIX_ENV=test` (asdf shims), and a mechanical
function-length/conditional-density scan of both `lib/` trees. No git mutations; this is the
only file written.

## (c) Compiler / lint state under strict flags — VERIFIED GREEN

| repo | command (MIX_ENV=test) | exit | notes |
|---|---|---|---|
| xaas | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile --warnings-as-errors` | 0 | Only warnings emitted were in **deps** (`deps/ex4pm/mix.exs:12` `Application.get_env` discouraged; `ash_affidavit/signing.ex:312` unused `@envelope_domain_tag`) — deps compile without `--warnings-as-errors`, so exit 0. Zero warnings in `lib/xaas` or `lib/xaas_web`. `_build` healthy (a build-dir lock held by pid 80446 was waited out, no corruption). |
| ash_surface | same command in `/Users/sac/ash_surface` | 0 | Dep warnings only (`ash_a2a/receipt_store.ex:151` type warning `dynamic(true)`; `ash_a2a/consequence_kernel/call_graph_court.ex:20` redundant `defp normalize(nil)`). `==> ash_surface: Compiling 51 files` clean, zero app warnings. Note: ash_surface has multiple lane build roots on disk (`_build-fleet-ash_surface`, `_build-nsprefix`, `_build-pub`, `_build-tdb-surface`, `_build-w16-11`) — per the cleanup law these are stale leases at integration, flagged here for the coordinator. |

Dialyzer is configured in both (`mix.exs` `dialyzer` + ignore files); not run in this vector
(dialyzer is out of scope for the compile-only gate).

## (a) Hard resource caps

### xaas

| cap | location | enforced upstream before execution? | boundary-tested? |
|---|---|---|---|
| Worker timeout + output-bytes cap | `lib/xaas/ultracode/dispatch.ex` (`@default_max_output_bytes 65_536`; deadline computed before `Port.open`; `collect/7` polls deadline, `keep_tail/2` truncates to `max_output_bytes`; `drain/…` same) | YES — deadline + cap passed into collect before any spawn; `kill_group` in `after` | Partial: cap values exercised in `test/xaas/ultracode/*` (autonomic_test:480/506, semantic_jira_*_crown/provenance/forged_court tests set `max_output_bytes: 4096/8192`); `wave_loop_test.exs:879-885` boundary-tests `ultracode_wave_loop_timeout_seconds: 1`. No dedicated test asserts the `keep_tail` byte boundary itself at exactly max vs max+1. |
| Context budget (items + bytes) | `lib/xaas/trimtab/context_budget.ex` — `within?/2`: `length(xs) <= max_items and byte_size(term_to_binary) <= max_bytes` | YES — pure check, callers gate on it | YES — `test/xaas/trimtab/context_budget_test.exs` asserts both sides of both bounds (over-items at 8, over-bytes at 8 bytes) |
| Sensing `max_items` (default 20) | `lib/xaac/ultracode/sensing.ex:231,277` — `positive_int(profile["max_items"])`, applied as `Enum.take` AFTER dedup+sort | YES — validated at profile parse, applied before emit | YES — `sensing_test.exs:120,132,388` ("max_items bounds output", "binds AFTER dedup+sort", bounded profile) |
| Semantic wave `max_items`/`capacity` | `lib/xaas/ultracode/semantic_wave.ex:32-33` — `admit_positive(:capacity,…)` and `admit_positive(:max_items,…)` in the `with` chain BEFORE `ready_epochs`/dispatch | YES — admission gate precedes `Task.Supervisor.async_stream_nolink` (with `max_concurrency: capacity`) | `test/xaas/ultracode/semantic_wave_test.exs` exists (passes values, exercises dispatch); no explicit negative test of `admit_positive` refusal observed |
| OCEL log rotation (10 MiB, keep 2) | `lib/xaas/telemetry/ocel_ash_emitter.ex:543-549` — `maybe_rotate` stats file and rotates BEFORE append (`maybe_rotate(@log_path)` from `append_ocel_event!/1`) | YES — pre-append size check | Mentioned only in a comment in `ocel_ash_emitter_test.exs:38`; no direct test drives a file over 10 MiB (acceptable — cost; but not boundary-tested) |
| Atlassian payload truncate (255) | `lib/xaas/sjira/atlassian_transport.ex:503,540,623` | Applied at payload build | Indirect only (grep hits in controller tests are coincidental word matches, not boundary tests of `truncate/2`) |
| HTTP body limit | `lib/xaas_web/endpoint.ex:71-77` `Plug.Parsers` with custom `StripeRawBodyReader` body_reader delegating to `Plug.Conn.read_body(conn, opts)` | Implicit only: no explicit `:length` option — you get Plug's default 8 MiB per parser segment. Not an explicit, named, auditable cap. | `stripe_webhook_controller_test.exs` tests signature path, not body-size rejection |
| `epoch_timeout_seconds` / duration budget | `xaas.stop_court`, `ultracode` engine/wave_loop | configured per epoch before dispatch | YES — `wave_loop_test.exs:879` (timeout=1), `duration_budget_test.exs:319` (`epoch_timeout_seconds: 0`) |

### ash_surface

| cap | location | upstream? | boundary-tested? |
|---|---|---|---|
| Verifier timeout (default 30 s) | `lib/ash_surface/mx_episode.ex:52,227-231,448-486` — `validate_timeout/1` (integer ≥ 0) in the `with` chain BEFORE `run_verifier`; deadline = monotonic + timeout, enforced in `collect_verifier` receive loop; timeout is `{:error, {:verifier_timeout, ms}}`, never a pass | YES — validated before spawn, enforced at port receive | YES — `test/ash_surface/mx_episode_verify_hardening_test.exs:61,73` (`timeout: 0` → `{:error, {:verifier_timeout, 0}}`, no scratch file left on timeout) |
| JS client reconcile timeout | `lib/ash_surface/projectors/expo.ex:264-289` — `reconcileTimeoutMs = 10000`, `AbortController` abort | YES (client-side, before fetch resolution) | Not directly boundary-tested (generated projector surface) |
| Expo JS tokenizer bound | `lib/ash_surface/projectors/js/zod_guard.ex:106-109` — `binary_part` recursion over remaining text | Structural recursion, terminates | Covered via projector tests (`event_projection_coverage_test.exs`) |

No request-body, nesting-depth, or iteration-count caps exist in `ash_surface/lib` — the
surface has no HTTP server input path; its only external inputs are the verifier subprocess
(time-bounded above) and projectors (total functions).

## (b) Complexity hotspots (heuristic: top-level function segment ≥80 lines or ≥25 conditionals)

Top offenders (lines / cond-count):

1. `xaas/lib/xaas_web/live/next_read/reader_live.ex` `render/1` — 494 lines, 29 cond (worst in fleet; heaviest conditional density too)
2. `xaas/lib/xaas/ultracode/target_suites.ex` `devs/1` — 367 lines
3. `xaas/lib/xaas_web/live/system/command_center_live.ex` `render/1` — 348 lines, 16 cond
4. `xaas/lib/xaas_web/live/chicago/seller_live.ex` `render/1` — 313 lines, 17 cond
5. `xaas/lib/xaas_web/live/wd_fa/case_study_live.ex` `render/1` — 313 lines, 10 cond
6. `xaas/lib/xaas/ultracode/autonomic.ex` `build_ctx/1` — 163 lines, 21 cond
7. `ash_surface/lib/ash_surface/ir.ex` `profile_section` — 145 lines, low cond (mostly data literal)
8. `xaas/lib/xaas/ultracode/run_validation.ex` `epoch_violations` — 143 lines, 8 cond
9. `xaas/lib/xaas/ultracode/autonomic.ex` `attempt/…` — 119 lines, 7 cond
10. `xaas/lib/xaas/ultracode/semantic_drive/plan_next.ex` `to_work_order` — 108 lines, 18 cond (path: `lib/xaas/ultracode/semantic_drive/plan_next.ex`)

Pattern: the hotspot cluster is **Phoenix LiveView `render/1` functions and ultracode
orchestration** — mostly HEEx/data-literal bulk (reader_live, case_study, ir.ex) rather than
true branch complexity; the genuinely high-branch offenders are `reader_live render` (29),
`autonomic.build_ctx` (21), `seller_live render` (17), `target_suites.devs` (16).

## Bottom line

- **(c) GREEN both repos** under `MIX_ENV=test mix compile --warnings-as-errors` (exit 0;
  dep-only warnings).
- **(a)** Caps are real and mostly enforced upstream-before-execution (semantic_wave admission
  gate, dispatch deadline+output cap, sensing profile validation, OCEL pre-append rotation,
  context_budget pure gate). Gaps: HTTP body limit is Plug's implicit 8 MiB default (no
  explicit `:length` in `endpoint.ex`), and three caps lack true boundary tests (OCEL rotation
  over-limit, atlassian truncate at 255, `admit_positive` refusal paths, `keep_tail` at exactly
  max vs max+1).
- **(b)** Complexity concentrates in LiveView `render/1` bulk and ultracode orchestration;
  `reader_live.ex render/1` (494 lines / 29 branches) is the single worst offender in either
  repo.
