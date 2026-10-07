# W390 — SYNC-OUTPUT staging for the castle-bridge commit

- Subject: `feat/playwright-surface` @ `d1db2b03` (git archive of branch tip, 2026-10-07)
- Method: reproduced W334's scratch materialization — `git archive feat/playwright-surface | tar -x` → `/tmp/w390-scratch`; copied live `mix.lock`; ran `ggen sync run` (ggen 26.9.28, `/Users/sac/.local/bin/ggen`). Sync EXIT=0, 278s (W334 observed 263s — same ballpark).
- Staging root: `docs/sjira/v26.10.6/plans/w390-sync-output-staging/` (8 files, relative paths preserved).

## Staging manifest (shasum -a 256)

| path | sha256 |
|---|---|
| `lib/xaas/castle.ex` | `26839b9d74bf42e5906a811177e7eb3eb6414049c3015c31438f5fd66f66f6c2` |
| `ggen.lock` | `8a84c6cd8a9e86993e67111e88f8ffa8a573097de403c03d5b126b7236e504d2` |
| `lib/xaas/generated/castle_bridge_contract.ex` | `a22927259a6c0ac6304b560b8bf5596a591548c32bafcb4b3a828840c38872b1` |
| `lib/xaas/generated/castle_bridge_edges.ex` | `e711aed26e58b914183c198ca7b534feb5f4edc4f1737b8102758524e7362e71` |
| `priv/semantic/generated/castle_bridge_shacl.ttl` | `da305dc6af199c70dd3b15c740b479895579fbcf224397ff749ab42893fc49de` |
| `test/xaas/generated/castle_bridge_contract_test.exs` | `7ae748063bf22a7f76d01999108c9351f713b22367efb655f868b00b9804610c` |
| `generated/castle_bridge/innovation.json` | `f1b63296a178fd7ba0819ad7e857355365dc309251406f6a4b579c71ceea109c` |
| `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` | `20e62a877f243ec77d021c4e0346b00ca05e7482741d7ab6ae0f9354ff8b313a` |

## Verdict: DIGEST MATCH

Staged `lib/xaas/castle.ex` sha256 = `26839b9d74bf…` — byte-identical to W334's
sync-output receipt (`26839b9d74bf42e5906a811177e7eb3eb6414049c3015c31438f5fd66f66f6c2`).
Generator output is reproducible across two independent scratch materializations
(W334 and W390). The live-tree `lib/xaas/castle.ex` is a different file
(`eac1e2043ccda9cc4d20e87e19e739d5ce991050feac7aa7307f6aec9f1fdda0`) and must
NOT be used for the castle-bridge commit — take the staged version.

## Coordinator commit instruction (unchanged from W334, now actionable)

Copy the 8 staged files (relative paths preserved) into the checkout before
committing. Do not hand-edit; these bytes are the reproducible sync output.

## Cleanup

`/tmp/w390-scratch`, `/tmp/w390-before.txt`, `/tmp/w390-sync.log` — removed (see below).
