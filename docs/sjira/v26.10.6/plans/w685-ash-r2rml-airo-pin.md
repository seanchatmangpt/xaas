# W685 — ash_r2rml AIRo Wiring Pin (Receipt)

- **Lane**: W685 (xaas v26.10.6 campaign, AIRo wiring extension)
- **Repo**: `/Users/sac/ash_r2rml` (canonical checkout)
- **Branch / exact HEAD at lane start**: `fix/v26.9.29-from-source-head` @ `b86a6a6635fb6ba9f45903fe8c9098a1c24c1347`
- **Tree state at start**: dirty from prior lanes (`CHANGELOG.md`,
  `lib/ash_r2rml/integrity.ex`, `usage-rules/vkg.md` modified; `docs/sjira/`
  untracked). No lane touched those files. Lane touched only
  `test/airo_wiring_ledger_pin_w685_test.exs` (new). Not committed —
  coordinator owns integration.
- **Standing**: ALIVE (observed execution on exact subject)

## Ledger claim under test

`docs/cro/artifacts/airo-wiring-ledger.md` (w625d row + cross-repo
consistency table) claims ash_r2rml CONSISTENT: fixture
`test/fixtures/airo_vocabulary_snapshot.ttl` sha-pinned at
`6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`.

## Per-claim verification (all before writing the test)

| claim | observation | result |
|---|---|---|
| fixture exists at pinned path | `ls test/fixtures/` | confirmed |
| fixture sha256 == ledger pin | `shasum -a 256` → `6274d2d8…8469` | **matches, byte-exact** |
| `priv/airo_risk_description.ttl` exists (second AIRo surface) | `shasum -a 256` → `bf32dd7a…` (distinct file, not the pin) | confirmed |
| pin traces to vendored canonical | `/Users/sac/xaas/priv/semantic/airo/airo.ttl` sha256 → `6274d2d8…8469` | **matches — pin is the vendored canonical** |
| existing w625d court present | `test/airo_risk_description_test.exs` (7-court, same pin constant) | confirmed |

**Verdict: ledger row accurate. No drift. CONSISTENT stands.**

## μ/diff

Single new file, handwritten (no generator profile exists for test courts;
reducible residue only):

- `test/airo_wiring_ledger_pin_w685_test.exs` — W685 pin court, 4 tests,
  Chicago-style (real file reads only, no mocks):
  1. fixture sha256 == ledger pin `6274d2d8…` (byte-hash pin)
  2. real Turtle structural parse: `@prefix airo:` + ≥20 `owl:Class` and
     ≥10 `owl:ObjectProperty` `airo:` declarations; anchor terms
     AISystem/Risk/RiskControl/Consequence/hasRiskControl/hasConsequence
  3. fixture byte-identical to `/Users/sac/xaas/priv/semantic/airo/airo.ttl`
     (cross-repo drift check against vendored canonical)
  4. `priv/airo_risk_description.ttl` cites only repo paths that exist
     (citation grounding)

One iteration: initial regex used `a owl:Class`; the fixture uses
`rdf:type owl:Class` form. Fixed against real parse, rerun green.

## Verification ladder (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW685 \
    mix test test/airo_wiring_ledger_pin_w685_test.exs
Compiling 158 files (.ex)   # first run, lane build root
Running ExUnit with seed: 526324, max_cases: 32
....
Finished in 0.05 seconds (0.05s async, 0.00s sync)
4 tests, 0 failures
```

First run exposed 1 real failure (parse regex), repaired, rerun 4/4 green.

## Falsifier

Any of: fixture sha256 drifts from `6274d2d8…`; fixture diverges from the
vendored canonical airo.ttl; cited path removed from `lib/|test/`; airo:
vocabulary term dropped below the declared anchors — the court fails and
the ledger's CONSISTENT verdict for ash_r2rml flips to DRIFT.

## Cleanup

`_build-laneW685` deleted at integration (`ls` confirms absent). Nothing
else in the repo touched.
