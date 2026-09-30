# CI architecture (rebuilt 2026-09-30)

Objective order: PR wall-clock to trustworthy green, then main wall-clock, then compute.
Evidence labels: **MEASURED** (observed here), **ESTIMATED** (reasoned, not run),
**NOT YET OBSERVED**.

## Observation that drove the design

MEASURED from the Actions API (800 completed runs 08-20..09-30; per-job data for 314 runs
since 09-24) and from local runs with the pinned OTP 28.5.0.2 / Elixir 1.20.2 toolchain:

| Fact | Value |
|---|---|
| Median successful PR wall-clock (17 runs, 09-24..09-26) | 53.6 min = `ci` 28.2 then `image-check` 23.8 (serial) |
| Dialyzer inside `ci` | 25.5 min (47.6% of wall); no PLT cache, dev deps recompiled cold (~12.6 min) then project PLT (~12 min) |
| `image-check` | 23.8 min, waits for every other job, no Docker layer cache, repeats the prod compile |
| `production` compile court | 21.6 min every run (no cache), parallel to `ci` |
| `mix test` | 2591 tests: 228 s serial local, 104 s in CI; 193 s with 2 processes (15% faster, not adopted) |
| Cold dependency compile (local, 4 cores) | 1677 s; `sparql` 543 s + `ggen_igniter` Rust NIF 499 s = 62% |
| Cache payload | `_build` 516 MB (431 MB zstd, 3.9 s); an existing CI restore of ~385 MB took ~6 s |
| Runs cancelled | 65% (09-14..09-30); 23% of runner-minutes (1570 of ~6864) went to cancelled jobs |
| Same sha run twice (push + pull_request) | 32% of shas |
| Last 100 runs | 0 succeeded: failures were cheap static defects (format 81, lock 35, prod warnings 20, syntax 13) that still paid for the 22 min prod job |

## Topology

```
PR / main push
 ├─ ci          restore cache → lock check → format → compile -W → tests → unused deps
 ├─ dialyzer    restore dev cache + PLTs → dialyzer (PLT saved even on warnings)
 ├─ production  restore prod cache → compile --force -W
 ├─ image-check buildx with gha layer cache (starts at t0; was serialized last)
 ├─ asyncapi, workbench (unchanged, seconds)
 └─ receipt     !cancelled(); asserts all six lanes; writes cache-hit table to the job summary
publish-image / deploy: unchanged operator-gated actuation (now also needs dialyzer)
```

Shared logic is one composite action, `.github/actions/beam`: pinned toolchain from
`.tool-versions`, cache keyed `mix-<env>-<os>-<erlang+elixir digest>-<hash(mix.lock)>`
with a same-toolchain prefix fallback (a lockfile change recompiles only the dependencies
that changed instead of the full 28 min), `mix deps.get --check-locked`, `mix deps.loadpaths`
(compiles only missing/stale dependencies; MEASURED 1.2 s no-op warm; an explicit `mix deps.compile`
rebuilds everything and cost 6.5-7 min per lane on a cache hit in the first run), and a cache
save immediately after dependencies compile (so failing runs still seed it).
Only the erlang/elixir lines of `.tool-versions` enter the key; editing terraform/awscli
no longer invalidates it.

Build-once/test-many was tested as a hypothesis and **not** adopted: a cache restore is
~6 s for ~400 MB and the application compiles in ~35-55 s, so artifact hand-off between jobs
would not beat restoring the lock-keyed cache in each lane.

## ERRC

- **Eliminated:** `deps-test` (warm-up job superseded by the cache save in the composite),
  `autonomic-wave-contract` (a tag-selected subset of the full `mix test`),
  `verify_system_authority_exact_head.yaml` (single cancelled run ever, hardcoded historical
  sha, only triggered on a dead branch), push triggers on `feat/**`, `fix/**`, `epoch/**`
  (the pull_request run covers the same sha), `--trace` (forced `max_cases: 1`) and
  `--max-failures 1` on the main suite, the `role "root" does not exist` Postgres health-check
  log spam.
