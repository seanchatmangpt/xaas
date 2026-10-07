# W710 — Art 86 Rights Deepening Court (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` @ `a0723bf6` (canonical checkout, no worktree)
- **Lane**: W710, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW710` (437M, left in place for coordinator cleanup — lane `rm` was permission-denied in this session)
- **Backlog item**: title_vi_xiii Art 86 (86.1–86.3) rows dispositioned "compliance
  obligations, no gap" via W648b, but no composed court. This lane composes the
  court end-to-end over the REAL modules.

## μ / diff

Handwritten (irreducible residue): one new test file, no lib changes.

- `test/eu_ai_act/art86_rights_deepening_test.exs` (NEW) — `@moduletag :eu_ai_act`, no mocks, real module composition:
  - **(a) 86.1 explanation**: real `EuAiActAdmission.admit/1` refusal
    (`{:error, :REFUSED_EUAIA_MANIPULATIVE}`) → decision record →
    `Counterfactual.run/2` + `Counterfactual.evaluate/3`; asserts human-legible
    anatomy: named article (`describe/1` =~ `~r/^Art\. \d/`), refusal atom,
    φ attribution (`cf.explanation` names the flipped check `lawful_practice`).
  - **(b) reproducibility**: same explanation binary-equal across 3 replays
    (`changed? == false`, identical check log) — right of access implies
    deterministic reproducibility.
  - **(c) 86.2 complaint path**: `IncidentReport.build/2` on an
    alleged-infringement receipt (`refusal_atom` + `rights_harm: true`) →
    `[:INFRINGES_UNION_LAW, :HARM_TO_RIGHTS]`; `AuthorityChannel.transmit/2`
    to a `:authority` channel → `:PREPARED_NOT_TRANSMITTED` (typed OPEN
    escalation shape, never silently "sent").
  - **(d) non-existent decision id**: honest typed gap — no id-lookup surface
    exists on any composed module (witnessed via `function_exported?/3`
    refutations); a fabricated record is refused by the real
    `{:error, {:record_outcome_mismatch, {:expected, ..., :got, ...}}}` typed
    refusal. No invented surface.

## Commands / exits (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW710 \
  mix test test/eu_ai_act/art86_rights_deepening_test.exs --include eu_ai_act

Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 4 passed
[exited with code 0]
```

Tests: 4/4 passed
(`real admission refusal composes into a decision record whose anatomy is
human-legible`, `the same explanation is derivable deterministically across 3
replays`, `alleged-infringement receipt builds an incident and prepares (never
transmits) to authority`, `typed refusal for a fabricated record; no invented
id-lookup surface`).

Mid-flight repair (witnessed, per W672 flake-adjudication intercept):
`@checks` module attribute holding an anonymous function failed to compile
(ArgumentError: cannot escape function) — same bug class as W641
art12_chain_court; fixed by moving the list into `defp checks/0`. Second
repair: `describe/1` strings say `Art. 5(1)(a)…`, not `Article` — assertion
tightened to `~r/^Art\. \d/`. Final run green on both fixes.

## Standing

- **Art 86.1**: ALIVE — composed court over real admission + counterfactual
  surfaces; explanation anatomy witnessed (named article, refusal atom, φ
  attribution), deterministic x3.
- **Art 86.2**: ALIVE-with-typed-caveat — complaint classification is real and
  derived; authority transmission remains honestly
  `PREPARED_NOT_TRANSMITTED` (no authority endpoint exists; typed OPEN per
  corpus 73.4–73.5). Same caveat as the W538/W625 Art 73 rows.
- **Art 86.3**: unchanged W648b disposition (legal scoping provision) — this
  court adds the honest no-decision-id-registry gap witness (part d) rather
  than an invented lookup surface.
- **Verification ladder**: narrow (module composition unit court) — no mocks,
  real BEAM execution over real modules.

## Falsifier

Any of: the anatomy assertions regress (describe/1 loses the `Art. N` prefix,
explanation no longer names the flipped check); a replay becomes
non-deterministic (binary-different explanation across the 3 replays);
`IncidentReport.build/2` mis-classifies an EUAIA-refusal receipt; the
authority transmit returns anything other than `PREPARED_NOT_TRANSMITTED`;
or an id-lookup surface appears without a corresponding typed-refusal court.

## Replay

```
cd /Users/sac/xaas && git checkout a0723bf6 -- test/eu_ai_act/art86_rights_deepening_test.exs
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW710 \
  mix test test/eu_ai_act/art86_rights_deepening_test.exs --include eu_ai_act
# expect: Result: 4 passed
```

Not committed (lane rule: coordinator owns transitions/commits).
