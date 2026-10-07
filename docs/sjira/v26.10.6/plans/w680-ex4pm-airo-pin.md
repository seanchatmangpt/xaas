# W680 — ex4pm AIRo surface pin (receipt)

- **Subject**: /Users/sac/ex4pm @ branch `main`, HEAD `46bfcc8fac15889971a36b2e99c463d80b3f1712` (recorded before any writes; no commits, no branch switches)
- **Lane**: W680, xaas v26.10.6 AIRo wiring ledger verification
- **Backlog claim under test**: `/Users/sac/xaas/docs/cro/artifacts/airo-wiring-ledger.md` — "ex4pm CONSISTENT"
- **Tree discipline**: no worktrees; only file written in-repo is `test/w680_airo_surface_pin_test.exs` (left uncommitted for coordinator integration). Pre-existing dirty state untouched: `M CHANGELOG.md`, `M mix.exs`, `?? docs/sjira/`, `?? ex4pm-26.10.1.tar` (other lanes/coordinator).

## Per-claim verification

| claim | verdict | evidence |
|---|---|---|
| Ledger contains an ex4pm row | **REFUTED — drift** | `grep -inE "ex4pm" airo-wiring-ledger.md` → zero matches. The consolidated table lists 14 repos (w600–w638); ex4pm appears nowhere: not in the coverage statement, table, or the cross-repo sha table. The "ex4pm CONSISTENT" attribution is **unsupported by the ledger text**. |
| ex4pm has a real AIRo surface | CONFIRMED (committed, not lane-local) | `priv/ontologies/airo_risk_description.ttl` (7,956 B, sha256 `766059ce26259dde6806b3909ebaed231d5d6e0472ffc0d6c82e379d51e8df19`) + court `test/w645b_airo_risk_description_test.exs` — both **tracked** at HEAD `46bfcc8` (`git ls-files` verified). Appears to be w645b lane work already integrated. |
| Surface matches the w600 AIRo 1.0 vocabulary family | CONFIRMED | Real rdflib 7.6.0 parse: description = **77 triples**, union with `/Users/sac/xaas/priv/semantic/airo/airo.ttl` = **635 triples**. Note: this is a risk *description* instance (like beam4pm w634), not a byte-verbatim vocab copy — its sha intentionally differs from the `6274d2d8…` vocab pin; the description file is pinned at its own sha `766059ce…`. |
| AIRo terms present | CONFIRMED | All 20 pinned terms (10 classes: AISystem, RiskSource, Hazard, Risk, Consequence, Impact, Likelihood, Severity, RiskControl, AIProvider; 10 properties: hasRisk, isProvidedBy, hasConsequence, hasImpact, hasLikelihood, hasSeverity, hasRiskControl, mitigatesRiskConcept, detectsRiskConcept, hasDocumentation) asserted present in-test. |

## Drift finding (the honest headline)

**The ledger itself never claims ex4pm.** "ex4pm CONSISTENT" is not in
`airo-wiring-ledger.md`; the ledger's CONSISTENT verdict covers only its
listed 14 repos and 4 sha-table entries. ex4pm does, however, carry a
committed AIRo risk-description surface (w645b generation) that the ledger
omits — a coverage gap in the ledger, not a wiring defect in ex4pm. If the
backlog intends ex4pm in the 14-repo count, the ledger needs a w645b/ex4pm
row added (coordinator action, not lane action).

## Work performed

- New file: `test/w680_airo_surface_pin_test.exs` (4 tests; real file reads,
  real `:crypto` sha256, real `/tmp/airo-venv/bin/python` rdflib subprocess;
  no mocks, no interaction assertions).
- Receipt file (this one). Nothing committed anywhere.

## Commands + exits (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW680 \
    mix test test/w680_airo_surface_pin_test.exs
# first run: 3/4 passed — 1 failed, ErlangError :enoent,
#   /tmp/airo-venv/bin/python missing (tmp venv evaporated since w645b)
# repair: python3 -m venv /tmp/airo-venv && pip install rdflib → rdflib 7.6.0
# second run:
Excluding tags: [:chicago, :integration, :stress, :live_external]
....
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 4 passed

$ MIX_BUILD_ROOT=_build-laneW680 mix test test/w645b_airo_risk_description_test.exs
.....
Finished in 0.3 seconds (0.3s async, 0.00s sync)
Result: 5 passed   # pre-existing court also green on same subject
```

Toolchain: asdf elixir 1.20.4-otp-29 / erlang 29.1.1 (`.tool-versions` pin);
build root `_build-laneW680` created, **deleted after run** (lease law).
Full `mix test` suite NOT run (out of lane scope; dirty tree from other
lanes — no unrelated failures observed or disclosed beyond the above).

## Standing

- ex4pm AIRo surface: **ALIVE** on exact subject main@`46bfcc8` (observed
  execution, real parses, real sha checks).
- Ledger "ex4pm CONSISTENT" attribution: **UNSUPPORTED** (no such row) —
  surface itself is consistent with the AIRo 1.0 family; ledger coverage is
  the defect.
- Falsifier for the pin: any change to `priv/ontologies/airo_risk_description.ttl`
  that moves sha `766059ce…`, drops a pinned term, or breaks the rdflib
  parse/vocab-union fails `test/w680_airo_surface_pin_test.exs`.

## Replay

```
cd /Users/sac/ex4pm && git checkout 46bfcc8fac15889971a36b2e99c463d80b3f1712
export PATH=$HOME/.asdf/shims:$PATH
python3 -m venv /tmp/airo-venv && /tmp/airo-venv/bin/pip install rdflib
MIX_BUILD_ROOT=_build-laneW680 mix test test/w680_airo_surface_pin_test.exs   # expect 4 passed
MIX_BUILD_ROOT=_build-laneW680 mix test test/w645b_airo_risk_description_test.exs  # expect 5 passed
```

2026-10-07, lane W680.
