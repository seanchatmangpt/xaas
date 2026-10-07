# W40 — zcode-cli `prepare-release` workflow diagnosis (X5)

- **Date**: 2026-10-06
- **Repo**: `/Users/sac/zcode-cli` @ `7fc62da` (branch `fix/v26926-preview-publish-typed-skip`; 18 dirty files — untouched)
- **Falsifier scope**: why is `Prepare ZCode CLI release` failing 5 consecutive scheduled runs?
- **Standing**: DIAGNOSED, fix NOT applied — requires release decision on `main`
- **Git mutations**: none

## Evidence (real output)

`gh run list --workflow=prepare-release.yml --limit 5`:

```
completed failure 37387373021 2026-10-05T23:14:45Z (7m19s)
completed failure 37231537115 2026-10-04T20:17:35Z
completed failure 37150045904 2026-10-03T20:01:48Z
completed failure 37066543102 2026-10-02T21:23:27Z
completed failure 36931673004 2026-10-01T21:53:51Z
```

Two distinct failure classes, in time order:

### Class 1 (runs Oct 1–4): runtime compatibility failure

Failing step: `Build and validate release candidate` (`bun run release:prepare`). Real log line (runs 37231537115, 37150045904, 37066543102, 36931673004):

```
"code":"CONFIGURATION_ERROR","message":"Select a model before continuing",
"detail":"Model creation failed" ... vendor/zcode.cjs:114
```

The vendored upstream runtime (`vendor/zcode.cjs` from `zcode-runtime.lock.json`) cannot create a model — runtime-smoke court fails. Self-resolved by Oct 5 (newer upstream runtime passes the smoke).

### Class 2 (run 37387373021, Oct 5 — current active blocker): version drift

Failing step: `Prepare release metadata`. Real log:

```
BASE_VERSION: 3.14.3-1
Refusing to prepare 3.14.4-1 because npm latest is 3.14.4-32.
##[error] Process completed with exit code 1.
```

`origin/main` `package.json` version is `3.14.4-32` behind npm `latest`:
- `git show origin/main:package.json` → `"version": "3.14.3-1"`
- `npm view <pkg> version` (latest) → `3.14.4-32`

The daily upstream sync updates `zcode-runtime.lock.json` → `3.14.4-1`, but npm `latest`
is `3.14.4-32` — 31 builds of `3.14.4` were published through some channel outside this
workflow's CAS (`main` never advanced through `3.14.4-2..-32`). The workflow's guard at
`.github/workflows/prepare-release.yml:174` correctly refuses to go backwards. The workflow
is doing its job; the tree is behind npm.

## Root-cause classification

**Version sync drift, not config, not secrets, not test failure.** `main`'s
`package.json` version must advance past `3.14.4-32` before the guard can pass. This is a
release decision (which version to publish next), not a workflow-level fix. No workflow diff
is lawful here — patching the guard to allow downgrades would be an overclaiming hazard.

## Exact unblock sequence

1. Land the in-flight dirty stream on `fix/v26926-preview-publish-typed-skip` (18 files) to `main` first — any version bump commit should not race it.
2. On `main`, set `package.json` `version` to a value that compares > `3.14.4-32` under
   `scripts/release-version.ts` `compareReleaseVersions` (appVersion first, then build):
   either `3.14.4-33` (next build) or `3.14.5-1`. Setting `3.14.4-33` makes the next
   scheduled run's `syncedReleaseVersion` output comparable? Note `syncedReleaseVersion` keeps
   the current build on upstream syncs — so after the bump, the scheduled run sets
   `3.14.4-33`, which IS > npm latest `3.14.4-32` → guard passes, release PR opens.
3. Verify before the next scheduled run (01:30 Asia/Shanghai) with a manual
   `workflow_dispatch` (`kind=upstream`) run and watch the `Prepare release metadata` step.
4. Separately: if the Oct 1–4 "Model creation failed" runtime class recurs, the upstream
   runtime compatibility issue automation (`Summarize runtime compatibility failure` step)
   should open the tracking issue — it did not fire on those runs because
   `.release/runtime-compatibility.json` presence gated it; confirm the artifact exists on
   any recurrence before debugging the workflow.

## Files

- `/Users/sac/zcode-cli/.github/workflows/prepare-release.yml` (read-only, line 174 guard)
- `/Users/sac/zcode-cli/scripts/release-version.ts` (read-only)
- Receipt: this file
