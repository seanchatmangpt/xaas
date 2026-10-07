# W984cx2 — ash_pplan OS-20 second-root gate card (v26.10.7 campaign)

Lane: W984cx2 · Date: 2026-10-07 · No commits made (lane constraint honored).
Repo: /Users/sac/ash_pplan (canonical checkout, branch `fix/ggen-verify-header`).

## Subject identity

- Observed gates run at HEAD `110f5d6` ("chore: ignore lane-lease build roots") —
  content-relevant parent `862f0c0` "chore(release): v26.10.7 version bump (W618 via W627)",
  which changed **mix.exs only** (`@version 26.10.3 -> 26.10.7`).
- At compile/test launch HEAD was `862f0c0`; during the run a sibling lane committed
  `110f5d6` (.gitignore only, no source impact). All findings hold for both.
- W609 ran at `6dbd3b0`; W609b receipt **not landed** (checked
  ~/xaas/docs/sjira/v26.10.7/plans/ — no w609b file). The suite gate therefore
  falls to this lane; it was run here and is **incomplete** (below).

## Gate 1 — strict compile, fresh root (ALIVE)

```
MIX_BUILD_ROOT=_build-laneW984cx2 MIX_ENV=test mix compile --force
EXIT=0; grep -ci warning → 0 warnings; 97 apps compiled
```
(Pinned toolchain: elixir 1.20.4-otp-29 / erlang 29.1.1 via ~/.asdf/shims, per repo
.tool-versions. First compile+rerun captured to /tmp/w984cx2-compile.log, full output,
0 warning lines.) Consistent with W609's two fresh roots (0 warnings, both).

## Gate 2 — test suite: INCOMPLETE, red where it completed

Three attempts, all honest-incomplete; log at /tmp/w984cx2-{test,suite2,manufacture}.log:

1. Full `mix test` (fresh root) — **SIGTERM'd at the 30-min harness background cap**
   before the ExUnit summary. Before the kill it had already surfaced 5 failures:
   4 version-pin failures (Gate 2a) + 1 pack-regen court timeout (Gate 2b).
2. Suite minus manufacture_test.exs — also killed at the 30-min cap, no summary
   printed; 3 ReleaseContract failures recorded before kill. Exit 1.
3. `mix test test/manufacture_test.exs` alone — killed at the cap mid-run;
   1 timeout failure (manufacture-durable-chaos) recorded before kill.

Deterministic, non-load-dependent failures (reproduced in two independent runs):

### Gate 2a — version-pin courts: 4 RED (blocking, fix is 3 companion edits)

Commit `862f0c0` bumped **only mix.exs**. The repo's own release-contract courts
correctly refuse the incomplete bump:

| court | site | expects | tree has |
|---|---|---|---|
| AshPPlanTest | test/ash_pplan_test.exs:18 | `version() == "26.10.3"` pin not updated to 26.10.7 | test asserts hardcoded 26.10.3 vs live 26.10.7 |
| ReleaseContractTest | test/release_contract_test.exs:27 | CHANGELOG first entry `26.10.7 ` | first entry still `26.10.3 - 2026-10-03` |
| ReleaseContractTest | :34 | ontology carries packaged version | ontology.ttl still 26.10.3 |
| ReleaseContractTest | :40 | producer lock `release = "v26.10.7"` | lock still `release = "v26.10.6..."` |

(Note: the lock shows `release = "v26.10.3"`; correction —
the lock content printed in the failure shows `release = "v26.10.3"`, i.e. the
lock was not touched by the bump at all.)

### Gate 2b — pack-regeneration courts: timeouts, unresolved

`AshPPlan.ManufactureTest` pack courts spawn the ggen manufacture scripts under a
hard `@tag timeout: 600_000`. Two different scripts timed out at exactly 600 s in
two independent runs (manufacture-dsl in run 1, manufacture-durable-chaos in run 3)
on a machine carrying ~21 concurrent BEAMs (campaign load). The per-test @tag
overrides `mix test --timeout`, so this cannot be raised from the CLI; needs either
a quieter machine or a `@pack_court_timeouts` bump. Not adjudicated this lane —
could be load-induced slowness, not a regression; W609 did not run this file.

## Gate 3 — version-bump / push state

- `862f0c0` **is on origin/main** (verified: `git branch -a --contains 862f0c0` →
  `remotes/origin/main`); W627 did commit and push the bump.
- Local ref `main` is stale (5f10c97) — remote is authoritative; no action taken
  (lane must not move refs).
- Local HEAD branch `fix/ggen-verify-header` = origin/fix/ggen-verify-header,
  plus unpushed `110f5d6` (.gitignore).
- **No `v26.10.7` tag exists** (local; remote not refetched this lane).

## Findings carried forward

- `test/map_update_w609_residual_court_test.exs` (W609's court) is still
  **untracked/uncommitted** in the checkout — W609's ALIVE standing rests on an
  uncommitted file. Needs a commit owner.
- ash_pplan version-bump companion edits still missing, enumerated in Gate 2a:
  test/ash_pplan_test.exs:18, CHANGELOG.md first entry, ontology.ttl version,
  producer-lock `release` line. Not done by this lane (no-commit constraint).

## Verdict

**NOT release-ready for the v26.10.7 tag from this repo's gates.**

- Compile gate: ALIVE (0 warnings, fresh root).
- Suite gate: INCOMPLETE (harness 30-min cap; no ExUnit summary obtained on any run).
- Blocking, deterministic: 4 version-pin court failures from the incomplete
  `862f0c0` bump — three companion edits required before tagging.
- Unresolved: pack-regen 600 s timeouts (likely load; needs one quiet-machine run
  of `mix test test/manufacture_test.exs`).

Standing: **PARTIAL_ALIVE** — compile gate ALIVE on a fresh root at the bumped
HEAD; suite red on the version pins (courts working as designed), suite
completion itself unwitnessed under campaign machine load.
