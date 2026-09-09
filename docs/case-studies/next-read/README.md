# Next Read

## Purpose

"Next Read" is xaas's flagship case study: a library reading-recommendation system
built for real inside this platform (Ash resources, a 6-factor composite ranking engine,
sentence embeddings with Nx/Bumblebee, reactive LiveViews, and Ash AI MCP tools) to
demonstrate xaas's declarative capabilities end to end, not a mockup or a slide deck alone.
The pitch deck under `presentation/` is the sales artifact that motivated the build; this
README states what of the deck is now real running code versus a disclosed scenario
placeholder, per this repo's no-overclaiming discipline.

## Source-of-truth pitch deck

- `presentation/Qvest Partner Presentation.dc.html` — 24-slide partner pitch,
  imported verbatim from a Claude Design project. **Do not edit.**
- `presentation/deck-stage.js`, `presentation/support.js` — generated
  deck-runtime scaffolding, also verbatim. **Do not edit.**

The deck is the *pitch*, not documentation of the code. It states a case for
the product to a partner audience; it does not describe xaas's actual
implementation and should never be read as if it does. This README is the
implementation-side counterpart.

## Implemented Ash Domain Architecture (`Xaas.Library`)

The domain is fully realized in executable Ash resources (file tree confirmed by
grep against this repo, not carried over from a prior description):

- `Xaas.Library.Book` (`lib/xaas/library/book.ex`) — Catalog book resource grounded in
  `schema:Book`/`bibo:Book` with atomic inventory management (`:borrow_copy`, `:return_copy`),
  declarative calculations (`:is_available`, `:has_multiple_copies`), and PubSub notifications.
- `Xaas.Library.Checkout` (`lib/xaas/library/checkout.ex`) — Circulation borrow actions
  grounded in `schema:BorrowAction`/`prov:Activity` with atomic inventory triggers
  (`lib/xaas/library/changes/decrement_book_inventory.ex`).
- `Xaas.Library.HoldRequest` (`lib/xaas/library/hold_request.ex`) — Real Ash resource for
  hold-queue positions and hold states, grounded in `schema:ReserveAction`/`prov:Activity`
  (`postgres.table "library_holds"`).
- `Xaas.Library.Curation` (`lib/xaas/library/curation.ex`) — Librarian staff spotlights and boosts.
- `Xaas.Library.RecommendationLog` (`lib/xaas/library/recommendation_log.ex`) — Real Ash
  resource that persists recommendation receipts (candidate pool, factor weights, produced
  recommendations) to `library_recommendation_logs`, not just an in-memory computation.
- `Xaas.Library.School` (`lib/xaas/library/school.ex`) — School/tenant grounding resource.
- `Xaas.Library.Config` (`lib/xaas/library/config.ex`) — Dynamic 6-factor weights, grade decay
  tables, and channel naming. *(Owned by a separate concurrent workflow this session — not
  touched by this edit.)*
- `Xaas.Library.Ranker` (`lib/xaas/library/ranker.ex`) — Weighted 6-factor recommendation
  scoring and explainability.
- `Xaas.Library.Embeddings` (`lib/xaas/library/embeddings.ex`) — Real local Nx/Bumblebee
  sentence-embedding inference backing the ranker's `semantic` term.
- `XaasWeb.NextRead.ReaderLive` (`lib/xaas_web/live/next_read/reader_live.ex`) — Realtime
  LiveView UI mounted at `/next-read`. *(Owned by a separate concurrent workflow this
  session — not touched by this edit.)*
