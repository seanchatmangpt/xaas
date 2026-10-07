# W346 — Operator decisions OS-2 / OS-3 / OS-6: typed lift memos

- **Date**: 2026-10-06
- **Lane**: W346, campaign v26.10.6
- **Standing**: MEMOS READY — operator-gated, zero code changes made anywhere
- **Repos touched**: none (read-only on zcode-cli, ggen, ggen-marketplace)

---

## OS-2 — zcode-cli main version bump

**Current state (real reads)**

- `/Users/sac/zcode-cli/package.json`: `"name": "zcode-app-cli"`, `"version": "3.14.3-1"` — matches the `origin/main` value w40 quoted.
- `/Users/sac/zcode-cli/.github/workflows/prepare-release.yml` ("Prepare release metadata" step, ~line 174): captures `BASE_VERSION=3.14.3-1` before any increment; the scheduled upstream sync then bumps `PACKAGE_VERSION` to `3.14.4-1` and runs:
  `compareReleaseVersions(PACKAGE_VERSION, LATEST_VERSION) > 0` → refuses with
  `Refusing to prepare 3.14.4-1 because npm latest is 3.14.4-32.` (exact log line in w40, run 37387373021).
- Comparison function: `/Users/sac/zcode-cli/scripts/release-version.ts` `compareReleaseVersions` — compares appVersion triple then build. `3.14.4-1 < 3.14.4-32` → exit 1. This Class-2 failure is behind all 5 consecutive scheduled failures (w40 run list 36931673004 → 37387373021, Oct 1–5).
- **Live npm check (network UP)**: `npm view zcode-app-cli@latest version` → `3.14.4-32`; recent publishes: `3.14.4-29 … -32`. `main` never advanced through `3.14.4-2..-32` — the tree is behind npm.

**Proposed bump: `3.14.4-33`** (one greater than npm latest; compares > under `compareReleaseVersions`)

Exact one-line change on `main`:

```diff
--- a/package.json
+++ b/package.json
@@
-  "version": "3.14.3-1",
+  "version": "3.14.4-33",
```

**What unblocks**: `compareReleaseVersions("3.14.4-33", "3.14.4-32") > 0` → true; npm "already published" check passes (`3.14.4-33` unpublished); the release PR for `3.14.4-33` opens on the next scheduled run (01:30 Asia/Shanghai) or a manual `workflow_dispatch` (kind=upstream); the 5-failure streak ends. Per w40 step 3, verify with a manual dispatch before the next scheduled run.

---

## OS-3 — ggen tag v26.10.6

**Current state (real reads)**

- `/Users/sac/ggen/Cargo.toml` line 2: `version = "26.10.6"` — WP-D workspace bump content landed locally.
- `git -C ~/ggen tag --list 'v26.10*'` → `v26.10.0`, `v26.10.5` — no `v26.10.6` tag exists.
- `git -C ~/ggen log --oneline -3` (HEAD of `feat/v26.10.5-release-cut`): `000bffb8f` (CA1 closure), `8ac246add` (MU3 mutation sample), `03942743a`.
- `/Users/sac/ggen/docs/CHANGELOG.md` line 7: `## [26.10.6] — v26.10.5 Convergence Closure (2026-10-06)` section present, including the workspace bump entry.
- Local branch is **29 commits ahead of `origin/main`** (`git log origin/main..HEAD | wc -l` → 29); `git branch -r --contains 000bffb8f` → **empty** — bump HEAD is on no remote branch.

**Preconditions for tagging — status: BLOCKED (precondition 1 fails)**

1. **WP-D bump commit landed on main — FAILING.** The bump content exists only on local `feat/v26.10.5-release-cut`, unpushed (no remote branch contains `000bffb8f`).
2. **CI green on the bump head — UNVERIFIABLE until (1).** `gh run list` auth works (remote `seanchatmangpt/ggen`): recent main runs are `v26.9.28 lock sync` schedule successes plus one WD CS2 exact-head court failure — none cover the bump commit.
3. Operator tags after 1+2.

**Exact operator command sequence** (after the branch is pushed and merged to `main`):

```bash
cd /Users/sac/ggen
git checkout main && git pull
git log -1 --format='%h %s'   # must be a merge containing 000bffb8f
gh run watch                   # CI green on new main head
git tag -a v26.10.6 -m "v26.10.6 - v26.10.5 Convergence Closure"
git push origin v26.10.6
```

**Readiness**: **BLOCKED** — the WP-D bump commit (`000bffb8f` head) is local-only, 29 commits ahead of `origin/main`, on no remote branch; CI-green-on-bump is UNVERIFIABLE until push+merge.

---

## OS-6 — frozen ggen pin v26.8.11

Restated (3 lines, per r2 §4.4 — user-only gate):

- `ggen-marketplace` `marketplace.toml [ggen]` pins `version = "v26.8.11"` @ `402cecdff8784767eb9f26e235d87c759610c066`; the 2026-10-05 pin-bump request was typed-REFUSED `BLOCKED:pin-bump-user-gated`.
- Lifting requires the user alone to approve and execute the pin bump per `r2` §4.4 — staged procedure already written at `docs/context/ggen-pin-bump.pending.md`; no lane may edit the pin.
- Dependent work (court identity re-qualification, `w80` re-pin render verification) may be staged but not executed until the user lifts the gate.
