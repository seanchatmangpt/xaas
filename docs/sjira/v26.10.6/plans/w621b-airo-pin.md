# W621b — AIRo Vendored Vocabulary Pin

Lane W621b, AIRo wave, repo `/Users/sac/xaas` @ `feat/playwright-surface`,
private build root `_build-laneW621b`.

## Scope (contract)

Written only:
- `test/xaas/semantics/airo_vendored_pin_test.exs` (new)
- `docs/sjira/v26.10.6/plans/w621b-airo-pin.md` (this receipt)

## Assertions

Against `priv/semantic/airo/`:
1. `airo.ttl` exists.
2. sha256(`airo.ttl`) == `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
   (W600's verified vendor).
3. `README.md` exists.
4. Key classes present in content: `AISystem`, `Risk`, `RiskSource`, `RiskControl`,
   `Vulnerability`.
5. Key properties present in content: `hasRisk`, `mitigatesRiskConcept`,
   `detectsRiskConcept`.

Against W601's module:
6. `Xaas.Semantics.AiroRiskMapping.risk_graph/0` called twice returns equal
   binaries (deterministic) and output contains `airo:`.

## Observed state at authoring time

- `priv/semantic/airo/airo.ttl` present; `shasum -a 256` =
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (matches pin).
- `priv/semantic/airo/README.md` present.
- `lib/xaas/semantics/airo_risk_mapping.ex` (W601) present on disk; poll-gate
  not needed.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW621b \
  mix test test/xaas/semantics/airo_vendored_pin_test.exs
```

Result (final, 2026-10-06, warm `_build-laneW621b`, pinned asdf toolchain):

```
Result: 6 passed
Finished in 0.04 seconds
```

Notes:
- One intermediate red run: test-side repo-root path bug (`@repo_root` two
  levels up instead of three); fixed in the test file, not a product defect.
- One transient red gate owned by another lane: `lib/mix/tasks/xaas.release_audit.ex`
  mismatched-delimiter compile error; poll-gated until that lane fixed it
  (`mix compile` green after 14 probes), then re-ran. Not introduced by W621b.

## Verdict

ALIVE — vendored AIRo pin test green 6/6 on the exact working-tree subject;
hash matches W600's vendor pin; `risk_graph/0` deterministic with `airo:`
prefix (also witnessed standalone: exit 0, `has airo prefix: true`).
