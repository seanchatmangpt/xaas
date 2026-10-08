# W650v4 — Commit Receipt: digest-framing rotation landed on HEAD

Lane W650v4, v26.10.7 fleet seal. Subject:
`lib/xaas/operations/refusal_ledger_export.ex` (W650v3's landed-uncommitted
work) + receipt `w650v3-digest-framing.md`.

## Freshness

- File mtime 1791415014, checked at 1791418998 (~66 min stable, ≥5 min gate).
- `git log -- lib/xaas/operations/refusal_ledger_export.ex`: last commit
  touching it is d95defa2 (W616b) — W650z7's sweep did NOT land it.

## Digest chain (rotation disclosed)

| digest | meaning |
|---|---|
| `203fee7c…` | BEFORE — SHA-256 of canonical JCS body (excl. `\n`), old framing |
| `6d1e4b89fa90c7489f848ced8d1adcae4bbee9fd608476f035c0b62f91334ea7` | AFTER — SHA-256 of exact written bytes (body + `\n`); equals on-disk `shasum -a 256` |

## Gates (all run this session, real output)

1. Fresh strict compile `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650v4 mix compile --force` → **EXIT=0**.
2. `mix xaas.export_refusal_ledger --court` → **EXIT=0**; printed
   `sha256: 6d1e4b89fa90c7489f848ced8d1adcae4bbee9fd608476f035c0b62f91334ea7`,
   `replay: MATCH`, mutation leg OK; artifact
   `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`.
3. `shasum -a 256` on artifact → `6d1e4b89…34ea7` — **== printed digest**.
4. Depth court `mix test test/xaas/operations/refusal_ledger_export_depth_test.exs`
   → **5 passed**, EXIT=0.

## Landing

- Commit `5e03acf5` on `feat/playwright-surface` (explicit pathspec:
  lib module + w650v3 receipt; w650v2-ledger-digest.md already tracked/clean,
  nothing to stage).
- Fetch-first; `git merge --ff-only origin/feat/playwright-surface`
  → "Already up to date"; push fast-forward `a60bff8c..5e03acf5` — no force.
- Standing: **ALIVE** (all four gates witnessed on the exact subject).
