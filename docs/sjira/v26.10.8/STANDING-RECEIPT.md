# STANDING-RECEIPT — xaas doc-hdit doc surface (lane R108)

Date: 2026-10-09 · Lane R108 · Repo: /Users/sac/xaas (canonical checkout,
branch `main`)

## Identity (subject-bound)

- Subject: xaas `main` @ `0afd81ed91802c1a5e464129cc72d30ac6ec6e12`
  ("docs(reference): ground remaining 9 modules + doc-surface policy
  receipt (lane R26-r)").
- Extractor pin: `scripts/gen_doc_surface.py` (ggen-marketplace)
  sha256 `3d2abae19dac9f529b8250a0f96a02b34dbf86348dad241fbdb003410dc35590`
  — ledger-current (`check_pin_freshness.sh` exit 0, 2026-10-09), same pin
  as the R26-r policy receipt.
- Coordination note: a concurrent R92 doc-hdit audit over xaas was observed
  mid-flight during this receipt's minting (pid 7931, 96% CPU, audit dir
  `/tmp/hdit/r92/`), but its audited subject is the STALE head `26f9b75e`
  (`/tmp/hdit/r92/xaas.head`), an ancestor of `0afd81ed`. Its certify
  receipt, when it lands, is bound to `26f9b75e` and does NOT supersede a
  standing receipt at `0afd81ed`. No skip taken; this receipt stands.

## Standing: FAIL-HONEST at policy scope

The honest standing of the doc surface at `0afd81ed` is FAIL-HONEST. No
PASS is manufactured.

### Module gate — policy (audited-roots) scope: FAIL

Per `.doc-surface.toml` (landed with R26-r at `0afd81ed`), the audited doc
surface is the 7 audited roots (docs/reference, docs/claude/diataxis,
docs/airo, docs/hddl, docs/rfc, docs/eu_ai_act, docs/ci); the historical/
receipt plane (docs/sjira, docs/jira, docs/archive, docs/cro,
docs/ultracode, docs/vision, docs/case-studies, docs/streams, docs/release,
docs/claude-minus-diataxis) is scoped out BY DECISION. Gate thresholds are
NOT relaxed.

At this scope the module gate FAILS: 1013 modules, **64 uncovered**
(`docs/sjira/v26.10.8/plans/r26-doc-surface-policy-receipt.md`, in-tree at
this subject). Largest blocks: Xaas.Governance.Types (14),
Xaas.Runtime.ProviderFabric (9), ProviderMesh remainder (6),
Xaas.Ultracode.CapitalCensus.Types (6), FOND remainder (4), plus
senders/mailer, AwsRepo, ILSRepo, ErrorHTML, Gettext, SIP2TestServer,
CorpusLoader (test-support-in-code-surface is an open extractor-scope
question, recorded not silently excluded).

### Whole-docs (pre-policy) denominator: 1004/1013 = 0.9911 — PASS vs 0.90

Cited honestly, this is a DIFFERENT denominator and is NOT the standing
figure. The pre-policy whole-docs scan at xaas `26f9b75e` measured
**1004/1013 = 0.9911, PASS vs 0.90** (DENOMINATOR-SCOPE-DECISION,
ggen-marketplace `0f3d840ffd46cb560a910402af9d8d8ddee9b379`,
`docs/sjira/v26.10.8/DENOMINATOR-SCOPE-DECISION.md`). That figure counted
prose living in docs/sjira and other receipt-plane roots that the policy
decision scoped out; the policy re-exposed 64 modules that were previously
"covered" only by that plane. Both figures are true of their own scopes;
the standing above is taken at the policy scope because that is the
receipted surface definition, not because the passing figure is stale.

### Φ (hallucination rate): SOLVED

Φ = **0.0001** post-`[152]` scaffold-cell grounding discipline (extractor
`2a7355419`), at both scopes (DENOMINATOR-SCOPE-DECISION line 58;
SEMANTIC-WAVE-RECEIPT witness table: xaas 0.1008→0.0001, Φ gate flips to
PASS). Φ standing is independent of the coverage FAIL above.

