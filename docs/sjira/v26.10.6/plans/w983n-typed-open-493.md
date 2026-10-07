# W983n — Typed-Open 49.3 Anatomy + Disposition (v26.10.6)

Lane W983n, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`
(canonical checkout, shared, live campaign; no commit — coordinator owns
commits). Build root `_build-laneW983n` (cold, lane-local; deletion attempt
denied by the permission system this lane — left for the coordinator per the
lane-contract fallback, same as W962).

## Task

The register (`w859-typed-gap-register.md`) holds 2 TYPED-OPEN rows. One is
the 49.3 corpus open-gap (CONFIRMED-FINAL by W980j). Anatomy it: what exactly
is the gap, what closure would require, whether closure is xaas-side
executable today or genuinely external; strengthen the row's blocker naming;
TYPED-OPEN stays if genuinely external.

## Lineage read (all `test -f`-verified, read this lane)

- `w779-opengap-tag.md` → `w815-gap-registration.md` →
  `w650c-terminal-census.md` → `w935b` (count capture) → `w962`/`w962b`
  (tag reconciliation; convention `--only eu_ai_act_open_gap`) →
  `w980j-register-close.md` (0 flips, 49.3 CONFIRMED-FINAL).
- Defining receipt: `w815-gap-registration.md` — registered Art. 49(3) as the
  corpus's single typed open gap in `docs/eu_ai_act/corpus-README.md`;
  generating honestly since W779's scope fix.

## Gap anatomy

The gap IS a generated test, not missing code per se:

- `test/eu_ai_act/title_iv_v_test.exs` generates tests from
  `docs/eu_ai_act/corpus.json` at compile time. The cond chain maps corpus
  line 49.3 to `{:open_gap, @open_gaps["49.3"]}` (line 364-366, 385-386),
  which generates `test "EUAI-ACT 49.3 — OPEN_GAP: ..." do flunk(...) end`
  tagged `:eu_ai_act_open_gap` (line 451-456). The flunk row is the typed
  disclosure surface — W815: "the honest refusal shape is the flunk row
  itself, not an invented closure."
- Corpus text (read from `corpus.json` this lane, verbatim): *"Before
  putting into service or using a high-risk AI system listed in Annex III …
  deployers that are public authorities, Union institutions … shall register
  themselves, select the system and register its use in the EU database
  referred to in Article 71."*
- The test-generator's cond chain never reaches the
  `"40".."49"` NOT_APPLICABLE bucket for 49.3 because `@open_gaps` is
  consulted before the article-range buckets (map key beats range bucket by
  cond order). So the OPEN_GAP verdict is a deliberate, declaration-driven
  choice, not a default.

## What closure would require

Two independent external dependencies, either one sufficient:

1. **The Article 71 EU database** — a Commission-operated registry. The
   campaign controls no artifact of it: no deployer-facing machine endpoint
   exists in the repo, the corpus, or upstream (title_vi_xiii_test.exs:126
   already classifies Arts 64-71 authority machinery as `:not_applicable`
   — "EU database administration" is not a system obligation). A local
   "registration seam" (Ash resource or gate module recording "registered in
   the EU database") would not touch the actual registry; it would flip the
   verdict by construction, not by evidence — exactly the vacuity class the
   campaign kills (cf. W770/W980j's deletion of the vacuous pass-through
   approval modules). A gate over an empty subject set (xaas operates no
   Annex III high-risk system) is a zero-information check (composition law:
   zero-information checks carry no bits).
2. **The addressee predicate is an operator fact**: Art. 49(3) binds
   public-authority / Union-institution deployers of Annex III systems. The
   operator (Sean) runs no such deployment. No code xaas can add changes the
   factual predicate; only an operator decision to deploy an Annex III
   high-risk system as a public authority creates a subject for the duty.

## Disposition

**TYPED-OPEN stays.** Closure is genuinely external, not xaas-side
executable today. The register row's status receipt column now cites this
receipt with the precise external dependency naming.

## Register row updated (one row, no flips)

`w859-typed-gap-register.md` 49.3 row, status-receipt column: appended
"+ w983n-typed-open-493.md (blocker anatomy re-derivation: duty is genuinely
external — the Article 71 EU database is a Commission-operated registry with
no deployer-facing machine endpoint the campaign controls, and the duty's
own addressee predicate (public-authority deployer of an Annex III system)
is an operator fact (none exists), so a local registration gate would be a
vacuity-class zero-information check; census invariants re-witnessed ×2 at
this lane's tree)".

## Census invariants re-witnessed (real runs, this lane)

Build: cold `_build-laneW983n`, asdf shims, MIX_ENV=test. No lib/ or test/
edits by this lane; runs witness standing at this lane's tree.

| run | command | result | exit |
|---|---|---|---|
| gated ×2 | `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap` | see tails | 0 |
| census ×2 | `mix test test/eu_ai_act --only eu_ai_act_open_gap` | see tails | 0 |

Real tails:

```
gated run 1 (cold _build-laneW983n compile, ~18 min):
  Result: 1352 passed, 1 excluded
  [exited with code 0]
gated run 2:
  Result: 1352 passed, 1 excluded
  [exited with code 0]
census run 1 (`--only eu_ai_act_open_gap`):
  Result: 0/1 passed, 1352 excluded
  Failed: 1 test
census run 2:
  Result: 0/1 passed, 1352 excluded
  Failed: 1 test
census flunk detail (witnessed run 2 repeat):
  1) test EUAI-ACT 49.3 — OPEN_GAP: Before putting into service or using a
     high-risk AI system listed in Ann (Xaas.EUAIAct.TitleIVVTest)
     test/eu_ai_act/title_iv_v_test.exs:453
     OPEN_GAP: Art.49(3) deployer EU-database registration duty before putting
     into service — no registration seam exists in this repo
     code: flunk("OPEN_GAP: " <> unquote(detail))
(The "Failed: 1" under the census invocation is the by-design flunk marker —
the honest gap count signal, not a regression; the gated run's "1 excluded"
IS the same invariant. Pre-existing compile warnings in
title_vi_xiii_test.exs noted, untouched, not this lane's.)
```

## Standing

ALIVE (documentation-only lane: no code diff, register row strengthened with
blocker anatomy, census invariants re-witnessed ×2). The flunk row itself is
the pinned honest surface and remains intentionally RED under the census
invocation (`--only eu_ai_act_open_gap` → 0/1 passed, the 1 = 49.3 flunk;
honest gap count = 1).

## Replay

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983n \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983n \
  mix test test/eu_ai_act --only eu_ai_act_open_gap
test -f /Users/sac/xaas/docs/sjira/v26.10.6/plans/w983n-typed-open-493.md
grep -c "w983n-typed-open-493" /Users/sac/xaas/docs/sjira/v26.10.6/plans/w859-typed-gap-register.md
```
