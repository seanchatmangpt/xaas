# W693 — ferroplan AIRo pin test (lane W693)

Subject: xaas `feat/playwright-surface` (test + receipt written here, not committed — lane law: coordinator commits); ferroplan `main` @ `c03787687da4c0cd7d11d2f8b1bf1a9851ef8758` (re-verified HEAD at lane start, matches the ledger's `c0378768`).

Artifact: `/Users/sac/xaas/test/xaas/semantics/ferroplan_airo_pin_test.exs` (new, 8 tests).

## Why xaas, not ferroplan

ferroplan is a Rust workspace (no mix project), so the ExUnit pin lives in the
xaas test tree, mirroring `airo_vendored_pin_test.exs` (W621b). It pins the
ferroplan surface by absolute path. This is a deviation from "add a pin test to
ferroplan" — recorded as a deliberate routing decision, not drift.

## Per-claim verification (ledger w668, ferroplan row w638)

| claim (w668) | verification | result |
|---|---|---|
| TTL exists, 5,417 B | `ls`/`wc` on `/Users/sac/ferroplan/docs/airo-risk-description.ttl` (69 lines) | VERIFIED (69 lines, 5,417 B) |
| bare parse = 34 triples | independent `/tmp/airo-venv` rdflib run: `bare 34` | VERIFIED |
| 34 + 558 = 592 unioned triples | rdflib union parse (TTL + canonical vocab): `union 592` | VERIFIED |
| vocabulary sha256 `6274d2d8…` | `shasum -a 256` on `/Users/sac/xaas/priv/semantic/airo/airo.ttl` AND `/tmp/airo.ttl` — both `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` | VERIFIED (byte-identical to the W600 pin) |
| cited paths verified | test asserts every repo-relative path extracted from the TTL exists under `/Users/sac/ferroplan` | VERIFIED (non-vacuous: 10+ cited paths) |
| key AIRo terms defined in vocabulary | test asserts `airo#<Term>` present in the canonical vendored airo.ttl for AISystem, AIProvider, RiskSource, RiskControl, Risk, hasRisk, hasRiskControl, isProvidedBy, hasLikelihood, hasSeverity, hasConsequence, mitigatesRiskConcept | VERIFIED |

## Real command output

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW693 \
    mix test test/xaas/semantics/ferroplan_airo_pin_test.exs
Running ExUnit with seed: 882013, max_cases: 32
........
Finished in 0.7 seconds (0.00s async, 0.7s sync)
Result: 8 passed
```

(ExUnit excluded-tag banner: `[:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]`; PromEx/Grafana nxdomain warnings are environmental noise — Grafana not running locally.)

Independent corroborating run (not via ExUnit):

```
$ /tmp/airo-venv/bin/python -c "...rdflib..."
bare 34
union 592
```

## Honest iteration log

Two of my own bugs were caught by the test court during this lane (run outputs
disclosed above): `:crypto.hash/2` pipe-argument error (data piped as first
arg), and a `Regex.scan` capture-group arity error plus `System.cmd` `:input`
option not accepted — fixed to a real temp-file subprocess.

## Standing

- **ALIVE** (this exact subject): all 8 pin tests pass on ferroplan `c0378768`
  and the ledger's triple arithmetic (34 + 558 = 592) and vocabulary hash pin
  are reproduced by an independent toolchain (rdflib subprocess) and a byte
  hash, not just `check_airo.sh`.
- Ledger w668 ferroplan rows: no drift found. The only reality-vs-claim
  divergence is none — but note the TTL is **untracked in ferroplan git**
  (`?? docs/airo-risk-description.ttl`, `?? scripts/check_airo.sh` in
  `git status`), so the pinned surface is a working-tree artifact, not a
  committed subject. Pin is therefore to the working-tree bytes
  (`27fd0cb808c1974b20d9259153a011c453913c0bbc2c2b43f5c2c14d464d4e08`), which
  will drift silently if W684/W638 files are modified uncommitted. Flagged to
  the coordinator.
- Pre-existing unrelated failures: none observed in this test file's run; no
  broader suite run (lane scope was the new test file only).

## Lane hygiene

`_build-laneW693` was created under `/Users/sac/xaas` and the `rm -rf` cleanup
was denied by the permission system — **left in place for the coordinator to
delete at integration** per the lane-lease law.
