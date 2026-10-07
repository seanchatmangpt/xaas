# W984x — Mutation-Hardening Wave 2 (REPAIRED rows, newest repair lineage)

Lane: W984x, xaas v26.10.6 campaign, 2026-10-07. Subject: branch
`feat/playwright-surface`, working tree (uncommitted), pinned asdf toolchain
(`PATH=$HOME/.asdf/shims:$PATH`), `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW984x` (fresh root, 450 MB, compile exit 0 before
any mutation).

Task (W981p pattern, receipt `w981p-open-gap-mutation-hardening.md`): mutation-kill
the 4 REPAIRED rows flipped by W983p (`w983p-register-flips.md`) whose repair
lineage is newest (landed this session) and whose courts were witnessed but
never mutation-killed. Confirmed fresh: none of W731 / W750-G2 / W765 / W802
carried a mutation-kill citation in w983p/w983d/w982t before this lane
(w983d explicitly discloses "No mutation kill performed").

Method: file-swap only — snapshots at `/tmp/w984x/*.orig` with pre-mutation
md5s (`/tmp/w984x/md5s.txt`); mutate production file, run court ×1, restore
from snapshot, md5-verify, run court restored ×1. No stash. Real tails recorded.

## Row × mutation verdict table

| Register row | Court (file) | Mutation (minimal production change) | Mutated run | Restored run | Verdict |
|---|---|---|---|---|---|
| **W731 GAP(graphlaw-limits-not-enforced)** — REPAIRED per w983p (SPEC-10 `Xaas.Graphlaw.LimitGate` + byte-limit seams w981k) | `test/xaas/graphlaw_limit_gate_test.exs` (10 tests) | deleted the depth-gate `LimitGate.enforce/2` call in `Xaas.Bridges.Graphlaw.assess/2` (`lib/xaas/bridges/graphlaw.ex` ~:83), reverting to pre-SPEC-10 ungated `do_assess` | **9/10, 1 RED** — exactly `gate refuses a depth-65 claim at the bridge seam` fails: `refusal.code` came back `:host_not_started` (claim reached the engine) instead of `:limit_exceeded` | **10/10** | **KILL** |
| **W750-G2 (detect/1 blind to upsert-overwritten regressions)** — REPAIRED per w983p (SPEC-14, commit `fd471722`) | `test/xaas/operations/capability_liveness_deepening_test.exs` (11 tests) | `SetPreviousStatus.capture_previous_status/1`: `change_attribute(changeset, :previous_status, prior)` → no-op (never sets `previous_status`), reverting to pre-SPEC-14 in-place overwrite blindness | **9/11, 2 RED** — including the W968c visible-diff court (line 189: `detect/1` returned `[]` where the ALIVE→REFUTED in-place regression is now reported); second failure the sibling in-place court, same root cause | **11/11** | **KILL** |
| **W765 GAP-D (FreezeWindow runtime consumer gates)** — REPAIRED per w983p (SPEC-18, commit `5a853130`) | `test/xaas/governance/freeze_window_active_gate_test.exs` (5 tests) | deleted `forbid_if({Xaas.Governance.Checks.FreezeWindowActive, []})` from the `:approve` bypass in `lib/xaas/governance/approval_environment_promote.ex` (:47), reverting to pre-SPEC-18 ungated promote | **4/5, 1 RED** — exactly `2: same refusal + time-bounded lift on ApprovalEnvironmentPromote :approve` fails: in-window `:approve` no longer returns `Ash.Error.Forbidden` | **5/5** | **KILL** |
| **W802/W819 graphql-http-surface** — REPAIRED per w983p (SPEC-30 mount) — **row since superseded, see disclosure 1** | `test/xaas_web/graphql_http_surface_test.exs` (15 tests) | removed the `Absinthe.Plug` forward from the `/api/graphql` scope in `lib/xaas_web/router.ex` (~:301-307), leaving an empty scope (surface unmounted) | **1/15, 14 RED** | **BLOCKED, moot** — court file deleted from tree mid-lane by the operator-directed removal (disclosure 1); could not run restored | **KILL (mutated leg witnessed); row standing now OUT-OF-SCOPE per disclosure 1** |

## Honest disclosures

1. **Concurrent operator-directed GraphQL removal (W984ao/ap/aq) superseded the
   W802 row mid-lane.** Sequence: W802 mutated run executed ~10:55 (real,
   witnessed 1/15) against the then-present court; restore md5-verified
   (`8a1d2d948ec4795f77a513e1592cbdc0`); the restored leg was then BLOCKED
   because lanes W984ao/W984ap/W984aq removed the GraphQL surface
   (`lib/xaas/graphql_schema.ex` and all 3 graphql courts staged `D`,
   router `/api/graphql` scope removed, register row flipped
   `OUT-OF-SCOPE(removed-by-operator, 2026-10-07)` per
   `w984aq-graphql-docs-removal.md`). Consequences: (a) the W802 mutation
   evidence stands as a kill on the pre-removal REPAIRED row, (b) no
   VACUOUS-GUARD finding — the court demonstrably fires, (c) the row's
   standing is no longer REPAIRED and is not this lane's call; w984aq owns
   the flip.
2. **Concurrent lane edit to `lib/xaas/governance/approval_environment_promote.ex`.**
   After my md5-verified restore (matched `9f34656289cc5ef67fc585b195ae3ea5`),
   another lane's in-flight edit landed; file md5 moved to
   `881f138de382bc4e7f8179c28f017919`. Verified the mutation-relevant content
   is intact: `forbid_if({Xaas.Governance.Checks.FreezeWindowActive, []})`
   present at line 47. Not my edit; not reverted by me. Tree-wide: my four
   mutation sites are all in pre-mutation state except this one file, which
   differs from my snapshot only by the concurrent lane's diff.
3. No VACUOUS-GUARD findings this wave. All four courts fired under mutation:
   the W983p REPAIRED flips are non-vacuous on their killing courts.
4. Baseline compile under the lane build root: exit 0 before any mutation;
   every restored leg ran on a compiling tree.

## Standing

- W731, W750-G2, W765: **KILL verified, REPAIRED standing confirmed
  (non-vacuous)** — mutation-kill citations now exist for all three rows via
  this receipt.
- W802/W819: kill evidence witnessed on the pre-removal row; row since flipped
  `OUT-OF-SCOPE(removed-by-operator)` by W984aq (not a VACUOUS-GUARD; no
  re-opening from this lane).
- Register totals: unchanged by this lane (0 re-openings; W802's flip owned by
  w984aq). No lib edits retained from this lane — every mutation restored and
  md5-verified (except disclosure 2's concurrent edit, which is not mine).
- Lane build root `_build-laneW984x` left in place for the coordinator (not
  deleted; per-lane lease per campaign discipline).
