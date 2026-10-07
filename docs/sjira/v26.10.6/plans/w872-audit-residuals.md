# W872 — `xaas.release_audit` residual unguarded reads (W845 §4 residual)

Lane W872. Subject: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD
`a0723bf6` + working-tree delta confined to
`lib/mix/tasks/xaas.release_audit.ex` (this lane) and this receipt file.
Build: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW872`, elixir 1.20.2-otp-28 via asdf.
No commit (per lane contract; coordinator owns integration).

## 1. Repair (μ/diff)

`lib/mix/tasks/xaas.release_audit.ex` only. All three residual `File.read!`
classes from W845 §4 converted:

| site | class | after |
|---|---|---|
| `check_release_docs` (~:351→ now `append_architecture_finding/2`) | scanned doc | `File.read` case; `{:error, reason}` → typed finding `cannot read docs/claude/diataxis/explanation/architecture-overview.md: <reason>`, audit continues |
| `check_version` (VERSION) | REQUIRED input | new `required_input!/1`: `{:error, reason}` → `Mix.raise("REFUSED(release_audit, detail: %{finding: "required release-audit input VERSION unreadable: <reason>"})")` — loud typed refusal, audit terminates immediately |
| `check_runtime_identity` (.tool-versions, Dockerfile) | REQUIRED input | same `required_input!/1` typed refusal |

Contract split (per lane task): required inputs refuse loudly and terminate;
scanned docs record a typed finding and let the audit complete its refusal
render. The compile-time `@version File.read!("VERSION")` module attribute is
unchanged — its shape is pinned by
`test/mix/tasks/xaas_release_audit_test.exs` ("must derive from the VERSION
file (mix.exs:13 shape)"), and mix.exs is outside lane ownership.

## 2. Falsifiers (real runs)

### F-A. Scanned-doc moved aside (architecture-overview.md → /tmp, restored by mv)

```
REFUSED(release_audit, detail: %{finding: "cannot read tracked text file docs/claude/diataxis/explanation/architecture-overview.md: :enoent"})   (check_text_integrity, pre-existing)
REFUSED(release_audit, detail: %{finding: "broken Markdown link in docs/claude/diataxis/README.md: explanation/architecture-overview.md"})        (link scan)
REFUSED(release_audit, detail: %{finding: "tracked markdown file absent in worktree: docs/claude/diataxis/explanation/architecture-overview.md"}) (check_markdown_links, W845)
REFUSED(release_audit, detail: %{finding: "stale-claim scan: tracked file absent in worktree: docs/claude/diataxis/explanation/architecture-overview.md"}) (check_stale_claims, W845)
REFUSED(release_audit, detail: %{finding: "cannot read docs/claude/diataxis/explanation/architecture-overview.md: :enoent"})                       (NEW — this lane)
** (Mix) v26.10.6 release audit failed with 28 finding(s)
EXIT=1
```

Audit completes to its typed-refusal render; no `File.Error`. Restoration:
the working-tree file (which legitimately differs from HEAD — it was `MM` in
git status) was moved back untouched;
`git status --porcelain` → `MM docs/claude/diataxis/explanation/architecture-overview.md`,
i.e. the exact pre-lane state.

### F-B. REQUIRED input absent (VERSION → /tmp)

Full `mix xaas.release_audit` invocation: `** (File.Error) could not read file
"VERSION": no such file or directory — mix.exs:13` — mix evaluates `mix.exs`
on every invocation, and its own compile-time `File.read!("VERSION")` crashes
before the task loads. That outer crash is loud and fail-closed (exit 1) but
untyped and outside lane ownership (mix.exs). The task-level typed refusal is
therefore witnessed inside one already-running mix process
(`mix run -e`, VERSION renamed after startup):

```
RAISED=Mix.Error
MSG=REFUSED(release_audit, detail: %{finding: "required release-audit input VERSION unreadable: :enoent"})
VERSION_RESTORED=26.10.6
```

Same witness for the other two required inputs:

```
.tool-versions RAISED=REFUSED(release_audit, detail: %{finding: "required release-audit input .tool-versions unreadable: :enoent"})
Dockerfile   RAISED=REFUSED(release_audit, detail: %{finding: "required release-audit input Dockerfile unreadable: :enoent"})
RESTORED tool=true docker=true
```

All three files restored byte-identical (`git status --porcelain VERSION
.tool-versions Dockerfile` → empty).

### F-C. Regression

- `mix compile` (fresh lane build) → EXIT=0.
- `mix test test/mix/tasks/xaas_release_audit_test.exs
  test/mix/tasks/xaas_refusal_render_test.exs` → **12 passed, 0 failed** ×2
  consecutive runs, EXIT=0.

## 3. Mutation rationale

Reverting `append_architecture_finding/2` to the `File.read!(architecture)`
`String.contains?` one-liner removes exactly the F-A finding
`cannot read docs/.../architecture-overview.md: :enoent` and restores the
W814-class crash at the first absent-doc run (witnessed: that finding is the
only new line in F-A's 28 vs. W845-F-A's 24). Reverting `required_input!/1`
at any of the three required-input sites removes exactly that site's
`required release-audit input <path> unreadable` refusal and restores the
`File.Error` crash (witnessed per-site in F-B). No other typed finding
changes under either reversion: F-A's other four lines are W845-era arms
witnessed firing independently of this lane's edit.

## 4. Residual (for coordinator)

- `mix.exs:13` compile-time `File.read!("VERSION")` crashes untyped when
  VERSION is absent at process startup (every mix invocation re-evaluates
  mix.exs) and pre-empts the task's typed refusal in a fresh CLI invocation.
  Untyped-but-loud, fail-closed, outside lane ownership.
- `check_release_docs`' PRD read remains `File.exists?(prd) and
  File.read!(prd)` — exists-guarded (TOCTOU-race only), left as-is.
- Build root `_build-laneW872` left in place: lane `rm -rf` denied by
  permission scope (same as W845); coordinator deletes at integration.

## 5. Standing

- W845 §4 residual: **ALIVE (repaired, witnessed)** — all three residual
  unguarded-read classes now typed (2 refusal classes + 1 finding class),
  falsifiers witnessed on the exact subject.
- `File.Error` crash class in `xaas.release_audit`: no unguarded read
  remains in the task; the only surviving untyped crash is mix.exs startup
  (§4), which is loud and fail-closed.
- Tests: 12/12 green ×2. Build root `_build-laneW872` left for coordinator.
