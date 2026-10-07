# W984by — Corpus evidenced-line deepening wave 7 (2 lines, 6 courts)

Lane W984by · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per
dispatch). Build root `_build-laneW984by` — cold compile, pinned asdf
toolchain (PATH=$HOME/.asdf/shims), `MIX_ENV=test`. **Build root deleted
by this lane at integration** (see Standing).

## Gap-inventory provenance

All five prior wave receipts read fresh before picking:
`w981t-corpus-deepening.md` (26.6 / 14.4.b / 15.5.s3),
`w982z-corpus-deepening-2.md` (26.7, 27.1.c/d),
`w984a-corpus-deepening-3.md` (10.2.h / 10.3),
`w984p-corpus-deepening-4.md` (26.1, 26.9/Art 13),
`w984al-corpus-deepening-5.md` (9.4, 13.3.e). The dispatch's taken list
(27.3, art50, 15.3, art73, art86/counterfactual, art99, title-II, 26.2,
26.5) was excluded; the evidence maps
(`test/eu_ai_act/title_iii_test.exs`, `title_vi_xiii_test.exs`,
`title_i_test.exs`) were re-read live. Chosen lines are EVIDENCED,
court-free, and non-GraphQL-adjacent:

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 10.2.f / 10.2.g | data-governance bias examination + detect/prevent/mitigate via the sliced-W1 gate (W502) | MEASUREMENT LIVENESS of the executed bias measure: (1) the REFUSED_BIAS_THRESHOLD envelope carries the real executed measurement — `w1_proxy` equals the independent `sliced_w1/3` recomputation, `epsilon_bias` echoes the call argument, and the same biased population flips ADMITTED ↔ typed refusal exactly at the measured value (strict `w1 > epsilon` boundary); (2) the seeded projection machinery is live — `w1_proxy` genuinely varies across seeds and across projection counts k while the verdict stays stable, same-seed reruns bit-identical; (3) scale equivariance — scaling every feature by c>0 scales the measured W1 by exactly c | `test/xaas/deepening/art_10_2fg_bias_gate_measurement_liveness_test.exs` (3 courts) | a hardcoded/stale epsilon or envelope drift fails court 1 while verdict-level courts pass (any epsilon on the same boundary side gives the same verdict); freezing the seed or ignoring `:projections` fails court 2 while single-seed courts still pass; a normalized/clipped/non-homogeneous statistic fails court 3 while verdict courts still pass |
| 27.1.f | measures foreseen in case of risk materialisation (FRIA inventory) | BINDING LIVENESS of the FRIA's materialisation inventory: the cited safeguards EXECUTE and deliver the claimed protections — DatasetAdmission refuses `REFUSED_BIAS_THRESHOLD` on a real biased population matching the FRIA's own `basis` string; EuAiActAdmission refuses a real Art. 5 candidate; the zero-PII claim holds on executed behavior (undeclared field never changes the verdict); the halt-to-safe-state safeguard (QuiescentStop over a real Provider row) executes, is a no-op on re-halt, and leaves the subject in its safe state; a real materialised risk (executed Art. 5 refusal + real Ash.Policy.Authorizer denial over real Postgres) derives a typed IncidentReport classification (INFRINGES_UNION_LAW + MALFUNCTION, HARM_TO_RIGHTS absent) and the authority channels stay honestly `:PREPARED_NOT_TRANSMITTED` while the internal channel records; incident identity is content-derived (deterministic, tracks its evidence) | `test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs` (3 courts) | cited-symbol drift (bias gate stops returning the cited basis atom, admission gate stops refusing) fails court 1 while path-existence courts pass; a hardcoded classification or a silently-transmitting authority channel fails court 2 while shape courts over hand-built reports still pass; a timestamped (non-content-derived) incident id fails court 3's causality leg while fria determinism courts still pass |

Overlap discipline: 10.2.h/10.3 (W984a) covered gate ORDER and the eta
causality and the ADMITTED-envelope identity; this lane covers the BIAS
refusal envelope + seeded-measurement liveness + scale equivariance —
complementary, non-overlapping. 27.3 (W704) covers the stop surface's
typed refusals/determinism and fria/0-halt composition; 27.1.f here binds
the FRIA's full materialisation chain (executed safeguards + incident
derivation + honest channel) as binding-liveness, which no prior court
asserted.

