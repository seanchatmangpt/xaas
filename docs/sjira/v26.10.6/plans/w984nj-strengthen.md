# W984nj Court-Strengthening Receipt — W984ls Route-Validations Court (kills M5/M6)

Lane W984nj on /Users/sac/xaas, branch feat/playwright-surface (no branch switch, no
commit, no stash). Date: 2026-10-08. Executes the work order typed in
`docs/sjira/v26.10.6/plans/w984mj-probe.md` (Finding 1 + residue).

Subject: `test/xaas/platform/route_validations_court_w984ls_test.exs` — strengthened
with a Class-5 forced-blank section (5 new tests? no: **4 new tests** — 2 generated
RequiresApprover rows + 1 cert-secret + 1 trim-branch), court now **9 tests**.

## Changed file

- `test/xaas/platform/validations court` (single file): new `force_blank/3` helper
  plus 4 forced-blank tests (flag/project `:approve` `approved_by == ""` arm,
  ActiveRequiresCertificateSecret `certificate_secret_name == ""` arm,
  ValidProjectName `String.trim/1` branch).

## Method — and a typed correction to the work order

W984mj's prescribed `Ash.Changeset.force_change_attribute/3` is **itself masked**:
it re-casts through `Ash.Type.cast_input` with the attribute's default `:string`
constraints (`trim?: true, allow_empty?: false`), so a forced `""` STILL collapses
to nil (probed: `force_change_attribute(cs, :approved_by, "")` → `get_attribute`
nil, `cs.attributes.approved_by = nil`). First court run: **5/9** — all 4 new tests
red on their precondition asserts.

Fix (all gates below use it): inject the raw blank directly into
`changeset.attributes` (past the cast layer) and run the real pipeline. This
survives on `:update` paths (verified: real `:approve` and `:update` refusals with
the typed messages over real sandboxed Postgres) but NOT on `:create`: the create
pipeline re-casts injected attributes at execution time, so even the raw injection
collapses to nil before validations run (probe: injected `"   "` project_name →
validation saw nil → refusal via the `_ ->` nil fallback, not the trim arm). For
the M6 case the receipt's sanctioned fallback applies: build the real `:create`
changeset, force the whitespace, and apply
`RouteProjectsBackupsValidProjectName.validate/3` directly, with wiring
non-vacuity already pinned by the class-4 wiring assert; a pipeline-level refusal
assert on the same changeset is also pinned.

## Kill matrix (before → after)

| # | Subject | Mutation | Before (W984mj) | After (W984nj) |
|---|---|---|---|---|
| M5 | RouteOrgsCustomDomainActiveRequiresCertificateSecret | `is_nil(x) or x == ""` → `is_nil(x)` | SURVIVED | **KILLED** (forced-blank cert-secret test failed; court 7/9) |
| M6 | RouteProjectsBackupsValidProjectName | `String.trim(name) == ""` → `name == ""` | SURVIVED | **KILLED** (forced-whitespace trim test failed; court 8/9) |

## Gates

- Strengthened court baseline: **9 passed, exit 0**
  (`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984nj mix test test/xaas/platform/route_validations_court_w984ls_test.exs`).
- W984ls's original 5 assertions: all green within the 9 (no original test modified).
- Mock gate: `mix run -e 'IO.inspect(...scan_mock_usage(["test", "lib"]))'` → **[]**.
- Restores: both subject validation files `cmp`-identical after each mutant
  (`cmp` OK printed both times); final baseline re-run green.

## Tree cleanliness

- Validation modules: byte-identical to pre-lane state (cmp-verified, both files).
- Only file changed: the court test file (Class-5 section, 4 tests + helper).
- No commit. Branch unchanged. /tmp/w984nj/ snapshots retained (out-of-tree).
- Lane build root `_build-laneW984nj`: rm -rf attempted at close (see final lines);
  python shutil fallback if rm denied.
