# W334 — HEAD drift witness (DoD 4: clean-tree-after-generation, witnessed in scratch)

- Subject: `feat/playwright-surface` @ `d1db2b03` (git archive of branch tip, 2026-10-06)
- Method: scratch materialization at `/tmp/w334-scratch` via `git archive | tar -x`
  (repo untouched). Copied live `mix.lock` (byte-identical to HEAD's). Ran
  `ggen sync run` (ggen 26.9.28 at `/Users/sac/.local/bin/ggen`; CI leg
  `root-sync-drift` in `.github/workflows/closure-gates.yml` builds from
  `GGEN_SHA` — local identity differs from CI's pinned build, noted as caveat).
  Hashed all files before/after (`find -print0 | sort -z | xargs -0 shasum -a 256`),
  diffed.
- Sync: EXIT=0, 263s; produced `ggen.lock` + `.ggen-v2/receipt.json` (actuator
  `ggen@26.9.28`).

## Verdict: HEAD FAILS its own root-sync drift condition

Tracked-worthy drift set at HEAD (files sync writes that are NOT gitignored —
confirmed via `git check-ignore` against HEAD's `.gitignore`):

Modified by sync:
- `lib/xaas/castle.ex` — HEAD `667498c61044c192ba14a4a401d23072e49a521f60bc7baf4241126a4d602bdd`
  → sync output `26839b9d74bf42e5906a811177e7eb3eb6414049c3015c31438f5fd66f66f6c2`

New (generated, not at HEAD):
- `ggen.lock`
- `lib/xaas/generated/castle_bridge_contract.ex`
- `lib/xaas/generated/castle_bridge_edges.ex`
- `priv/semantic/generated/castle_bridge_shacl.ttl`
- `test/xaas/generated/castle_bridge_contract_test.exs`
- `generated/castle_bridge/innovation.json`
- `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`

Unignored side artifacts sync also minted (coordinator decision needed:
gitignore or commit; CI's `git status --porcelain | grep -v '^??'` test would
not fail on these, but a clean-tree gate would):
- `.ggen/keys/{.gitignore,signing.key,verifying.key}`
- `.clap-noun-verb/{ocel.json,receipts.jsonl}`
- `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`

Gitignored (NOT drift; excluded): `.ggen-v2/` (9923 files, git-pack mirror),
`.agp-receipts/`, `.ash-gen-receipts/`, `.terraform-validate-receipts/`
(closure-gates.yml:86-92 .gitignore lines verified).

## Cross-check vs live tree

Live `/Users/sac/xaas` `git status --porcelain` shows the same drift class:
`M lib/xaas/castle.ex`, `?? ggen.lock`,
`?? lib/xaas/generated/castle_bridge_{contract,edges}.ex`,
`?? docs/.../generated-castle-bridge-errc.md`, `?? GGEN-SH-AFTER-*`,
`?? .clap-noun-verb/`. Scratch and live agree. (Live additionally carries the
uncommitted convergence diff — unrelated files — which is out of scope here.)

## Coordinator commit-sufficiency verdict

The coordinator's commit set is SUFFICIENT only if it includes exactly:
`lib/xaas/castle.ex` (sync-output version `26839b9d…`, not the live-tree
version `eac1e204…` — the live uncommitted version differs from what sync
produces in a clean materialization; coordinator must take the sync output)
plus the 7 new generated files above, plus a decision on `.ggen/keys/`,
`.clap-noun-verb/`, `GGEN-SH-AFTER-*` (recommend gitignore; note
`.ggen/keys/signing.key` is a **signing key — never commit**).

Replay: re-run the same archive→hash→sync→hash in a fresh scratch; after the
coordinator's commit lands, the same procedure must show an empty diff.

## Cleanup

`rm -rf /tmp/w334-scratch /tmp/w334-before.txt /tmp/w334-after.txt /tmp/b.txt /tmp/a.txt /tmp/w334-drift.txt`
