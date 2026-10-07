# W357 — ggen-marketplace WP-E re-witness receipt (v26.10.6)

- Date: 2026-10-06
- Lane: W357 (verification legs, freshness re-witness; prior 1956/0 ×2 stands)
- Subject: /Users/sac/ggen-marketplace (canonical checkout, no commits made)

## Subject pin
- HEAD: `93895f808775e04dce9441fbf4014a3d4d40c942`
- Dirty entries: 5

## Commands + real tails

### Leg 2 — validate
```
python3 scripts/marketplace.py validate 2>&1 | tail -5
→ validated packs=305 manifests=305 ontologies=502 templates=1819 native_gates=1868 verifier_gates=21 profiles={"project":101,"projection":158,"semantic":46} diataxis=20
EXIT=0
```

### Leg 3 — catalog
```
python3 scripts/marketplace.py catalog 2> /tmp/w357_catalog.err; echo EXIT=$?  # stderr clean
→ tail: "tier": "verified", "verifier_gates": 1, "version": "26.9.13" } , "schema": "https://ggen.dev/marketplace/catalog/v2", "scope": "active"
EXIT=0
```

## Leg 4 — version + standing.md freshness
- `marketplace.active.toml` line 2: `version = "26.10.6"` — matches WP-E expectation.
- mtime: `marketplace.active.toml` 1791313440 vs `docs/context/standing.md` 1791284365.
- standing.md is OLDER than the toml by ~29,075 s (~8.1 h) → STALE vs toml.
- No standing.md regen command found in README.md or marketplace.py (only
  `docs/reference/standing.md` referenced in scripts/marketplace.py:98, a different file).
- Regen not run (writes to sibling repo — forbidden for this lane). Staleness noted only.

## Leg 5 — narrow test
Skipped: no fast court identified in receipts for this lane; full-suite freshness not
required (prior 1956/0 ×2 receipt stands).

## Verdicts
- validate: PASS (exit 0, all gates)
- catalog: PASS (exit 0, regenerates clean, schema v2 active scope)
- version: PASS (26.10.6)
- standing.md: STALE (older than toml by ~8.1 h; regen command not documented; not run — out of lane authority)
