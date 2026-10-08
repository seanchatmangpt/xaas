# W984lr — fix W984lp finding: guard e2e seed Sandbox flip behind Mix.env == :test

Date: 2026-10-08 · Lane: W984lr · Branch: feat/playwright-surface · NO commit

## Finding fixed (from w984lp-e2e-falsifier.md)

`e2e/seed-library.exs:26` called `Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)`
unconditionally. Under the W984fw pinned `MIX_ENV=dev` e2e boot, the dev Repo is
not sandbox-pooled, so the flip raised and `W823_SEED_OK` was never reported.

## Diff (2 files, both already carried other lanes' working-tree edits at lane
start; the W984lr hunks are the `W984lr`-commented ones)

### e2e/seed-library.exs

1. Sandbox flip wrapped in `if Mix.env() == :test do ... end` (both Xaas.Repo and
   Xaas.LegacyRepo), with W984lr comment.
2. The script's own cartographer re-assert block changed from `Ash.read_one!`
   to read-first (`Ash.Query.limit(1)` + `Ash.read!` + `List.first`), with
   W984lr comment. Same idempotency repair as DevSeeds below.

### lib/xaas/dev_seeds.ex

`get_or_create_library_checkout/2` and `get_or_create_library_curation/1` changed
from `Ash.read_one!` to read-first (`limit(1)` + `read!` + `List.first`), each
with a W984lr comment.

## Why the extra dev_seeds change (disclosed scope expansion)

After the guard landed, the falsifier progressed past the Sandbox flip but
exposed a second, pre-existing failure: legacy xaas_dev rows (duplicates from
pre-W984fw unsandboxed runs and playwright pin/checkout clicks) made the
get-or-create lookups ambiguous — `read_one!` raises "expected at most one
result but got at least 6/27". The seed could not reach W823_SEED_OK against a
dirty dev database without repairing this. Read-first preserves the documented
get-or-create semantics (deterministic, oldest matching row wins, no new
duplicates created).

## Falsifier (real, from /Users/sac/xaas)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix run e2e/seed-library.exs
→ W823_SEED_OK 10 library_books seeded ; EXIT=0   (was: Sandbox flip raise, EXIT=1)
```
Before-state evidence: first post-guard run failed with
`(Ash.Error.Invalid) expected at most one result but got at least 6`
(dev_seeds.ex:453 checkout lookup), then `at least 27` (seed-library.exs:59
curation re-assert). Both repaired; final run reaches W823_SEED_OK exit 0.

Sandbox-path probe (behavior captured):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix run e2e/seed-library.exs
→ W823_SEED_OK 10 library_books seeded ; EXIT=0
```

The guard is true in :test, so the Sandbox `:auto` flip executed (no Sandbox
error) and the W983f DevSeeds `e2e: true` opt-in admitted the run. Fixtures
landed in xaas_test (acceptable per lane contract: sandbox path exercised).

## Gates

- `Code.string_to_quoted!` on both edited files: SYNTAX_OK.
- Mix compile warnings in dev build output are pre-existing
  (approval_causal_anatomy.ex:144, xaas.airo.compile_shacl.ex:273,
  ash_affidavit signing.ex:312) — not introduced by this lane.
- Mock gate not owed: no test files touched.
- No MIX_BUILD_ROOT used; no lane build-root cleanup owed.

## Standing

ALIVE on subject: branch feat/playwright-surface (uncommitted working tree),
files e2e/seed-library.exs + lib/xaas/dev_seeds.ex as of 2026-10-08.
Falsifier rerun command recorded above; replay = `git diff` of the two
W984lr-commented hunks + the two runs.
