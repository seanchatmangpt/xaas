# W984bk — GraphQL Straggler Removal (receipt)

Lane W984bk, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`.
No commit, per lane contract. Task from W984ay's sweep
(`docs/sjira/v26.10.6/plans/w984ay-code-graphql-sweep.md`), fix-forward.

## Standing

**ALIVE** for items 1 and 2 (template strip + comment deletions, compile EXIT=0,
removal falsifier green). Item 3 (mix.lock) stands **BLOCKED(upstream-dev-deps)**
— `mix deps.get` legitimately keeps the entries; cause measured, no hand-edit.

## Item 1 — `priv/packs/xaas_library_pack/templates/manufacture.ex.eex` (load-bearing)

- BEFORE: 17 graphql lines — `AshGraphql.Domain` at L92; `AshGraphql.Resource`
  at L228, 454, 609, 838, 974; and 5 `graphql do / type :... / end` blocks at
  L260, 486, 644, 868, 991.
- AFTER: zero graphql tokens in the file (`grep -i graphql` → no matches).
  6 insertions(+), 21 deletions(−) vs HEAD.
- Correction to the sweep's count: W984ay recorded "six graphql do blocks";
  the template contains **5** `graphql do` blocks (the sixth graphql element is
  the Domain-level extensions entry at L92). Total removed = 5 blocks + 6
  extension mentions.
- Kept intact: all policies, `json_api`, `admin`, `pub_sub`, actions.
- Guard note for the pins owner: ran the corrected check form
  `mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack --check`
  (w983c/w984g shape) → **exit 4, drifted_count=1**,
  `write lib/mix/tasks/xaas.language...` — precisely:
  `lib/mix/tasks/xaas.library.manufacture.ex`, the same single pre-existing
  drift W983c/W984g recorded (tracked file emits `authorize_if always()` vs the
  ontology render's `actor_present()` floor — owner-pending policy upgrade).
  The tracked task file contains zero graphql tokens, so this strip adds **no
  new drift** to the check surface; pin delta vs the pre-edit verdict is
  **unchanged** (drifted_count 1→1, same file, same cause). No destructive
  regen was run.
- Templates/renders of the manufactured *resource* surface (what the task
  generates at runtime) now carry no graphql; the tracked resource files were
  already graphql-free from W984ao's lib/ sweep.

## Item 2 — 6 stale SPEC-31 comment lines removed

Per W984ay's named sites:

- `lib/xaas/a2a/agent.ex:17` — deleted
  `# SPEC-31 deepening (lane W984l): real GraphQL read surface.`
- `lib/xaas/graphlaw/capability.ex:12` — deleted (same line)
- `lib/xaas/temporal_memory/observation.ex:40` — deleted (same line); `:50`
  line `# the GraphQL read surface is wired over the existing `:read` action.`
  deleted; the surrounding policy-floor comment block kept intact.
- `lib/xaas/coupling/coupling_run.ex:31` — deleted (same line)
- `lib/xaas/generation/projection_record.ex:19` — deleted only the first line
  of the 3-line comment (the "+ the" continuation and policy-floor lines kept
  intact, minus the dangling "+ the").

## Item 3 — mix.lock (absinthe / absinthe_plug / ash_graphql)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bk mix deps.get`
  → exit 0, **mix.lock byte-unchanged** (`git diff mix.lock` empty, 5 graphql-family
  entries remain: absinthe, absinthe_plug, ash_graphql, plus ash_money's/prom_ex's
  optional-dep listings).
- Why they stay (measured, not hand-edited): `deps/ash_authentication/mix.exs:238-239`
  declares `{:absinthe_plug, "~> 1.5", only: [:dev, :test]}` and
  `{:ash_graphql, "~> 1.8", only: [:dev, :test]}` — hex lockfiles converge across
  dependency envs, so upstream dev/test deps pin the cluster. Only an upstream
  change to ash_authentication (or an override) can drop them.
- Remaining graphql mentions in code are W984ay's legitimate-prose class, the
  real non-Ash VKG GraphQL projection (`lib/xaas/semantics/vkg.ex`, AshR2RML —
  not AshGraphql), and removal-documentation comments.

## Verification (real runs, pinned toolchain)

- Compile: `mix compile --force` (pinned asdf toolchain, MIX_ENV=test,
  MIX_BUILD_ROOT=_build-laneW984bk) → **EXIT=0**.
- Removal falsifier: unrestricted `grep -rni graphql` over lib/ config/ test/
  priv/packs (excluding mix.lock + surface_contract descriptions) → zero code
  stragglers; only prose/VKG/removal-doc hits listed above.
- Lane build root `_build-laneW984bk` deleted at integration.

## Replay

```bash
cd /Users/sac/xaas
grep -in graphql priv/packs/xaas_library_pack/templates/manufacture.ex.eex   # expect: no matches
git diff priv/packs/xaas_library_pack/templates/manufacture.ex.eex           # 6 insertions, 21 deletions
grep -rn "SPEC-31 deepening (lane W984" lib/xaas/a2a/agent.ex lib/xaas/graphlaw/capability.ex lib/xaas/temporal_memory/observation.ex lib/xaas/coupling/coupling_run.ex lib/xaas/generation/projection_record.ex | grep -i graphql  # expect: no matches
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix deps.get                        # mix.lock unchanged
```

## Falsifiers attempted (all failed to refute)

- A graphql token surviving in the template or the 6 comment sites → none.
- New drift vs pre-edit check verdict → none (1→1, same cause).
- mix.lock pruned by deps.get → refuted: upstream ash_authentication dev/test
  deps hold the entries; BLOCKED, not UNKNOWN.