- **Reduced:** critical path (serial `ci` → `image-check` → `receipt` became parallel lanes);
  cancel cost (main runs are no longer cancelled, PR runs still are); Elixir compile setup in
  `wd-cs2-exact-head`, `stogaf-wd-cs2-court`, `ultracode-closure`, `project-measure-extension`
  (all now use the shared cache); `packer` and `stogaf` no longer run on every main push;
  `wd-cs2-exact-head` only when its inputs change (plus a daily run).
- **Raised:** cache hit probability (prefix restore instead of exact-or-nothing),
  cache reuse across workflows (same `mix-test-…` key), PLT reuse, Docker layer reuse,
  failure localization (receipt names the failing lane and cache state).
- **Created:** `.github/actions/beam`, `cold-court.yml` (weekly from-scratch compile of test
  and prod plus an uncached image build, so a cache can never mask a real break for long).

## Claims preserved

Every previous claim is still established per PR: exact-head identity, locked deps, format,
warnings-as-errors compile (test and prod), full test suite, unused deps, dialyzer, AsyncAPI,
workbench image, container build, bounded receipt (now strictly stronger: it also asserts
`asyncapi`, `workbench` and `dialyzer`). The one claim made weaker per PR is "production graph
compiled from a clean directory": PRs restore compiled *dependencies* (content-addressed by
`mix.lock`) and force-compile the whole application; the from-scratch form runs weekly in
`cold-court.yml`.

## Before / after

| Metric | Before | After |
|---|---|---|
| PR critical path, warm | 53.6 min median (MEASURED) | NOT YET OBSERVED. Observed warm pieces on the first run with the new cache: restore ~7 s, format 15 s, forced compile 34 s (MEASURED, run 36777276895). Dialyzer warm, prod warm, image warm: NOT YET OBSERVED. Hypothesis: 6-10 min (ESTIMATED) |
| PR critical path, cold (new lock, no usable cache) | ~54 min | dominated by dependency compile, ≈ 28 min for the lane that must rebuild it (ESTIMATED); a lockfile bump that only touches a few deps should use the prefix cache instead |
| Jobs per PR in `ci_cd` | 8 | 7 (`ci`, `dialyzer`, `asyncapi`, `workbench`, `production`, `image-check`, `receipt`) |
| Prod dependency compile per run | 1 clean (21.6 min) + 1 in Docker (≈21 min) | 0 when cached; weekly clean in `cold-court` |
| Dialyzer deps+PLT rebuild per run | every run (~25 min) | only when no PLT/dev cache matches the toolchain |
| Sha double-runs (push + PR) | 32% of shas | 0 for ci_cd (push only on main) |
| Cancelled main runs | yes (they prevented cache seeding) | no |
| Total runner-minutes | ~82 per successful run (MEASURED) | NOT YET OBSERVED |
| Estimated cost/run | - | NOT YET OBSERVED (no runner-price evidence gathered; free tier for public repos) |

## Known red, not caused by CI structure

The Trimtab tests (`test/xaas/trimtab/*`) alias `XaaS.Trimtab.*` while the modules are
`Xaas.Trimtab.*` and call APIs absent from `lib/`; the load error aborts the whole suite.
Five further failures exist locally (TopologyGuard, SjProgramRegistry, Sa2a.RouteTest
tripwire, and two others). These are repo defects, reported in PR 107, not hidden or skipped.

## Remaining opportunities, ordered by expected Δwall_clock / cost

1. Precompiled `ggen_igniter` NIF and `sparql` parser artifacts upstream (removes ~17 min from any truly cold build).
2. Docs-only change classification (needs a test→file dependency map; not guessed).
3. `r80`/`r84`/`castle` build ggen from source; consume the release binary pinned in `.ggen/toolchain.lock.toml`.
4. Share the Playwright WD court between `wd-cs2-exact-head` and `stogaf-wd-cs2-court` (identical spec).
5. SHA-pin remaining tag-pinned actions (`checkout`, `cache`, `upload-artifact`).
6. ARM64 and larger runners: NOT YET OBSERVED; the image and several NIFs are amd64-bound today.
7. Test sharding: measured 15% at 2 processes; below the runner-startup break-even.
