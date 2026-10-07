# Vector 3 — Differential Oracles & Ignored Conformance Suites (v26.10.6)

Read-only audit of `/Users/sac/xaas` and `/Users/sac/ash_surface`. Every row cites the
skip mechanism as it exists on disk (2026-10-06, branch `feat/playwright-surface`,
HEAD `d1db2b03`). No builds, no git mutations, no code changes.

## 1. xaas — default-excluded tag classes (`test/test_helper.exs:56-67`)

The single `ExUnit.configure(exclude: [...])` at `test/test_helper.exs:54-67` removes
nine tag classes from every default `mix test`. `mix.exs` provides two re-inclusion
aliases: `test.full` (includes all of them) and `test.integration` (excludes
`:stress`, `:kind`, `:requires_cnv_deploy` — "need a live k8s cluster this
environment does not have", `mix.exs:296-306`).

| file | test | skip mechanism | un-ignore requirement |
|---|---|---|---|
| `/Users/sac/xaas/test/xaas/castle_bridge_test.exs:57,167` | CASTLE cross-repo BRCE court — real binary built from the admitted CASTLE source subject judged through the bridge | `@tag :castle_kernel`, excluded `test_helper.exs:65`; re-included only by `.github/workflows/castle-paas-bridge.yml:164` (`mix test --include castle_kernel test/xaas/castle_bridge_test.exs`) | Build the admitted CASTLE subject binary locally (workflow supplies it in CI) or point the test at a prebuilt artifact; then drop `:castle_kernel` from the exclude list or run `mix test --include castle_kernel` as a gate |
| `/Users/sac/xaas/test/e2e/kind_deployment_test.exs:65`, `kind_chaos_pod_recovery_test.exs:32`, `kind_chaos_postgres_pod_recovery_test.exs:62` | Real chaos/e2e against a live kind-xaas pod | `@moduletag :kind`, excluded `test_helper.exs:58`; requires `kubectl port-forward` to kind-xaas already running (`test_helper.exs:22-24`) | Start `kind` cluster + `kubectl port-forward`, then `mix test --include kind`. For a non-optional gate: a CI service container (kind action) supplying the cluster; otherwise bounded-forever out of scope (no live k8s here per `mix.exs:296`) |
| `/Users/sac/xaas/test/xaas/operations/autofde_planner_candidate_test.exs:4` and `autofde_planner_cross_product_test.exs` | Real cnv-deploy-dependent planner tests | `@moduletag :requires_cnv_deploy`, excluded `test_helper.exs:59` | Deploy cnv (the local container substrate) and remove the tag from the exclude list; same live-cluster class as `:kind` |
| `/Users/sac/xaas/test/xaas/ontology/ex4pm_staleness_test.exs:22` | Real cross-repo staleness court vs sibling `~/ex4pm` checkout | `@moduletag :external`, excluded `test_helper.exs:60` ("default `mix test` never depends on that sibling repo") | Clone/check out `~/ex4pm` once (one canonical checkout per repo, already the fleet doctrine); then `--include external`, or drop the tag |
| `/Users/sac/xaas/test/xaas/library/explainer_test.exs:100` | Real Groq API call (`@describetag :external_llm`) | Excluded `test_helper.exs:62` — added after a real disclosed bug where the tag existed but was NOT excluded and made a real API call every `mix test` (`test_helper.exs:38-43`) | `GROQ_API_KEY` in env + network, run via `test.integration`/`test.full`. As a hard gate: keep excluded from fast loop; include in CI `test.integration` job with a real key secret |
| `test/mix/tasks/xaas_verify_and_commit_test.exs`, `test/mix/tasks/xaas_ingest_capability_receipts_test.exs`, `test/xaas/autofde/demo_planner_reactor_test.exs` | Real OS subprocess tests (nested `mix`/`git` BEAM boots, real Ports + `ps` liveness) | `@tag/:moduletag :subprocess`, excluded `test_helper.exs:63` (2+ nested VM boots each) | Nothing environmental — just time. `mix test --include subprocess` or `test.full`/`test.integration`; make CI run `test.integration` as the merge gate |
| `test/xaas/operations/capability_liveness_regressions_property_test.exs` | StreamData property tests, hundreds of real-DB cases | `@tag :property`, excluded `test_helper.exs:64` | Time only — `mix test --include property` / `test.integration`. Bounded: it is already in the `test.integration` alias |
| `:stress` tag (pool-hungry concurrency tests) | Stress tests | Excluded `test_helper.exs:57`; deliberately NOT in `test.integration` (`mix.exs:296-301`) | Connection-pool-tuned Postgres + time; keep in `test.full` only (bounded-resource verdict: stays opt-in) |
| `/Users/sac/xaas/.github/workflows/ci_cd.yaml` etc. | — | No `continue-on-error` and no `--exclude` found in any xaas workflow — no CI-skipped jobs | n/a |

## 2. xaas — conditional skip-tagged tests (differential/oracle suites)

| file | test | skip mechanism | un-ignore requirement |
|---|---|---|---|
| `/Users/sac/xaas/test/xaas/receipt/r_projection_test.exs:18-22,65,115,128,146,167,206` | **Differential oracle**: every real receipt is re-validated by the independent fleet validator `~/.claude/dfcm/validate_receipt.py` via `python3` (line 334) | `@needs_validator if File.regular?(@validator)` — skips silently when the validator script is absent | Install/pin `~/.claude/dfcm/validate_receipt.py` (it exists on this host — verify with `test -f`); requirement is only that the gate assert its presence: convert the silent `File.regular?` skip into a setup-time `flunk` when absent on CI |
| `/Users/sac/xaas/test/xaas/receipt/r_projection_consistency_test.exs:340-343` | **Oracle suite, episode fmt-1**: replays the committed reference episode against the real ggen_igniter subject repo and asserts projection consistency | `@describetag skip: if(is_nil(@ggen_dir))` where `@ggen_dir = System.get_env("GGEN_IGNITER_DIR")` (line 43) | `GGEN_IGNITER_DIR` set to a ggen_igniter checkout (canonical checkout at `~/ggen_igniter`); export the env var in CI/test.full. No code change needed |
| `/Users/sac/xaas/test/xaas/ultracode/origin_authority_test.exs:34-38,104-107` | **Differential oracle vs production kernel**: drives the real G1 kernel in the ggen_igniter checkout (sj:AuthorityTrustRoot pins + compiled `_build/test`), `SemanticDrive.graph_toolchain/2` | `@ggen_ready File.regular?(ontology) and File.dir?(#{ggen}/_build/test/lib/ggen_igniter)`; skips with reason "no sj:AuthorityTrustRoot pins or no compiled _build/test" | `GGEN_IGNITER_DIR` at a ggen_igniter checkout **with `_build/test` compiled**. Bounded: one `mix compile` of the sibling under the pinned toolchain, then export env. CI must compile the sibling (cache the build) |
| `/Users/sac/xaas/test/xaas/ultracode/semantic_drive_anchor_test.exs:27-36,165` | Live anchor through the real graph side of ggen_igniter (`mix semantic_jira.descriptor`) | `@live_skip` when `GGEN_IGNITER_DIR` is nil or lacks `lib/mix/tasks/semantic_jira.descriptor.ex` | Same as origin_authority: env var + intact sibling checkout. No code change |
| `/Users/sac/xaas/test/xaas/sjira/ard_court_test.exs:18,714-717` | Real ash-atlassian ARD court over `~/ash_atlassian` (+ `~/ggen-marketplace`) | `@real_ready File.dir?(~/ash_atlassian) and ...` skips with "~/ash_atlassian or ~/ggen-marketplace not present" | Clone `~/ash_atlassian` and `~/ggen-marketplace` (canonical checkouts). Bounded: 2 clones; then the describe block runs un-skipped |
| `/Users/sac/xaas/test/xaas/sjira/yield_test.exs:24,125` | **Differential oracle**: flipped OCEL outcome must reach the real SA2A allocator (beam-bridge `autofde` binary) lane order | `@tag skip: if(@autofde, ...)` — `System.find_executable("autofde")` | Build/install the `autofde` binary on PATH (the SA2A beam-bridge). If the binary is a build artifact of a sibling repo, CI must build it once; otherwise keep as named environmental skip |
| `/Users/sac/xaas/test/xaas/sjira/yield_test.exs:234-237` | Fleet matrix salience assertions via `jq` | `@tag skip: if(@jq ...)` — `System.find_executable("jq")` | `jq` on PATH (one `brew install jq`); trivial gate |
| `/Users/sac/xaas/test/xaas/sjira/successor_test.exs:132-135` | **Independent oracle**: `successor_law.py` re-derives the successor law via python3+rdflib ASK, independent of the Elixir side | `@rdflib` — python3 present AND rdflib importable; skips with "successor_law.py needs python3 with rdflib" | `pip install rdflib` into the host python3 (bounded); or vendor rdflib into a venv the test activates. Same for the twin skips in `test/sjira/v26_9_23_goal_test.exs:1128,1816` and `test/mix/tasks/xaas_stop_court_test.exs:569` |
| `/Users/sac/xaas/test/xaas/zcode_plugin/projection_test.exs:20,30` | Real `ggen` binary projection of the zcode plugin surface | `@ggen_present System.find_executable("ggen") != nil` | `ggen` installed on PATH (already fleet capital — install/pin the release); then runs un-skipped |
| `/Users/sac/xaas/test/xaas/ultracode/gate_surface_test.exs:22-24` | Node-based gate surface | `@moduletag skip: if(@node ...)` — `System.find_executable("node")` | `node` on PATH (one install) |
| `/Users/sac/xaas/test/xaas/chicago/seller/seller_live_test.exs:308` | R6: `/chicago/seller` route live test | Hard-coded `@tag skip: "R6: the /chicago/seller route lands at integration (lanes do not touch router.ex); un-skip then"` — a deferred integration step, not environmental | Land the router.ex route (the named integration step the skip message names), delete the tag. This is the one pure code-closure skip in the repo |

## 3. ash_surface

The core conformance replay (`test/conformance/conformance_replay_test.exs`, corpus in
`conformance/vectors/*.json` pinned by `MANIFEST.json` sha256, regenerate via
`scripts/conformance_regen.exs`) is **not ignored** — it runs in the default suite and
is already a hard gate. Same for the `:truth_changed_by_t17`/`:gap_closed_by_t17` and
`:path_truth`/`:flow_states` tags (informational, not excluded anywhere — checked
`test_helper.exs` (bare `ExUnit.start()`), `mix.exs`, and all five workflows).

| file | test | skip mechanism | un-ignore requirement |
|---|---|---|---|
| `/Users/sac/ash_surface/test/ash_surface/lineage_court_test.exs:550-556` | **LIVE PR #7 court**: re-judges the real PR #7 ancestry claim on real git history | Compile-time `if` + `@tag skip: "real PR #7 history unreachable (shallow/absent .git); set ASH_SURFACE_LINEAGE_GIT_DIR to a full clone's .git"` | `ASH_SURFACE_LINEAGE_GIT_DIR` env pointing at a full (non-shallow) `.git`; `ci.yml:13-19` already does `fetch-depth: 0` in CI for exactly this reason (comment at lines 13-15: "a shallow clone makes them a named skip, so CI would never judge the claim") — locally export the env var, no code change |
| `/Users/sac/ash_surface/mix.exs:157-160` (`test.zoe`) | ZOE extracted-package suite (`packages/ash_surface_zoe`) | Deliberately NOT part of `test.all` ("deliberately NOT part of test.all so core stays green without it") — optional-only path | Give `packages/ash_surface_zoe` its own deps/_build and run `mix test.zoe` as a separate CI job (its own gate), or fold it into `test.all` after fixing its build |

## 4. Closure verdicts (bounded resources)

1. **One-command fixes (make gates now)**: `r_projection` validator
   (`File.regular?` → presence assert), `GGEN_IGNITER_DIR` suites (export env to
   canonical checkout), `ASH_SURFACE_LINEAGE_GIT_DIR`, `jq`, `node`, rdflib, `ggen`
   on PATH. All are environment-presence skips with named reasons; none need new
   test code beyond a presence-assert.
2. **One-clone fixes**: `~/ash_atlassian`, `~/ggen-marketplace`, `~/ex4pm` canonical
   checkouts un-skip ard_court, ex4pm_staleness.
3. **One-build fixes**: compile `~/ggen_igniter/_build/test` (origin_authority);
   build/install `autofde` (yield SA2A allocator oracle).
4. **One code change**: delete the `seller_live_test.exs:308` R6 skip after landing
   the router route.
5. **Out of bounded scope (keep opt-in, CI-supplied)**: `:kind`, `:requires_cnv_deploy`,
   `:stress`, `:castle_kernel` (CI builds the subject in
   `castle-paas-bridge.yml`), `:external_llm` (needs a real API key secret).
   These stay `test.full`-gated, not default-gated.
