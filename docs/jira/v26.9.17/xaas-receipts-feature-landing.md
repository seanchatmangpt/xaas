# XaaS Receipts Feature Landing — land the live author's staged work without reverting the atom fix

## Summary

A live author (the receipts/lease seam work: `mix xaas.receipts` task,
receipts read path, lease/epoch_reactor changes + tests) staged work in the
xaas main checkout mid-wave. The ledger-closure agent deliberately refused to
race their index. Hazard: `git status` shows the controller/test files as
`MM` — a bare `git commit` without re-adding
`lib/xaas_web/controllers/execution_fabric_controller.ex` and its test would
COMMIT AWAY the atom-table DoS fix (`32b5ba1`).

## Status

DONE — landed atomically as `15c287a` on `feat/execution-actuation-fabric`
(2026-09-17 ~15:10, by the post-outage continuation session).

## Scope

1. Confirm the author's work is complete/stable (their staged set unchanged
   across two observations; no active mtime/reflog movement).
2. Re-stage the controller + test (the `MM` files) together with the staged
   feature set; commit atomically on `feat/execution-actuation-fabric`
   (shared-lock discipline for xaas git ops).
3. Full court after landing: `mix compile --force --warnings-as-errors`,
   `mix test --only ultracode`, `mix test` — expect the r6 baselines or
   better (648+ passed / 0 failures), plus whatever suites the receipts
   feature adds.
4. Update `HANDWRITTEN.md` (the `mix xaas.receipts` row already anticipates
   this — reconcile rows to the final file set).
5. Receipt: staged-set inventory, commit SHA, court exits.

## Key Invariant(s)

- The atom fix (`32b5ba1` content) must be an ancestor of the landed commit
  — verify with `git log --oneline` + a grep for `String.to_existing_atom`
  in the landed tree.
- Never force, never push; one atomic commit per semantic unit.

## Relationship to Existing Work

- `ledger-closure.md` (the refusal + MM hazard);
  `boundary-xaas.md` (atom fix proven by 648/0 court).
- The receipts read path feeds `affidavit-followup-binding.md`.

## Falsifiers / What Would Defeat This

- Post-landing tree loses the atom fix (reverted by the MM trap).
- The receipts feature lands without its tests green.

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | queued | xaas feat/execution-actuation-fabric @ 6ff1a32 (MM hazard live) | atom fix court 648/0 at 32b5ba1 | author-quiescence → atomic land → full court |
| 2026-09-17T15:10-07:00 | DONE | xaas feat/execution-actuation-fabric @ 15c287a | quiescence: reflog unchanged since 12:08, porcelain identical across 2 observations (14:36/14:40); courts BEFORE land: `MIX_ENV=test mix compile --force --warnings-as-errors`→0, `mix test --only ultracode`→17/0, `mix test`→688/0 (baseline 648); atom-fix invariant: `git merge-base --is-ancestor 32b5ba1 HEAD`→0 + 2×String.to_existing_atom in tree; land = one atomic commit, 51 files +3879/−473 (incl. wave-5 actuate seam, token machinery, plugin de-hooking, VERSION 26.9.17); plugin regenerated + installed 26.9.17 (0 hooks, enabled), old 26.8.21 cache dir removed | push/PR decision (operator act 6 family) |

Deviation recorded: strict compile ran in MIX_ENV=test, not dev — the live
dev server (pid 7796, `mix phx.server` from this tree) watches `_build/dev`
through the code reloader; a dev-env force compile from a second process is
the exact wave-4 crash mechanism. Same source, same `--warnings-as-errors`
flag, isolated build path.
