# W616b Receipt — Refusal Ledger Commit Lane (v26.10.7 campaign)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` — commit **d95defa2**
  (`feat(operations): W616b refusal ledger commit — export module + mix task`)
- **Standing**: **ALIVE** — all gate legs witnessed on the exact committed subject bytes
- **Mode**: CONSTRUCT (lane W616b, coordinator-delegated commit)

## Landed (2 paths in d95defa2)

1. `lib/xaas/operations/refusal_ledger_export.ex`
2. `lib/mix/tasks/xaas.export_refusal_ledger.ex`

## Already landed elsewhere (disclosed collision)

The other 2 of the 4 contract paths —
`docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json` and
`docs/sjira/v26.10.7/plans/w616-refusal-ledger.md` — were committed mid-gate by
lane W629's receipts-corpus commit **6222135e** ("docs(sjira): W629 receipts
corpus commit — 32 confirmed done-lane receipts..."). Verified: committed blobs
in 6222135e are **byte-identical** (sha256 `6d1e4b89fa90c748...34ea7` and
`ca39cd284598e230...ed163`) to the on-disk bytes I gated and verified this
session. No duplication commit made; re-committing would have been a no-op.

## Gates witnessed (real output)

- **Freshness**: all 4 paths mtime-stable ≥15 min before gating (newest
  1791403035 at start; artifact untouched through the gate).
- **Strict compile**: `mix compile --force` with
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW616b`,
  fresh build root — **EXIT=0** ("Generated xaas app").
- **Real regeneration run ×2**: `mix xaas.export_refusal_ledger` (run 1) and
  with `--court` (run 2). Both: `emitted:
  docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`, replay **MATCH** at
  content digest sha256 `203fee7cd4ec9d7c...bea8f59` — this is the **JCS
  canonical content digest** the module computes (matches the W616 receipt's
  cited digest), not the raw file-byte hash.
- **Byte-identity proof**: snapshot → rerun → `diff` — **BYTE_IDENTICAL**;
  file-byte digest `6d1e4b89fa90c748...34ea7` stable across runs and equal to
  the committed blob in 6222135e.
- **Court leg (run 2)**: `court: OK (fake-variant mutation refused:
  REFUSED_FAKE_W616_NO_COURT, reason: :court_missing)` — the ledger is not
  vacuous.
- **Disk re-read after commit**: `git show 6222135e:<path>` shasum == on-disk
  shasum for both docs paths.

## Gate-command deviation (disclosed)

Task contract said `mix xaas.export_refusal_ledger --out /tmp/w616b-ledger.json`.
The task **does not implement `--out`** — `Mix.Tasks.Xaas.ExportRefusalLedger.run/1`
accepts only `--court` and emits to the fixed canonical path
(`out_relpath/0` = `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`);
the stray flag is silently ignored. The byte-identity gate was satisfied with
the snapshot→rerun→diff idiom instead (equivalent and stronger: real diff of
two independent emit runs). No code change made for this — the fixed path is
the designed contract.

## Verification ladder

narrow (blob-vs-disk shasum) → unit-level (emit + digest replay ×2) →
court leg (mutation refusal) → byte diff between independent runs.

## Digest tails (re-read at receipt time)

- Content digest (JCS, replay MATCH ×2): `203fee7cd4ec9d7c68d4621469cac248c`
- File-byte digest: `6d1e4b89fa90c748f848ced8d1adcae4bbee9fd608476f035c0b62f91334ea7`
- Receipt-byte digest: `ca39cd284598e2302878dba1afc86c874b1f2abe8d419baf0eefd56daebed163`

## Exclusions / next hops

- Lane build root `_build-laneW616b` left in place per lane contract (coordinator
  deletes at integration).
- `--court` leg run only in run 2; run 1 was plain emit.
- Two untracked depth-test files appeared in the tree mid-gate
  (`test/xaas/operations/refusal_ledger_export_depth_test.exs`,
  `test/xaas/igniter/refusal_code_policy_depth_test.exs`) — another lane's
  in-flight work, not touched by this lane.
