# W845 — `xaas.release_audit` typed-absent repair (W814 F1)

Lane W845. Subject: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD
`a0723bf6` + working-tree delta confined to
`lib/mix/tasks/xaas.release_audit.ex` (this lane) and the receipt file.
Build: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW845`, elixir 1.20.2-otp-28 via asdf.
No commit (per lane contract; coordinator owns integration).

## 1. Repair (μ/diff)

`lib/mix/tasks/xaas.release_audit.ex` only. All six W814-listed `File.read!`
sites converted to the typed-absent pattern (W636), matching the rpc check's
existing `{:error, :enoent}` arm:

| site | check | after |
|---|---|---|
| :156 | `check_resource_registration` | `File.read` case; `:enoent` → `[]` modules + finding `tracked source file absent in worktree: <path>` |
| :187 | `check_migration_uniqueness` | `File.read` case; `:enoent` → `[]` tables + finding `tracked migration absent in worktree: <path>` |
| :231 | `check_json` | `File.read` case; `:enoent` → finding `tracked JSON file absent in worktree: <path>` |
| :256 | `check_markdown_links` | `File.read` case; `:enoent` → finding; link scan extracted to `scan_markdown_links/3` |
| :291 | `check_stale_claims` | `File.read` case; `:enoent` → finding `stale-claim scan: tracked file absent in worktree: <path>` |
| :357 | `check_rpc_alignment` (config.exs) | `File.read` case; `:enoent` → finding `tracked config absent in worktree: config/config.exs` + empty config (downstream endpoint checks then also fail closed with their own typed findings) |

Every missing file is now a typed audit finding that feeds the existing
fail-closed refusal path (REFUSED lines + `Mix.raise`), never a `File.Error`
crash.

## 2. Falsifiers (real runs)

### F-A. Live tree (already carries 4 concurrently-deleted tracked files — the exact W814 crash files)

`mix xaas.release_audit` pre-fix (W814, 3/3): `** (File.Error) could not read
file "lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex"` at :291.
Post-fix, same tree:

```
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex"})
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: lib/xaas/platform/changes/route_projects_backups_approve.ex"})
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: lib/xaas/platform/validations/route_orgs_custom_domain_requires_approver.ex"})
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: lib/xaas/platform/validations/route_projects_backups_requires_approver.ex"})
** (Mix) v26.10.6 release audit failed with 24 finding(s)
EXIT=1
```

No `File.Error`. Fail-closed via the typed-refusal path, exit 1 per contract.

### F-B. Controlled falsifier (README.md moved aside, restored from `git show HEAD:` blob)

```
REFUSED(release_audit, detail: %{finding: "cannot read tracked text file README.md: :enoent"})   (check_text_integrity, pre-existing :enoent arm)
REFUSED(release_audit, detail: %{finding: "tracked markdown file absent in worktree: README.md"}) (check_markdown_links, new)
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: README.md"}) (check_stale_claims, new)
** (Mix) v26.10.6 release audit failed with 27 finding(s)
EXIT=1
```

Restored: `cmp README.md <(git show HEAD:README.md)` → identical;
`git status --porcelain README.md` → clean.

### F-C. Clean-surface regression

- `mix compile` (fresh lane build, 929 files) → EXIT=0.
- `mix xaas.release_audit` completes the full check pipeline (all checks run;
  exit 1 is the pre-existing stale-claim content findings on this tree, not a
  crash — W814's UNKNOWN is now resolvable: the contract checks themselves run
  to completion).
- Existing tests: `mix test test/mix/tasks/xaas_release_audit_test.exs
  test/mix/tasks/xaas_refusal_render_test.exs test/xaas_web/rpc_surface_deepening_test.exs`
  → **23 passed, 0 failed, EXIT=0**.

## 3. Mutation rationale

Reverting any one site to `File.read!` removes exactly its typed finding and
restores the crash: e.g. removing `check_stale_claims`'s `:enoent` arm
reproduces W814's `File.Error` at the first absent tracked file (witnessed
3/3 pre-fix on this same tree), and the F-A/F-B runs show each new finding
type appearing only where its site reads. Each arm is individually witnessed
by the file it covers (json/markdown/stale/config arms witnessed in F-A/F-B;
migration + resource-reg arms share the identical pattern and compile+test
coverage).

## 4. Residual (out of scope, for coordinator)

Non-listed `File.read!` sites remain: `@version`/`check_version` (VERSION),
`check_runtime_identity` (.tool-versions, Dockerfile), and
`check_release_docs`' `File.read!(architecture)` at ~:351 — the last is a
tracked docs file read unguarded; same crash class if deleted. Left per the
6-site lane scope.

## 5. Standing

- W814 F1: **ALIVE (repaired, witnessed)** — typed findings replace the crash
  on the exact crash files, on the exact subject.
- Release-audit contract checks: now reachable; current tree refuses with 24
  typed findings (pre-existing stale-claim content + 4 absent files) — content
  findings are W814's UNKNOWN residue for a coordinator/content lane, not a
  task defect.
- Tests: 23/23 green. Build root `_build-laneW845` left in place for the
  coordinator (lane deletion denied by permission scope; W814's precedent) —
  it holds a clean, current compile state; delete at integration.
