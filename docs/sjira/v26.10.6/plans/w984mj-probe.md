# W984mj Probe Receipt — Mutation Non-Vacuity Audit #12 (W984ls Route-Validations Court)

Lane: W984mj on /Users/sac/xaas, branch feat/playwright-surface (no branch switch, no
commit, no stash). Date: 2026-10-08.

Subject: `test/xaas/platform/route_validations_court_w984ls_test.exs` over the 5
platform route validation modules in `lib/xaas/platform/validations/`:
RouteFeatureFlagsRequiresApprover, RouteProjectsRequiresApprover,
RouteOrgsCustomDomainValidHostname,
RouteOrgsCustomDomainActiveRequiresCertificateSecret,
RouteProjectsBackupsValidProjectName.

## Method

File-swap via `cp` snapshots to `/tmp/w984mj/`, one surgical mutation at a time,
targeted court run only, restore + `cmp` byte-identical after every mutant. Fresh-beam
protocol (needed — see Build note): mutate → `touch` → `rm` the module's beam →
`mix compile` → confirm beam mtime newer than source → run court. Gates:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mj`.

Baseline: court green, **5 passed, exit 0**.

## Matrix

| # | Subject module | Mutation | Verdict |
|---|---|---|---|
| M1 | RouteFeatureFlagsRequiresApprover | drop nil leg: `is_nil(approved_by) or approved_by == ""` → `approved_by == ""` | **KILLED** (flag test fails, 4/5) |
| M2 | RouteProjectsRequiresApprover | distinct clause → `false` (self-approval no longer refused) | **KILLED** (project test fails, 4/5) |
| M3 | RouteOrgsCustomDomainValidHostname | `length(labels) >= 2` → `>= 1` | **KILLED** (hostname test fails, 4/5) |
| M4 | RouteOrgsCustomDomainValidHostname | repeated charset `[a-z0-9-]` → `[a-z0-9.-]` (interior dot) | **SURVIVED — INVALID MUTANT (auditor error, not court vacuity):** labels are post-`String.split`, so a label can never contain a dot; the mutant is semantically equivalent. Replaced by M4' |
| M4' | RouteOrgsCustomDomainValidHostname | first-char class `[a-z0-9]` → `[a-z0-9-]` (leading hyphen allowed) | **KILLED** (hostname test fails, 4/5) |
| M5 | RouteOrgsCustomDomainActiveRequiresCertificateSecret | drop blank leg: `is_nil(x) or x == ""` → `is_nil(x)` | **SURVIVED — typed masking finding** (see Finding 1) |
| M6 | RouteProjectsBackupsValidProjectName | `String.trim(name) == ""` → `name == ""` | **SURVIVED — typed masking finding** (see Finding 1) |

Score: 4 KILLED / 2 SURVIVED (both with typed, probe-confirmed cause) / 1 invalid
mutant discarded (M4, superseded by M4').

## Finding 1 (the audit's substance): blank/whitespace inputs never reach the validations

Direct probes (transient `tmp_w984mj_probe_test.exs`, removed after each run, real
sandboxed Postgres):

- `for_update(:approve, %{approved_by: ""})` → `Ash.Changeset.get_attribute/2`
  returns **nil** at validation time.
- `for_create(:create, %{project_name: "   "})` and `"\t\n"` → attribute is
  **nil** at validation time.

Cause: Ash's `:string` type trims inputs and drops empty/blank values before the
changeset carries them, so every blank/whitespace input collapses to the nil arm of
each validation. Consequences for W984ls's court:

1. The `""` clauses in both RequiresApprover modules and in
   ActiveRequiresCertificateSecret are **dead code via the live action path**; the
   court's blank-input assertions pass off the nil arm (identical messages on both
   arms, so they are indistinguishable). M5 (and the M1-first-attempt, identical
   mutation on the nil/blank compound leg) cannot be killed by ANY test going
   through `Ash.Changeset.for_update/for_create` inputs.
2. ValidProjectName's `String.trim/1` branch is **dead code via the live action
   path** — the trim branch would only run if a whitespace-only string reached the
   validation, which Ash's empty-value dropping makes impossible through
   for_create/for_update inputs. M6 is unkillable via the action path. W984ls's
   receipt line "the blank-string clause which the deepening test's `:"   "` case
   does hit" is **wrong** — `"   "` is dropped to nil before the validation sees it
   (probe output above).
3. The court's hostname coverage is genuinely non-vacuous on the binary branch
   (M3/M4' killed, M4 invalid).

Killing M5/M6 would require `Ash.Changeset.force_change_attribute/3` in the court
(bypasses empty-value dropping), not a change to the assertions' inputs.

## Build note (lane-harness finding)

Plain `mix compile` repeatedly failed to recompile a mutated source even with
`touch` (beam mtime stayed older than source). `rm <module beam>` + `mix compile`
recompiles exactly that module. All mutant runs verified beam-mtime-newer than
source before the court run; baselines and restores verified by `cmp` + green court.

## Tree cleanliness

- All 5 subject files `cmp`-identical to /tmp/w984mj snapshots: **OK (5/5)**.
- Final court run on restored tree: **5 passed, exit 0**.
- No probe files remain (`tmp_w984mj_probe_test.exs` removed after each run).
- No commit. Branch unchanged.
- Lane build root `_build-laneW984mj`: **removed** (`rm -rf` succeeded; `ls`
  confirms absent). No fallback needed.
- /tmp/w984mj/ snapshots retained (out-of-tree).

## Standing

PARTIAL_ALIVE: the court's wiring asserts + nil/hyphen/length/self-approval
branches are mutation-hard; its blank/whitespace assertions are masked by Ash
empty-value dropping and cannot kill the corresponding mutants through the action
path (M5/M6 survivors, typed). The residue is a court-strengthening work order
(`force_change_attribute` blank cases), not an auditor judgment call.
