# W362 — P3 boot-path catalog determinism receipt (v26.10.6)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, `e2e/global-setup.cjs --catalog` boot-path probe. Read-only lane; no repo writes besides this file.

## Script analysis (path/exit contract)

- `MARKETPLACE_CATALOG_PATH` = `path.join(os.tmpdir(), "xaas-e2e-marketplace-catalog.json")` — observed resolving to `/Users/sac/.cache/tmp/xaas-e2e-marketplace-catalog.json` (TMPDIR is macOS cache-dir based here). Exported via `module.exports` and consumed by `playwright.config.cjs`.
- `--catalog` mode → `catalogOnly()` → `generateMarketplaceCatalog()` then unconditional `process.exit(0)`. Matches the header/playwright.config.cjs contract: generation failure is logged (`tryStep` catches, warns "[global-setup] ... FAILED (continuing)") and boot proceeds; mount-time ingest surfaces the typed refusal in the UI.
- Generator invoked: `python3 scripts/marketplace.py catalog` with `cwd: /Users/sac/ggen-marketplace` (exists on disk). Output must `JSON.parse` and contain `packs.length > 0` or the write is skipped (still exit 0).
- **Env-var finding**: the script reads **no** env var for the output path. The task's proposed `PW_MARKETPLACE_CATALOG` is not consumed; the write target is hard-coded to the tmpdir constant. Two-run isolation was done by copying the fixed-path output after each run instead.

## Two-run determinism

- Run 1: exit 0, "marketplace catalog written ... (13 packs)" → sha256 `6689b80acbf14a89bb260353cdda97c08acc29e85c3ede68291f79815214a487` (/tmp/w362-cat1.json)
- Run 2: exit 0, same message → sha256 `6689b80acbf14a89bb260353cdda97c08acc29e85c3ede68291f79815214a487` (/tmp/w362-cat2.json)
- Identical hashes → **deterministic: YES** (no diff needed).

## JSON validity

Both files parse via `JSON.parse(readFileSync(...))`: `cat1 OK`, `cat2 OK`.

## Negative probe

Skipped. The script's failure mode is `tryStep` catching a failing generator command; every safe breakage (e.g. shadowing `python3`, empty catalog) routes through the same `tryStep`/exit-0 path already exercised by code inspection, and the only hostile breakages (deleting/renaming `/Users/sac/ggen-marketplace`) would mutate a sibling repo. Per contract, skipped with this reason.

## Verdict

Deterministic: **YES**, exits 0 both runs, JSON valid both runs, fallback contract (exit 0 on generation failure) confirmed in code. Falsifier for the catalog court: catalog bytes diverge across two same-subject runs — not observed.