- `XaasWeb.A2A.NextReadUserAgent` (`lib/xaas_web/a2a/next_read_user_agent.ex`) — Real
  Agent-to-Agent (A2A, https://google.github.io/A2A/) simulation agent mounted at `/a2a`
  (`A2A.Plug`, `lib/xaas_web/router.ex`). Lets an A2A client drive real Ash
  reads/creates against `Xaas.Library` as a simulated student/librarian persona
  (`as:<user_id>` actor resolution), the same reads/creates a human would trigger through
  `ReaderLive` — not a stubbed protocol handler. Ships with a disclosed authorization gap
  (self-asserted `as:<user_id>` actor claims, no cross-check against the caller's own
  identity) documented in the module's own `@moduledoc`.
- Real seed data: `priv/repo/seeds.exs` seeds `Xaas.Library.Book` rows for `/next-read`
  (`IO.puts("Seeded #{length(fixtures.library_books)} Xaas.Library.Book row(s) for
  /next-read.")`).

### Ash AI MCP tools live in `Xaas.Library`'s own domain module — but are not part of
### Next Read's recommendation/explanation path

`Xaas.Library` (`lib/xaas/library.ex`) declares `extensions: [..., AshAi]` and a real
`tools do` block exposing three read-only query tools (`:list_books`,
`:books_by_grade_band`, `:active_curations_for_grade`) at the repo-wide `/mcp` route
(`AshAi.Mcp.Router`, `lib/xaas_web/router.ex`). `ash_ai` (`{:ash_ai, "~> 1.0"}`, `mix.exs`)
is a real, currently-compiling repo dependency again as of this session, re-added
specifically to back `mix ash_ai.gen.mcp` and this MCP tool surface.

This does **not** contradict this case study's "no LLM in the recommendation/explanation
path" claim: `ash_ai`'s tools here are read-only catalog *lookups* exposed to an external
MCP-speaking client (Claude, Zed, Cursor) — they let an outside agent *query* the catalog,
they are not called *by* the ranker or explainer, and no LLM inference happens inside
`Xaas.Library.Ranker` or the explanation path because of `ash_ai`'s presence. The ranker's
`semantic` scoring term (`lib/xaas/library/embeddings.ex`) uses a real local Nx/Bumblebee
model, not `ash_ai`/`req_llm`, and the explanation path (see
[`ILS-AND-EXPLANATION-SUBSTITUTION.md`](./ILS-AND-EXPLANATION-SUBSTITUTION.md)) remains the
disclosed deterministic template adapter with zero LLM calls of any kind, `ash_ai` included.
`ash_ai` merely being present in `mix.exs`/`mix.lock` (e.g. its optional `req_llm` dependency)
is not evidence any Next Read code path invokes it — grep `lib/xaas/library/ranker.ex` and
`lib/xaas/library/explainer/` for confirmation; neither references `AshAi` or `ReqLLM`.

## Implementation plan status (real file tree, grepped this session)

| Piece | Status | Evidence |
| --- | --- | --- |
| Book/Checkout/Curation/School Ash resources | Real | `lib/xaas/library/{book,checkout,curation,school}.ex` |
| Hold requests | Real | `lib/xaas/library/hold_request.ex`, table `library_holds` |
| Recommendation logging | Real | `lib/xaas/library/recommendation_log.ex`, table `library_recommendation_logs` |
| 6-factor ranker | Real | `lib/xaas/library/ranker.ex` |
| Real local sentence embeddings | Real | `lib/xaas/library/embeddings.ex` (Nx/Bumblebee) |
| Ash AI MCP tools (catalog lookups only) | Real, but not on the ranking/explanation path | `lib/xaas/library.ex` `tools do` block, `/mcp` route |
| A2A user-simulation agent | Real | `lib/xaas_web/a2a/next_read_user_agent.ex`, `/a2a` route |
| Real seed data | Real | `priv/repo/seeds.exs` |
| LiveView UI | Real | `lib/xaas_web/live/next_read/reader_live.ex` |
| ILS integration | Disclosed fixture substitution | `ILS-AND-EXPLANATION-SUBSTITUTION.md` |
| LLM explanation generation | Disclosed template substitution, zero LLM calls | `ILS-AND-EXPLANATION-SUBSTITUTION.md` |
| Playwright e2e coverage | Real | `e2e/next-read-ml.spec.js` |

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

## What is real: the ranker & ML engine

The ranker's dynamic formula is implemented for real with zero hardcoded constants:

```
score = w.collab*collab + w.semantic*semantic + w.gradeFit*gradeFit + w.available*available + w.diversity*diversity + w.curation*curation
```

- The `semantic` term is backed by real local sentence embeddings computed with
  Nx/Bumblebee — a genuine embedding model run locally, not `ash_ai`/`req_llm`
  (see the ash_ai distinction above).
- Live reactive grade changes dynamically update scores and candidate ordering.
- Every produced recommendation is persisted as a real
  `Xaas.Library.RecommendationLog` row (candidate pool, factor weights, output) —
  an auditable receipt, not a discarded computation.
- Hold requests (`Xaas.Library.HoldRequest`) are real Ash-backed queue state, not a
  UI-only placeholder.
- Verified end-to-end with Playwright browser tests (`e2e/next-read-ml.spec.js`).

## Interfaces Exposed

1. **Phoenix LiveView** (`/next-read`): Interactive student reading exploration and real-time checkout.
2. **Ash AI MCP Server** (`/mcp`): Exposes `:list_books`, `:books_by_grade_band`, and `:active_curations_for_grade` to external LLM agents (Claude, Zed, Cursor).
3. **Agent-to-Agent Protocol** (`/a2a`): Multi-persona simulation server for conversational workflows.
4. **JSON:API** (`/api/library/books`, `/api/library/checkouts`): Standard REST endpoints.

## Disclosed substitutions

Two integration points are DISCLOSED substitutions, not real external integrations:

- **ILS (library catalog system) integration** — a fixture/template adapter
  standing in for a real ILS connection (e.g. SIP2/NCIP or a vendor API).
- **LLM-based explanation** — a fixture/template adapter standing in for a
  real hosted LLM call; there is no real LLM API call in this path.

Full detail, scope, and the exact adapter boundary live in
[`ILS-AND-EXPLANATION-SUBSTITUTION.md`](./ILS-AND-EXPLANATION-SUBSTITUTION.md).

## See Also

- `presentation/Qvest Partner Presentation.dc.html` — the source-of-truth partner pitch deck.
- [`ILS-AND-EXPLANATION-SUBSTITUTION.md`](./ILS-AND-EXPLANATION-SUBSTITUTION.md) — full disclosure of the ILS and explanation adapter substitutions.
- `docs/claude/diataxis/explanation/ash-is-the-xaas.md` — deep explanation of Ash as the XaaS platform.
- `lib/xaas/library/` — the Ash domain and ranker implementation.
