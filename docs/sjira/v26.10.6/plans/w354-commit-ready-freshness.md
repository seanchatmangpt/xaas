# W354 — Commit-ready freshness receipt (2026-10-06, lane W354)

Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only audit; only this file written.

## Per-item status

1. **xaas castle-bridge set: PRESENT (staging-intact), with one name-deviation.**
   - `lib/xaas/castle.ex` — modified (injection present).
   - `lib/xaas/generated/castle_bridge_contract.ex` — untracked, present.
   - `lib/xaas/generated/castle_bridge_edges.ex` — untracked, present.
   - `test/xaas/generated/castle_bridge_contract_test.exs` — present on disk (979 bytes, Oct 6 11:55); untracked (does not appear in `castle` grep because the grep matched, but it shows only under `test/xaas/generated/` untracked lines — confirmed on disk; the dir also holds an unrelated `registry_drift_guard_test.exs`).
   - `priv/semantic/generated/castle_bridge_shacl.ttl` — present on disk (1135 bytes, Oct 6 11:55); the whole `priv/semantic/` dir is untracked (shows as `?? priv/semantic/`).
   - ERCC doc page — `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` untracked, present.
   - Bonus untracked in the same family (not in the 7-file set): `test/xaas/castle_refusal_negative_test.exs` + `batch2`–`batch6` tests, and `test/xaas/fabric/castle_alive_test.exs` (modified).

2. **ggen.lock: PRESENT, untracked** (`?? ggen.lock`). Pins pack source
   `ggen-marketplace.git@518572b6b53103922ae8a27636a00e982a0907c4#packs/xaas-castle-bridge-pack`.
   **MISMATCH vs closure-gates.yml**: `.github/workflows/closure-gates.yml` line 33 has
   `GGEN_SHA: 1e9fcb9679a61460fbd641415cb72511c7e50b33` — a different SHA from the pack-source
   SHA in ggen.lock (518572b6…). Note: the lock's SHA pins ggen-marketplace, while GGEN_SHA pins
   the ggen action/CLI — likely different repos by design, but flagging for w327 confirmation.

3. **ferroplan: STAGING INTACT (WP-B).** Untracked wasm artifact
   `crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` present; 4 ggen receipt files modified
   (`.ggen-v2/receipt-log.jsonl` + `receipt.json` at repo root and under `crates/ferroplan-wasm/`).

4. **zcode-cli: STAGING INTACT (WP-C).** `git status --porcelain | wc -l` = **18** (matches ~18 expected).

5. **priv/chicago + priv/zcode_plugin: CLEAN.** `git status --porcelain` on both → empty (tracked, unmodified).

6. **Exclusion list — STILL PRESENT at xaas root (delete candidates):**
   - `GGEN-SH-AFTER-MIX-COMPILE.log`
   - `GGEN-SH-AFTER-PROOF.txt`
   - `erl_crash.dump`
   (No other GGEN-SH-*.log/txt matched.)

7. **Lane build roots on disk NOW (current operator cleanup list, supersedes w191):**
   - /Users/sac/xaas: `_build-lane295`, `W125`, `W141`, `W177`, `W212`, `W248`, `W316`, `W318`, `W320`, `W329`, `W335`, `W347`, `W349`, `W350` (14 roots)
   - /Users/sac/ash_surface: `_build-laneW326`, `_build-laneW348` (2)
   - /Users/sac/ggen_igniter: `_build-laneW343` (1)
   Total: **17 lane build roots** across 3 repos.

## Lists as of now

**Commit-eligible (staging intact):** castle-bridge set (minus unconfirmed contract test), ggen.lock,
priv/semantic/ (contains shacl.ttl), ERCC doc page, castle refusal-negative tests (bonus, coordinator's call),
ferroplan wasm + 4 receipt files, zcode-cli's 18 entries.

**Do-not-commit:** anything under `_build-lane*`, ggen.lock generation artifacts if lock policy says ignore,
closure-gates.yml GGEN_SHA until marketplace-vs-ggen SHA question resolved with w327.

**Delete:** `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`, `erl_crash.dump`, all 17
`_build-lane*` roots listed above (coordinator executes at integration per cleanup law).

## Open items

- GGEN_SHA (1e9fcb9…) vs ggen.lock pack SHA (518572b…) — cross-repo ambiguity, needs w327's intent.
