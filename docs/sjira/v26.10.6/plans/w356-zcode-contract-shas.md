# W356 — zcode-cli contract sha re-verification receipt (WP-C staging integrity)

Wave lane W356, v26.10.6. Re-verifies the two contract artifacts whose parity
r7-zcode-cli.md recorded as ALIVE (byte-identical), so the coordinator's WP-C
commit receipt can pin exact shas. W46/W58 receipts themselves do not record
contract paths or shas — the contract identity comes from r7-zcode-cli.md
("Contract sha parity verified this session (both byte-identical)"), which is
the qualification reference for this stream.

## Contract paths + shas (recomputed 2026-10-06, `shasum -a 256`)

| contract | path (zcode-cli side) | path (xaas side) | sha256 (identical both sides) |
|---|---|---|---|
| gall-work | `/Users/sac/zcode-cli/test/fixtures/gall-work.contract.json` | `/Users/sac/xaas/priv/zcode_plugin/gall-work.contract.json` | `5515775861807cdd7394ef74b1ee38679dd24279224515178702bb6652a95fc4` |
| xaas-remote-relay | `/Users/sac/zcode-cli/test/fixtures/xaas-remote-relay.contract.json` | `/Users/sac/xaas/priv/ultracode/remote-relay.contract.json` | `76ff551c16cea5afb40b385ecee9ab7462ce1d73bee47655c0e0c63dc0a33f89` |

## Verdict: STABLE

Both contracts byte-identical across the repo boundary at recompute time.
No drift since qualification; neither contract file appears in the stream's
18 dirty files (`git status --porcelain`: 14 M + 4 ??, none of them the
contract fixtures). No re-qualification needed.

## Test gate re-run (post-W58)

Command: `cd /Users/sac/zcode-cli && ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts`
(bun 1.x, real run, 101.83s). Verbatim tail:

```
 1072 pass
  0 fail
 268359 expect() calls
Ran 1072 tests across 125 files. [101.83s]
```

Matches w58's recorded 1072 pass / 0 fail / 268359 expect() calls exactly.

## Standing

ALIVE — contracts sha-stable, unit suite green on the same command w58 used.
No source edits, no commits. Only write: this receipt.
