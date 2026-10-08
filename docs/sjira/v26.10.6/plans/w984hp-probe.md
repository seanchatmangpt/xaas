# W984hp — unclaimed-family probe: refusal/authority ledger export surface

Lane W984hp, 2026-10-07, branch `feat/playwright-surface`, checkout `/Users/sac/xaas`.
NO commit (per dispatch). New file only:
`test/xaas/operations/ledger_export_court_w984hp_test.exs` (10 tests, all pass, exit 0).

## Dispositions per module

| module / task | disposition | evidence |
|---|---|---|
| `lib/xaas/operations/refusal_ledger_export.ex` | partially covered (pre-existing W984cw4 depth court) + **newly courted: `rebuild_digest/0` missing-file (`{:error, :enoent}`) and corrupt-file (`Jason.DecodeError`) paths; `build/0` duplicate-atom merge; `pick_court/2` first-side court retention** | `ledger_export_court_w984hp_test.exs` (real file I/O with save/restore on both the source ledger and the emitted artifact; no mocks) |
| `lib/xaas/operations/authority_ledger_export.ex` | partially covered (pre-existing W603 court) + **newly courted: `merkle_root/1` degenerate cases (64 zeros / single leaf / odd-leaf duplication), `recompute_root/1` top-level malformed, `entry_leaves/1` sort order + content sensitivity** | same file; pure real SHA-256/JCS, no DB, no mocks |
| `lib/mix/tasks/xaas.export_refusal_ledger.ex` | indirectly covered — `RefusalLedgerExport.court/0` (its engine) is fully exercised by the W984cw4 depth court; the `--court` shell branch and its `Mix.shell` output formatting are UNCOVERED (stdout-only surface, no state bearing beyond emit which is covered) | census read this session |
| `lib/mix/tasks/xaas.export_authority_ledger.ex` | covered via W603 court: typed `REFUSED(empty_authority_ledger)` and `REFUSED(invalid_since)` via real `Mix.Task` runs, `--out` determinism. Still UNCOVERED: `REFUSED(invalid_option, ...)` unknown-flag branch (thin OptionParser shell, no state bearing) | census read this session |
| `test/xaas/operations/refusal_ledger_export_depth_test.exs` (W984cw4) | existing court, intact, disjoint from this lane | read-only census |
| `test/xaas/operations/authority_ledger_export_test.exs` (W603) | existing court, intact, disjoint from this lane | read-only census |

Disjointness: W984eu's landed edit (`lib/xaas/operations/refusal_ledger_export.ex`, vacuous
`not is_binary(court)` guard removal, disclosed at line 388 comment) read and respected —
this lane wrote zero edits to `lib/`; the tested binary-court behavior is unchanged.

## Finding (pinned, not repaired)

`AuthorityLedgerExport.recompute_root/1`: the typed `{:error, :malformed_bundle}` contract
guards only the top-level bundle shape (`%{"entries" => list}`). A bundle whose `"entries"`
list contains non-map members crashes with `BadMapError` (`Map.delete/2` on a scalar) —
the typed refusal never fires for malformed entry payloads. Pinned as observed behavior in
the court (assert_raise); a repair would flip that test to `{:error, :malformed_bundle}`.
Non-blocking: the surface is operator/court-facing, inputs are self-produced bundles today.

## Commands (real exits)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hp \
  mix test test/xaas/operations/ledger_export_court_w984hp_test.exs
# → 10 passed, exit 0 (also under a fresh lane build root: full compile, same result)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hp \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
# → [] (mock gate clean)
```

`git status --porcelain docs/cro/artifacts/refusal-ledger-v26.10.{6,7}.jcs.json` → clean
after the run: all real-file mutations (source-ledger duplicate injection, artifact
remove/corrupt) were restored; only the pre-existing `airo-wiring-ledger.md` modification
remains, untouched by this lane.

Standing: court ALIVE on the exact lane subject (uncommitted test file + this receipt).

Lane-lease note: lane build root `_build-laneW984hp` could NOT be removed — the
`rm -rf` Bash call was denied by the session permission system (shutil fallback NOT
attempted: routing around a permission denial is prohibited). Coordinator owns deletion
at integration per the same-checkout fan-out cleanup law.
