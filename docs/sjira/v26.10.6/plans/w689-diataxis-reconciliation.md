# W689 — diataxis domain/resource count reconciliation

- Lane: W689, v26.10.6 campaign
- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6` (uncommitted diff, no commit per lane contract)
- Date: 2026-10-07

## Task

diataxis reference docs contradicted each other and the code: `explanation/architecture-overview.md`
claimed "13 Ash domains / 92 resources"; `reference/ash-configuration.md` claimed
19/116 and carried a duplicated stale table (13-row subset with `Marketplace = 2`).

## Real derivation (grep, this tree)

Domains: `config/config.exs:13-33` `ash_domains` — 19 entries.
`grep -rln "use Ash.Domain" lib/xaas` — 19 files, one per domain.

Resources: `grep -c 'resource(' lib/xaas/{a2a,accounts,billing,conference,coupling,generation,governance,graphlaw,igniter,ledger,library,marketplace,ocel,operations,platform,security,temporal_memory,ultracode,witness}.ex`:

```
a2a 2, accounts 5, billing 8, conference 7, coupling 1, generation 1,
governance 28, graphlaw 2, igniter 2, ledger 4, library 7, marketplace 3,
ocel 5, operations 21, platform 7, security 2, temporal_memory 1,
ultracode 8, witness 2  => TOTAL 116
```

## Before → After

`explanation/architecture-overview.md`:
- L3/L10: "13 Ash domains" → "19 Ash domains"
- L12: `config.exs:13-27` → `:13-33`; "(92 total, re-verified 2026-09-22)" → "(116 total, re-verified 2026-10-07)"
- Table rows corrected against `lib/xaas/*.ex`: Ultracode 3 → 8 (added CapitalCensus listing), Marketplace 2 → 3 (added `Pack`), Operations 20 → 21
- Added 6 missing domain rows: A2a (2), Conference (7), Graphlaw (2), Igniter (2), Security (2), Witness (2) — names verified via `grep resource(` on each file

`reference/ash-configuration.md`:
- Deleted duplicated stale 13-row domain table (old lines 87-101; contained stale `Marketplace = 2`)
- Re-verified stamp updated: `2026-10-06 @ d1db2b03` → `2026-10-07 @ a0723bf6` (116 total unchanged)

## Verification (grep, post-edit)

- `grep "^| " architecture-overview.md | grep -v header/sep | wc -l` = 19 domain rows; all counts match the per-file grep
- `grep -rn "13 Ash\|92 total\|92 resources" docs/claude/diataxis/` → no matches
- ash-configuration.md now has exactly one domain table (19 rows, all 19 domains)
- Only the two named diataxis docs touched; README.md diff in the tree is pre-existing (was modified before this lane started)

## Standing

ALIVE (counts derived from and re-verified against this exact tree at `a0723bf6`; docs now agree with code and with each other).

Known residue (out of lane scope): architecture-overview.md's extensions paragraph
still lists the pre-v26.10.x extension distribution (omits `Xaas.Igniter`'s
`AshTypescript.Rpc` and the newer domains' extension sets); reference table is
the exact authority for extensions.