## Grounding lineage

- **R52** @ `26f9b75e`: 4-module grounding — SemanticDrive,
  FiboRevenueProfile, EventSimulation, SbbRealization (module surfaces in
  docs/reference/modules/{explanation,how_to,reference}.md).
- **R26-r** @ `0afd81ed`: 9-module grounding — WdFa.CapabilitySelector,
  FOND.Backoff, ProviderFabric.Backoff, SelfDigest.Promotion,
  ProviderMesh.{Backoff, PrioritySelector, RetryPolicy, Selector},
  NotificationExtension.Resource.Persist — prose in the AGENT-COMMENTARY
  slots of docs/reference/modules/explanation.md and how_to.md. All 9
  carry ≥1 grounded claim at the policy scope (FOND.Backoff 8,
  RetryPolicy 4, CapabilitySelector 2, Promotion 2, Persist 3); they are
  not part of the 64-module residual.
- Policy receipt path:
  `docs/sjira/v26.10.8/plans/r26-doc-surface-policy-receipt.md` (in-tree).

## Tags v26.10.8 / v26.10.8-2 / v26.10.8-3 coverage

Per ggen-marketplace `docs/sjira/v26.10.8/TAG-STANDING.md`: xaas
`v26.10.8` @ `86752b3b`, `v26.10.8-2` advanced to `8bb4a2f5` (sealed
XAAS-26108-1..5, standing ALIVE), `v26.10.8-3` advanced to `3ed88241`
(receipted `[60]` repair + generated config-surface reference). All three
tag targets are strict ancestors of this subject `0afd81ed`; this
receipt's FAIL-HONEST standing therefore describes documentation work
grounded AFTER the newest tag — the tags' coverage statements are not
invalidated, but they do not cover the post-`3ed88241` heads (`26f9b75e`,
`0afd81ed`), which this receipt binds.

## Replay

```
git -C /Users/sac/xaas rev-parse HEAD          # 0afd81ed91802c1a5e464…
git -C /Users/sac/xaas show 0afd81ed:docs/sjira/v26.10.8/plans/r26-doc-surface-policy-receipt.md
git -C /Users/sac/ggen-marketplace show 0f3d840ff:docs/sjira/v26.10.8/DENOMINATOR-SCOPE-DECISION.md | grep -E "1004|0.9911|0.0001"
cd /Users/sac/ggen-marketplace && sh scripts/check_pin_freshness.sh   # OK 3d2abae1…
# module gate at policy scope (FAIL, 64 uncovered):
cd /Users/sac/ggen-marketplace
python3 scripts/gen_doc_surface.py code /Users/sac/xaas > code.json
python3 scripts/gen_doc_surface.py doc /Users/sac/xaas \
  --code-json code.json --docs-dir <7 audited roots, comma-joined>
# module_coverage.modules: 1013, uncovered: 64
```

## Re-certification scope

Re-certification triggers on a non-empty `git diff --stat 0afd81ed..HEAD -- lib/ priv/` (code/claim-surface change); docs-only commits are grandfathered.

## Falsifier

- A PASS at the policy scope would falsify this receipt: re-run the gate
  with `--docs-dir` = the 7 audited roots; if `uncovered` is not 64
  (i.e. the gate PASSes) at `0afd81ed`, this standing is wrong.
- If the 9 R26-r-grounded modules appear in the uncovered list, the R26-r
  grounding claim is falsified.

## Receipt

Standing chosen: FAIL-HONEST at policy scope (module gate FAIL, 64
uncovered of 1013); Φ solved at 0.0001. Evidence paths: in-tree policy
receipt (above), DENOMINATOR-SCOPE-DECISION @0f3d840ff (ggen-marketplace),
TAG-STANDING.md (ggen-marketplace), pin 3d2abae1 ledger-current. Commit
SHA: recorded post-commit in the lane report.
