# W291 — ash_pplan patch landed, verdict receipt

Subject: /Users/sac/ash_pplan @ 414a393 (fix/ggen-verify-header), W20 patch landed on top (uncommitted).

## Patches landed (both files verified on disk)

1. `lib/ash_pplan/fond/policy_supervisor/offers.ex` — deleted the compiler-proven-unreachable
   `defp rank(_), do: 9` clause after `defp rank(:strong_cyclic), do: 1` (W20 diff, verbatim).
2. `test/support/examples/qualified_fulfillment/ledger.ex:334` —
   `def undo(%{path: path}, _a, _c, _o), do: (File.rm(path); :ok)`
   (was `(File.rm(path) && :ok) || :ok`, per the W20 receipt's named fix).

## Verification (real runs, /tmp/w291_full_suite*.log)

- **Narrow gate GREEN (decisive)**: `MIX_ENV=test mix test test/manufacture_test.exs`
  → exit 0. The ggen_igniter `--warnings-as-errors` verify — the only code-level blocker W20
  adjudicated — now passes: reactor reconciliation completed (saga_for_each dispatch.ex +
  poll.ex written, engine oxigraph, 10 queries). Both W20 warnings are gone.
- Full suite run 1 (`b9w6cpjs1`): **exit 0** (mix test exit code = green), but the `tail -4`
  pipe clipped the `N tests, 0 failures` summary line — not receipt-grade.
- Full suite reruns 2 and 3 (rerun 3 on fresh root `_build-laneW291b`): both killed at the
  2h background cap before printing a summary — 20-30 concurrent sibling-lane mix test
  beams sustained on this box; runs crawl and are SIGTERMed before completion.
  Contaminated/truncated, no verdict either way. Rerun 3's tail shows only the cap-induced
  SIGTERM shutdown (Dets handle_info EXIT trace), no test failures printed up to the kill.
- Narrow gate re-confirmed: run 1 was green on the same tree earlier in this session.

## Pins warning (P0-3)

Both patches are **uncommitted working-tree modifications** on branch `fix/ggen-verify-header`
@ 414a393. W20's plan file is untracked (`??`). **Do NOT advance any xaas pin to ash_pplan
until these two files are committed + pushed** — a pin advance would leave the verify fix
behind and re-open the --warnings-as-errors blocker.

## Recommendation

Commit the two files + W20/W291 receipts on `fix/ggen-verify-header`, then the pins advance
is lawful. Coordinator owns commits (W291 lane owns no git).

## Reproduction

```
cd /Users/sac/ash_pplan && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix test test/manufacture_test.exs   # exit 0, ggen_igniter verify passes
```
