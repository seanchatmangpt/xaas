# W628 — Master Equation determinism SOAK

Lane W628 of the EU-AI-Act wave. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
private build root `_build-laneW628`. One canonical checkout, no worktrees.

## Task

Soak the W541 Master Equation composition court
(`test/xaas/semantics/master_equation_test.exs`, `f_actuate/2`) to
dissertation-Theorem strength: invariance under repetition. W541 ran
determinism x3; this lane runs 100 iterations x 3 candidate classes
(lawful / Art.5-violating / margin-violating) = 300 runs with seeded
random interleaving.

## Files (lane contract)

* `test/xaas/semantics/master_equation_soak_test.exs` — NEW, the only code file.
* This plan/receipt doc.

No `lib/` edits. Composition is REUSED from W541's court module
(`Xaas.Semantics.MasterEquationTest.f_actuate/2`, public `def`s) — no
pipeline duplication.

## Soak design

* Seed: `62_828`; class sequence drawn via `:rand.bytes_s/2` over an
  exported `:exsss` state — fully reproducible interleaving.
* Per class (100 runs each):
  * determinism: every run byte-identical (`==`, full term equality) to the
    class's first-run baseline;
  * refusals name their EXACT gate — `:art5_violating` refuses at
    `:article5_admission` (`:REFUSED_EUAIA_MANIPULATIVE`), `:margin_violating`
    passes gate (a) and refuses at `:robust_margin` (`:REFUSED_ROBUST_MARGIN`,
    epsilon 100.0); every refusal's signature slot verifies (W541 disclosed
    HMAC stand-in slot contract);
  * every DO receipt's signature verifies over (subject, head_hash) and its
    per-run chain verifies `AuditChain.verify_chain == :ok`.
* Ledger martingale: every DO payload (100 of them) is appended into ONE
  soak-level `AuditChain`; at the end
  `verify_chain(soak_chain, expected_length: 100, expected_head: head) == :ok`.
* Cross-seed courts: same seed twice → identical results/chain/head;
  different seed → different interleaving but identical per-class outcomes.

## Soak parameters (receipt)

| param | value |
|---|---|
| iterations | 100 per class |
| classes | lawful, art5_violating, margin_violating |
| total runs | 300 |
| seed | 62828 |
| robustness (lawful) | epsilon 0.01, l_e 1.0 |
| robustness (margin) | epsilon 100.0, l_e 1.0 |

## Verification command

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW628 MIX_ENV=test \
  mix test test/xaas/semantics/master_equation_test.exs \
      test/xaas/semantics/master_equation_soak_test.exs
```

(The soak test reuses `Xaas.Semantics.MasterEquationTest.f_actuate/2` at
runtime, so the W541 court file must be in the same mix test invocation —
running the soak file alone does not load the court module.)

## Tails (observed 2026-10-06, lane build root `_build-laneW628`, MIX_ENV=test)

```
.............
Finished in 1.7 seconds (0.00s async, 1.7s sync)

Result: 13 passed
```

13 = 9 (W541 court, unchanged, still green) + 4 (W628 soak courts):

* determinism/gate-naming/receipt-verification over 300 runs — PASS
* ledger martingale: soak chain of 100 DO receipts verifies
  `:ok` with `expected_length: 100` + `expected_head` — PASS
* same-seed re-soak: identical results, chain, and head — PASS
* cross-seed: different interleaving, identical per-class outcomes — PASS

Verdict: **300/300**. Every lawful run byte-identical to its class baseline;
every refusal names its exact gate (Art.5 → `:article5_admission` /
`:REFUSED_EUAIA_MANIPULATIVE`; margin → `:robust_margin` /
`:REFUSED_ROBUST_MARGIN`, gate (a) shown as :pass in its trace); every DO
receipt signature verifies; every per-run chain verifies; the full soak
ledger verifies `:ok`.

## Standing

ALIVE on this subject (branch `feat/playwright-surface`, lane build root
`_build-laneW628`, test-only diff). Strict compile unaffected: no `lib/`
edits by this lane (all modified `lib/` paths in `git status` are
pre-existing branch state from other lanes).
