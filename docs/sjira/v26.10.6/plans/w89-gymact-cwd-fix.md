# W89 Receipt — gymact ggen CWD pollution fix (v26.10.6 convergence)

*Backfilled by coordinator from lane completion report.*

- **Repo**: /Users/sac/xaas
- **Root cause**: ggen ≥ 26.9.28 writes `.clap-noun-verb/` (`receipts.jsonl`, `ocel.json`)
  into the current working directory.
- **Fix**: `".clap-noun-verb"` added to `GGEN_GYM` `_IGNORED_PARTS`
  (`src/gymact/gyms/ggen.py:49`).
- **Gate**: contract test 9/9.
