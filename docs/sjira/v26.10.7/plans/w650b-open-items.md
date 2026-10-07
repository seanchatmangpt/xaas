# W650b — open-items register work-off (v26.10.7 fleet seal)

Lane W650b. Date: 2026-10-07. Repo: `/Users/sac/xaas` (canonical checkout,
branch `feat/playwright-surface`, HEAD `56325fa5` at lane start). No commit
made, per directive. Receipt only.

## Task

Work W650's open-items register (§8 of `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md`):
check each item's gating receipt, close what closure evidence now exists,
execute final witnessing runs where the evidence is still missing, update the
DRAFT receipt in place.

## Per-item closure table

| # | item | state at lane start | evidence found this lane | new state | standing |
|---|---|---|---|---|---|
| 1 | W984dj census re-witness | DRAFT — receipt pending | `plans/w984dj-census-verify.md` absent on disk (find across `docs/sjira/`, git log --all, grep: zero hits). W984dj never landed. | Confirming census executed by this lane at HEAD `56325fa5` — **CLOSED** | **ALIVE at HEAD** |
| 1b | Incorporate closure into DRAFT receipt | — | `_CLOSURE_RECEIPT.md` edited in place (§1 + §8 rows 1/1b + standing summary/seal verdict) | **DONE** | — |
| 2 | W638 Wasmex host commit | landed-uncommitted | `git log --all --grep="w638" -i` → only `24172283` (unrelated v26.10.6 blanket). `git status`: `lib/xaas/semantics/graphlaw_wasm.ex`, `priv/graphlaw.wasm{,.sha256}`, court files all still **untracked**. No commit exists. | **commit-pending confirmed** — DRAFT(W638-commit-pending) flag kept | PARTIAL (court ALIVE per `w638-wasmex-host.md`: 8/8 legs, ×2 roots) |
| 3 | W640 differential court | no landed receipt | `w640-differential-shacl.md` absent (only `v26.10.6/plans/w640-os21-verify.md`, a different item). Unification receipt §7 still DRAFT-PENDING, zero agreement rows. | **DRAFT(W640-differential-pending) kept** | PARTIAL — unification stays UNKNOWN→PARTIAL |
| 4–10 | ash_surface / ggen-marketplace version commits, projection staleness, ash_graphlaw re-render, affidavit/ferroplan pack migrations, xaas_dev ordering defect | BLOCKED/OPEN | Not in this lane's scope (external repos / design follow-ups); states re-read unchanged | unchanged | as receipted |

## Confirming census witness (item 1) — real run output

Command (pinned toolchain, fresh lane build root, full from-scratch compile):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650b \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- **Run 1**: `Result: 1351/1352 passed, 1 excluded. Failed: 1 test` —
  `test/eu_ai_act/counterfactual_test.exs:597`, `System.do_port_byte` port
  crash under 32-way async contention.
- Classification: reran the file in isolation with the census tags —
  `Result: 26 passed` (exit 0). Environment flake, not a regression.
- **Run 2 (full census, confirming)**: `Result: 1352 passed, 1 excluded`,
  `MIX_EXIT=0`. **ALIVE-PASS at HEAD `56325fa5`.**
- W633 attribution gap: closed by replacement — the 1352 line now cites a
  witnessed run at the exact seal HEAD instead of the never-attributed
  cf228da6 window.

## Receipt edits made (no commit)

`docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md`, in place:
- §1 witness table: cf228da6 row marked gap-closed-by-replacement; HEAD
  confirming-witness row added citing this receipt.
- §1 DRAFT(pending-W984dj) paragraph → **CLOSED (W650b)** paragraph
  (W984dj absent; HEAD witness; flake disclosure; ALIVE at HEAD).
- §8 rows 1 and 1b → CLOSED / LANDED citing this receipt.
- Standing summary + seal verdict: item 1 closed; remaining DRAFT blockers
  narrowed to items 2 (W638 commit) and 3 (W640 differential).
- Concurrent-lane note: W650c edited the file mid-lane (v2 status line, tag
  re-verification table, W628b row); W650b edits applied on top, no conflicts.

## Standing

- Census: **ALIVE at HEAD `56325fa5`** (1352/0/1, exit 0, fresh root).
- W638 host: PARTIAL — court ALIVE (8/8 ×2 roots), commit-pending.
- W640 differential: PARTIAL — no landed receipt; agreement matrix absent.
- Items 4–10: unchanged from receipted states.

## Replay

```
git -C /Users/sac/xaas rev-parse HEAD                      # 56325fa529927d317d551da4dd62e436296edf06
ls /Users/sac/xaas/docs/sjira/v26.10.7/plans/w984dj-census-verify.md   # absent
ls /Users/sac/xaas/docs/sjira/v26.10.7/plans/w640-differential-shacl.md # absent
git -C /Users/sac/xaas status --short -- lib/xaas/semantics/graphlaw_wasm.ex  # ?? untracked
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=_build-laneW650b mix test test/eu_ai_act \
  --include eu_ai_act --exclude eu_ai_act_open_gap         # 1352 passed, 1 excluded
```

Lane build root `_build-laneW650b` deleted after receipt per the fanout
cleanup law (coordinator may re-create by rerunning the court).
