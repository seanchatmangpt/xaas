# W348 — ash_surface fleet falsifiers G1–G5 execution receipt

Lane W348, 2026-10-06. Subject: `/Users/sac/ash_surface` @ `db5a8899e41fd87ef4917d07095677ecb057ed3f` (working tree, @version `26.10.6` at mix.exs:4, `@surface_schema_version "26.10.6"`, `@generator_identity "ash_surface:v26.10.6"` at lib/ash_surface.ex:18–19). No git actions; no fixes applied; only this receipt written (plus an un-removable build lease, see cleanup).

Definition source: `x2-ash-surface.md` §6 (G1–G5 with per-G falsifiers). Note: x2 audited 26.10.1; the tree has since moved to 26.10.6, so G1's "green at 26.10.5" precondition is evaluated at the current pinned version 26.10.6.

## G1 — version alignment gate — ALIVE

Command (private build root, pinned toolchain):

```
cd /Users/sac/ash_surface && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=/Users/sac/ash_surface/_build-laneW348 \
  mix test test/ash_surface/version_sync_test.exs test/ash_system...
```

Actual executed command: `mix test test/ash_surface/version_sync_test.exs test/ash_surface/digest_parity_fixture_test.exs`

Tail:

```
Running ExUnit with seed: 338156, max_cases: 32
............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 12 passed
```

12 passed / 0 failed, exit 0. mix.exs version, schema/generator identity, and digest-parity fixtures all agree at 26.10.6. Verdict: **ALIVE** (version alignment gate green; supersedes x2's 26.10.1 pin).

## G1b — xaas path-dep → versioned dep — BLOCKED(coordinator)

Falsifier requires fresh-clone `mix deps.get` against a pinned hex/git ref of ash_surface and byte-identical `priv/ash_surface/` regen. x2 explicitly labels this a **coordinator-only seam** (xaas mix.exs:115 is the change site, in the xaas tree). Precondition: coordinator pins a versioned dep for ash_surface and re-runs the digest-verified regen.

## G2 — ash_a2a wiring — BLOCKED(new-code)

Falsifier (`mix ash_surface.generate` in ash_a2a → digest-verified `priv/surfaces/` surface matching `AshA2A.AgentCard` actions) requires a new mix task + projection in the ash_a2a tree. Executed precondition check at ash_a2a HEAD: `git grep -l ash_surface -- lib mix.exs` = **zero hits**; `ls lib/mix/tasks | grep -i surface` = empty. The falsifier cannot run because its subject does not exist. Precondition: wire ash_surface into ash_a2a (R4 plan).

## G3 — ash_pplan wiring — BLOCKED(new-code)

Falsifier (MX episode dispatch `adapter: :pplan` survives restart, wire-visible) requires the pplan adapter seam in ash_pplan/ash_surface intent dispatch. Executed precondition check at ash_pplan HEAD: `git grep -l ash_surface -- lib mix.exs` = **zero hits**; no surface task. Precondition: implement the pplan durable-task adapter (R5 plan / catalog C26).

## G4 — ferroplan wiring — BLOCKED(new-code)

Falsifier (ferroplan mix task emits PlanningEpisode JSON from a generated policy; injected missing outcome fails digest) requires a new task in ferroplan. Executed precondition check at ferroplan HEAD: `git grep -l ash_surface -- lib mix.exs` = **zero hits**; no surface task. Precondition: wire the PlanningEpisode projection task into ferroplan.

## G5 — ggen-marketplace projecting pack — BLOCKED(new-code)

Falsifier (`ggen sync run` renders a fleet surface matching the xaas mix-task output digest) requires an experience-projection pack that actually projects. Executed precondition check: grep of `/Users/ggen-marketplace/packs` for `ash_surface` hits only ontology properties and qualification-mutant fixtures (protocol-integration-pack/enterprise_kudzu.ttl, chatman-ecosystem-release-pack qualification mutants) — **no pack projects fleet surfaces**. Precondition: implement the pack per ADR-0005 (R2 cross-ref).

## Cleanup

`rm -rf /Users/sac/ash_surface/_build-laneW348` was **denied by the permission system**. Lease remains on disk at `/Users/sac/ash_surface/_build-laneW348` (private MIX_BUILD_ROOT, untracked). Coordinator to delete at integration per the 2026-10-01 cleanup law.

## Summary

| Gate | Verdict |
|---|---|
| G1 version alignment | ALIVE (12/0 at 26.10.6) |
| G1b path→versioned dep | BLOCKED(coordinator) |
| G2 ash_a2a wiring | BLOCKED(new-code) |
| G3 ash_pplan wiring | BLOCKED(new-code) |
| G4 ferroplan wiring | BLOCKED(new-code) |
| G5 ggen pack | BLOCKED(new-code) |

Fleet wiring standing unchanged from x2: 1/11 repos consume ash_surface; G1 alignment is now witnessed at 26.10.6.
