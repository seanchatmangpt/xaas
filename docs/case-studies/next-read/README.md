# Next Read

## Purpose

"Next Read" is xaas's first case study: a library reading-recommendation system
built for real inside this platform (Ash resources, a ranking engine, realtime
LiveViews) to demonstrate xaas's capabilities end to end, not a mockup or a
slide deck alone. The pitch deck under `presentation/` is the sales artifact
that motivated the build; this README states what of the deck is now real
running code versus still a scenario placeholder, per this repo's
no-overclaiming discipline.

## Source-of-truth pitch deck

- `presentation/Qvest Partner Presentation.dc.html` — 24-slide partner pitch,
  imported verbatim from a Claude Design project. **Do not edit.**
- `presentation/deck-stage.js`, `presentation/support.js` — generated
  deck-runtime scaffolding, also verbatim. **Do not edit.**

The deck is the *pitch*, not documentation of the code. It states a case for
the product to a partner audience; it does not describe xaas's actual
implementation and should never be read as if it does. This README is the
implementation-side counterpart.

## Implementation plan (Xaas.Library domain)

- `Xaas.Library.Book`, `Xaas.Library.Checkout`, `Xaas.Library.Curation` — Ash
  resources under `lib/xaas/library/`.
- `lib/xaas/library/ranker.ex` — the weighted recommendation ranker.
- `lib/xaas_web/live/next_read/` — realtime LiveViews for the reader-facing
  and staff-facing UI.

As of this writing these paths are the planned layout for the case study;
treat this README as the charter, not a claim that every file already exists
on disk — check the actual tree (`lib/xaas/library/`,
`lib/xaas_web/live/next_read/`) before citing a specific module as shipped.

## Slide claims: real vs. scenario placeholder

**Slide 4 baselines are SCENARIO PLACEHOLDERS, not real district data.** The
deck's "38% of titles circulated," "1 in 5 students," and "0 personalized
suggestions" figures describe the deck's own fictional partner district,
invented for the pitch narrative. They are not measured facts about any real
library system, and nothing in this repository treats them as such. Do not
cite these numbers as evidence of anything xaas has observed or measured.

Any other quantitative or qualitative claim on other slides (adoption
projections, ROI framing, testimonial-style copy, etc.) is likewise pitch
narrative unless this README or a linked doc explicitly states it maps to
running code.

## What is real: the ranker

The ranker's formula is implemented for real, not aspirational:

```
score = 0.34*collab + 0.26*semantic + 0.16*gradeFit + 0.10*available + 0.06*diversity + 0.09*curation
```

The `semantic` term is backed by real local sentence embeddings computed with
Nx/Bumblebee — a genuine embedding model run locally, not a keyword or
tag-overlap heuristic standing in for "semantic."

## Disclosed substitutions

Two integration points are DISCLOSED substitutions, not real external
integrations, following the same disclosure pattern as
`docs/AWS-CHAPTERS-SUBSTITUTION.md` in this repo:

- **ILS (library catalog system) integration** — a fixture/template adapter
  standing in for a real ILS connection (e.g. SIP2/NCIP or a vendor API).
- **LLM-based explanation** — a fixture/template adapter standing in for a
  real hosted LLM call; there is no real LLM API call in this path.

Full detail, scope, and the exact adapter boundary live in
[`ILS-AND-EXPLANATION-SUBSTITUTION.md`](./ILS-AND-EXPLANATION-SUBSTITUTION.md)
(authored alongside this README).

## Explicitly out of scope

To prevent scope creep from the pitch deck's ambition into the implementation
plan:

- No real LLM API call anywhere in the recommendation or explanation path.
- No pgvector — embeddings are computed and compared with local Nx, not
  stored in or queried via a vector-search Postgres extension.
- No `ash_ai` — this repository dropped `ash_ai` as a dependency; Next Read
  does not reintroduce it.

## See Also

- `presentation/Qvest Partner Presentation.dc.html` — the source-of-truth
  partner pitch deck.
- [`ILS-AND-EXPLANATION-SUBSTITUTION.md`](./ILS-AND-EXPLANATION-SUBSTITUTION.md)
  — full disclosure of the ILS and explanation adapter substitutions.
- `docs/AWS-CHAPTERS-SUBSTITUTION.md` — this repo's precedent disclosed
  substitution pattern that the Next Read substitutions follow.
- `lib/xaas/library/` — the Ash domain and ranker implementation.