## Verification (real tails)

Lane files standalone (before census):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984by \
  mix test test/xaas/deepening/art_10_2fg_bias_gate_measurement_liveness_test.exs \
           test/xaas/deepening/art_27_1f_materialisation_safeguard_binding_test.exs \
  --include eu_ai_act
```

- Run 1: `6 passed` — exit 0 (after the disclosed repair below)
- Census command, run ×3 green:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984by \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Run 1: `Result: 42 passed` — exit 0
- Run 2 (random seed): `Result: 42 passed` — exit 0
- Run 3 (foreground re-witness): `Result: 42 passed` — exit 0

(42 = 14 deepening files × 3 courts, counted per-file on disk at
integration; pre-lane census was 36, so +6 = 42 is this lane's delta.
The task brief's "expect ~39" was stale — two sibling files (26.2, 26.5,
6 courts) had already landed when this lane's first census executed;
36+6=42, no missing sibling tests. My 6 are provably in the census count:
standalone 6/6 + 14×3=42.)

## Disclosed repair history (genuinely-new contract facts learned)

1. `QuiescentStop` on a real `Provider` leaves the subject at
   `:suspended`, not a literal `:quiescent` status — the attractor's
   "quiescent" is realized as the Provider resource's safe state
   `:suspended`. Court adjusted to assert the real contract
   (`:suspended`), intent unchanged.
2. Direct standalone runs without `--include eu_ai_act` exclude the
   tagged tests entirely (`0 tests, 6 excluded`) — the census filters are
   load-bearing for lane files, witnessed.

## Disclosed finding (typed, NOT fixed — outside this lane's contract)

fria/0's authority-channel right entry
(`lib/xaas/semantics/oversight_governance.ex`, right
`:access_to_effective_remedy_authority_channel`) still carries prose
"No incident-reporting seam exists", written pre-W538. The TRANSMISSION
gap the entry points at is still real (`AuthorityChannel` authority
transmit is typed OPEN, `:PREPARED_NOT_TRANSMITTED` — court 2 witnesses
this), so the entry's OPEN_GAP status is honest; the prose about the
seam is stale relative to the landed `IncidentReport.build/2` +
`AuthorityChannel.registry/1` surfaces. Flagged for the FRIA/corpus
owner; lib/ untouched by this lane.

## Mock gate

`grep -nE "Mock|patch\(|\.expect\("` over both new files → zero hits.
Chicago: real gate executions over real seeded populations, real Ash
policy denial over real sandboxed Postgres, real QuiescentStop over a
real Provider row, real IncidentReport/AuthorityChannel executions;
assertions on final returned state only.

## Tagging convention

Both files carry `@moduletag :eu_ai_act`; runs used the census filters.
No `eu_ai_act_open_gap` tags — no line flipped; this lane deepens
already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  6/6 standalone + census 42/42 ×3 (two seeds), real commands + real
  exits.
- `_build-laneW984by`: **deleted by this lane at integration** (cleanup
  law) — witnessed post-deletion: `ls: _build-laneW984by: No such file or
  directory` from the repo root, exit 0 on the `rm -rf`. (Other lanes'
  `_build-lane*` roots remain on disk for their owners/coordinator.)
- Real contract facts witnessed (worth retaining): Provider's
  quiescent safe state is `:suspended`; `IncidentReport` classification
  never yields HARM_TO_RIGHTS from a bare EUAIA atom (needs
  `rights_harm: true` or a `*_RIGHTS_`/`*_HARM_` atom string);
  `AuthorityChannel.transmit/2` by atom id resolves through
  `registry/0`; sliced-W1 is exactly 1-homogeneous under positive
  feature scaling (projections are scale-equivariant); direct standalone
  runs of tagged deepening files need `--include eu_ai_act` or everything
  is silently excluded.
- Census is a shared moving surface; the 42/42 is as-of these runs
  (receipt-cited counts re-read at use time per no-overclaiming).
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract.
