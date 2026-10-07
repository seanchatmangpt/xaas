# W632 — Lockfile convergence (checklist item 1, v26.10.7 fleet seal)

Date: 2026-10-07 · Lane W632 · repos `/Users/sac/xaas` + `/Users/sac/wasm4pm`

## ~/xaas — ALIVE (committed + pushed)

- **mix.lock**: already converged. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  mix deps.get` → **EXIT=0**, **zero diff** on `mix.lock` (resolved set
  unchanged; hex advisory warnings surfaced, no resolution change).
- **Stale GraphQL entries — persist, lawful**: `absinthe`, `absinthe_plug`
  (1.5.10), `ash_graphql` (1.12.0) remain in `mix.lock` after W984ao removed
  them from `mix.exs`. Cause (confirmed on disk): `deps/ash_authentication/mix.exs:238-239`
  declares `{:absinthe_plug, "~> 1.5", only: [:dev, :test]}` and
  `{:ash_graphql, "~> 1.8", only: [:dev, :test]}` — the resolver keeps them
  for the dev/test env. Matches the W984bk finding. Removal requires
  ash_authentication dropping its dev deps, not a lockfile edit.
- **Commit `56325fa5`** on `feat/playwright-surface`: `VERSION` 26.10.6→26.10.7
  (W617, owner-complete per `w617-version-bump.md`) + `CHANGELOG.md`
  v26.10.7 section (W619, owner-complete per `w619-changelog-backfill.md`),
  committed via explicit pathspec `-- VERSION CHANGELOG.md` so 11 other
  lanes' staged files were not swept in. Message file:
  `docs/sjira/v26.10.7/plans/w632-commit-msg.txt`.
- **Push**: fast-forward `cab79623..56325fa5` to
  `origin/feat/playwright-surface` (also advanced origin over 4 pre-existing
  local commits from lanes W615b/W616b/W604b2 — fast-forward only, no force).
- **Gate**: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW632 mix compile --force`
  → **EXIT=0** ("Generated xaas app"; warnings only, all pre-existing:
  `refusal_ledger_export.ex` type warning, actuation/SHACL warnings).
  First attempt failed on a **transient mid-write snapshot** of another
  lane's in-flight `lib/xaas/semantics/graphlaw_wasm.ex` (unclosed delimiter
  at :80; file was complete and parsing on disk minutes later) — compile-freeze
  SLA event, not session-introduced; second run passed.

## ~/wasm4pm — ALIVE (committed + pushed)

- W618 bumped `package.json` 26.10.6→26.10.7 (uncommitted in-tree).
- **Cargo.lock**: verified already converged — `cargo metadata --format-version 1`
  **EXIT=0**, **zero diff** (`LOCK_CLEAN`). No `package-lock.json` exists
  (no npm lockfile surface in this workspace).
- **Commit `986e5daa1`** on `fix/v26.9.30-ci-fmt-tsc`: `package.json` only,
  explicit pathspec. Untracked `crates/eu_gate/` left alone (out of scope,
  per W601p precedent).
- **Gate**: `cargo check --workspace` → **EXIT=0** on pinned
  nightly-2026-04-15 (`rust-toolchain.toml`); deprecation warnings only.
- **Push**: fast-forward `5925d4726..986e5daa1` to
  `origin/fix/v26.9.30-ci-fmt-tsc`. (First push attempt used a nonexistent
  `--ff-only` push flag → usage error, EXIT=129, nothing pushed; retried
  plain push — git push is fast-forward-only by default.)

## Standing

| surface | standing |
|---|---|
| xaas mix.lock convergence | ALIVE |
| xaas VERSION 26.10.7 seal commit 56325fa5 | ALIVE (pushed) |
| wasm4pm package.json 26.10.7 commit 986e5daa1 | ALIVE (pushed) |
| wasm4pm Cargo.lock | ALIVE (converged, unchanged) |
| xaas release_readiness | BLOCKED(release_audit) — inherited from W617: 19 typed audit findings, tag `v26.10.7` absent. Out of this lane's scope. |

## Falsifiers

- `git show 56325fa5 --stat` does not contain VERSION + CHANGELOG.md, or
  `cat VERSION` on origin tip ≠ 26.10.7.
- `git show 986e5daa1 --stat` does not contain package.json, or wasm4pm
  origin tip package.json version ≠ 26.10.7.
- `cd ~/xaas && mix deps.get && git diff --exit-code -- mix.lock` nonzero
  (drift reappeared).

## Hygiene

- `_build-laneW632` deletion **denied by harness permissions** (same as W617);
  left for coordinator cleanup per campaign law.
- No stash used; explicit pathspec commits only; no force push.
