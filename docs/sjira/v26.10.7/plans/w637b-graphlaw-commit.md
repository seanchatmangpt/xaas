# W637b — graphlaw wasm profile + digest sidecar commit (lane W637b, v26.10.7)

- **Standing**: ALIVE (committed + pushed, ff, verified on disk and remote)
- **Repo**: ~/graphlaw (canonical checkout, branch `graphlaw-registry-limits`)
- **Commit**: `1869a16` — `build(wasm): W637b [profile.wasm] merge + artifact digest sidecar`
- **Push**: `origin main` `0bb0df2..1869a16` (fast-forward; origin/main `0bb0df2a` was verified
  ancestor of HEAD pre-push; no force)

## Committed (explicit pathspec)

1. `wasm/Cargo.toml` — the `[profile.wasm]` merge only; the diff contained exactly that hunk
   (+11 lines: opt-level "s", lto, codegen-units=1, strip, panic=abort; comment cites ggen
   wasi-json-abi-pack `generated/graphlaw/cargo-profile.toml` and W637). No other hunks present.
2. `priv/graphlaw.wasm.sha256` (new sidecar) — records the artifact digest.

## Binary not committed — convention

`git ls-files priv/` was empty before this commit and `priv/` appears in no `.gitignore` rule;
the repo tracks **no** priv artifacts. Per the lane contract's convention branch, the 6,657,549-byte
`priv/graphlaw.wasm` was **not** committed; only the digest sidecar was.

## Digest verification (before commit)

```
shasum -a 256 priv/graphlaw.wasm
b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121  priv/graphlaw.wasm
stat -f%z → 6657549
```

Matches W637 receipt `w637-graphlaw-wasm-build.md` line 66 exactly.

## Receipt

- Commands/exits: git add/commit/push all exit 0; push output above.
- Replay: `cd ~/graphlaw && git show 1869a16 --stat` (2 files, +12); `git ls-remote origin main` → `1869a16…`.
- Falsifier (closed): prior to this commit `git ls-files priv/` returned nothing and the
  `[profile.wasm]` section was absent from committed `wasm/Cargo.toml`.
- Residual: binary remains local-only at `priv/graphlaw.wasm` (untracked); consumers replay via
  the sidecar digest, not the remote.
