# W984fa — Art 15.1/15.4/15.5 robustness/cybersecurity deepening (8 courts)

Lane W984fa · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; **no commit** per
dispatch). Build root `_build-laneW984fa`, cold compile, pinned asdf
toolchain (`PATH=$HOME/.asdf/shims`), `MIX_ENV=test`.

## Gap-inventory provenance

W984ec's receipt (`w984ec-probe.md`) flagged 15.1/15.4 (margin gate) and
15.5/15.5.s2 (wasi-gate) as court-free for dedicated deepening. The live
`deepening_map` (`test/eu_ai_act/title_iii_test.exs`) was re-read on
disk plus the adjacent corpus: `art15_deepening_test.exs` (W667: seeded
adversarial monotonicity sweeps + typed-refusal envelope), the
`title_iii` `deepen_kind(:margin_gate)`/`(:audit_chain)` generic shape
tests, and `deepen_kind(:wasi_gate)` (Cargo.toml text-existence only).
None of those assert exact boundary identities or the allowlist scope
knob. Taken lines (all EVIDENCED per W502, court-free for deepening):

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---| disclosed repair |
| 15.4 | robustness against errors/inconsistent outputs over the lifecycle (Thm 5.3 margin) | `Xaas.Semantics.RobustMargin` | `test/eu_ai_act/art15x_robustness_deepening_test.exs` (4 courts) | a hardcoded l_h or a non-inclusive boundary fails the exact-identity legs (penalty admit at `m == l_h*l_e*eps`, `eps* = m/(l_h*l_e)` flip); a constant boundary fails the shallow/steep flip leg; a wrong secant estimator fails the exact-slope identity leg |
| 15.5 / 15.5.s2 | cybersecurity; solutions appropriate to circumstances/risk scope | `Xaas.Semantics.GraphlawWasm.judge_imports/2` (hard WASI allowlist) | same file (3 courts) | a name-not-signature judge fails the fd_write arity-drift court; a judge that cannot scope fails the 15.5.s2 knob leg; a refusal echoing wrong offenders fails the exact-name assertion; custom-scope must not open the rest of the surface (sneaky proc_exit leg) |
| 15.1 | umbrella: accuracy/robustness/cybersecurity posture | RobustMargin + GraphlawWasm.judge_imports + `Xaas.Witness.AuditChain` | same file (1 court) | a gate not binding to the shared subject identity fails any of the three legs; head-anchored-only tamper detection fails the successor-link tamper leg |

NOT-BUILT disposition (typed, no filler): 15.4.s3 (continual-learning
robustness duty) — this surface does not continue learning after
deployment; the line is already NOT_APPLICABLE/NOT-BUILT in the
deepening map and stays untouched. 15.3/15.4.s2/15.5.s3 already hold
courts (W536/W507/W540) and were not duplicated.

## Concurrent-lane interaction (disclosed, compile-freeze SLA)

During this lane's cold compile, lane W984eu applied minimal unblock
edits to this file (missing `end` TokenMissingError freezing the
`test/eu_ai_act` census; boundary fixture placement; `Refusal` struct
module `Xaas.Actuation.Refusal`). Disclosed per the SLA; W984fa owns the
file and repaired the remaining fixture: the umbrella tamper leg
initially used a ONE-entry chain whose tamper is detected only by the
head anchor (`{:tampered, :head}` vs `{:tampered, 0}`); repaired to a
TWO-entry chain tampering the first entry, detected via the successor
link and named exactly `{:error, {:tampered, 0}}`. lib/ untouched.

## Verification (real outputs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fa \
  mix test test/eu_ai_act/art15x_robustness_deepening_test.exs --include eu_ai_act
```

- Run 1: 7/8 (steep-boundary fixture math — repaired by W984eu's
  concurrent edit to m=9.0/eps=2.0; then umbrella tamper-leg contract
  mismatch)
- Final: `Result: 8 passed` — exit 0

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fa \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Census: `Result: 1388 passed, 1 excluded` — exit 0
  (≥ the dispatch floor of 1355; counts as-of these runs, shared moving
  surface)

## Mock gate

`grep -nE "Mock|patch\(|\.expect\("` over the new file → zero hits
(exit 1). Chicago: real `RobustMargin` / `GraphlawWasm.judge_imports/2`
/ `AuditChain` executions over real in-test fixtures; assertions on
final returned state only; zero mocks, zero application-env knobs.

## Tagging convention

`@moduletag :eu_ai_act` only; no `eu_ai_act_open_gap` tags — no line
flipped; deepening of already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  8/8 standalone + census 1388/1388, real commands + real exits.
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract. No commit performed.
- Lane build root: `_build-laneW984fa` — `rm -rf` attempt was **denied
  by the permission system**; the directory remains on disk. Coordinator
  owns deletion at integration (fanout cleanup law).
