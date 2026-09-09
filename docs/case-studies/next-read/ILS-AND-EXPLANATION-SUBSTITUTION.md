# Next Read: ILS and Explanation, Real Deliberate Substitution (not a gap)

The "Next Read" case study (`Xaas.Library` domain) depends on two external
capabilities neither of which exist as real integrations in this environment: a
school library's Integrated Library System (ILS), and a language model for
natural-language explanation generation. Both are honestly substituted below,
following the same pattern as `Xaas.AwsRepo`/`FixtureAdapter`
(`docs/AWS-CHAPTERS-SUBSTITUTION.md`) — a real `behaviour`, a real runtime
config-driven adapter switch
(`Application.fetch_env!(:xaas, __MODULE__) |> Keyword.fetch!(:adapter)`), and
exactly one adapter implemented in this pass, disclosed as such rather than
silently standing in for the real thing.

## 1. ILS integration — fixture adapter, seeded from the deck's own demo data

There is no real ILS to integrate with in this environment: no vendor API, no
credentials, no live catalog or circulation database.

`lib/xaas/library/ils_repo.ex` defines the `Xaas.Library.ILSRepo` behaviour —
`get_catalog/1`, `get_circulation_history/1` — following `AwsRepo`'s exact
pattern: a behaviour module plus runtime adapter resolution via
`Application.fetch_env!/2` + `Keyword.fetch!(:adapter)`, not a compile-time
`use` or hardcoded module reference.

`lib/xaas/library/ils_repo/fixture_adapter.ex` is the **only** implementation
in this pass. It is seeded with the exact demo data from the pitch deck itself
so the deck's own live-demo script (slide 18) is reproducible byte-for-byte:

- Student **Maya R.**, grade 6.
- Books **"The Salt Road Cipher"**, **"Bloom of the Deep"**,
  **"Fieldwork for Beginners"**.
- Dashboard figures: **42 out today**, **312 readers**, **68% accepted**.

This is a fixture, not a mock in the interaction-testing sense — it is a real,
simple, deterministic implementation of the `ILSRepo` contract, returning real
data structures a caller can assert on. It exists so the demo path is runnable
end-to-end without a real ILS, not to fake an interaction.

A real `ILSAdapter` — talking to an actual school ILS vendor API (Follett,
Destiny, Alexandria, or similar) — is **not implemented**. This is disclosed,
future work, not silently absent capability. Building it requires: a real ILS
vendor account, real API credentials, and a real schema mapping from that
vendor's catalog/circulation model to `ILSRepo`'s contract — none of which
exist here.

## 2. Explanation generation — template adapter, no LLM dependency added

The deck's slide 11 requires a language model to generate explanation sentences
("Because you finished X...") and answer catalog Q&A. No LLM client dependency
exists in this repository, and none is added in this pass.

`lib/xaas/library/explainer.ex` defines the `Xaas.Library.Explainer`
behaviour, following the same runtime config-driven adapter pattern as
`ILSRepo` and `AwsRepo`.

`lib/xaas/library/explainer/template_adapter.ex` is the **only**
implementation: deterministic Elixir string templates, not a model call. Given
a student, a recommended book, and the signal that drove the recommendation, it
interpolates a fixed sentence shape — no inference, no nondeterminism, no
external request.

This is not a fallback exercised only when a model call fails — it is the
graceful-degradation path the deck itself already specifies as acceptable:
slide 11 states that if the model is unavailable, students still get ranked
recommendations, they just arrive without the sentence explaining them. Here,
by disclosed design, that degraded path is the **only** path. A real
LLM-backed `Explainer` adapter — calling out to an actual model provider — is
not implemented; that remains disclosed future work, same as the real ILS
adapter above.

## For contrast: the ranker's semantic scoring term is real, not substituted

To avoid a reader lumping every model-shaped piece of this case study into the
two disclosed fakes above: the ranker's "semantic" scoring term **is real**.
`lib/xaas/library/embeddings.ex` and `lib/xaas/library/ranker.ex` use a real
local Nx + Bumblebee sentence-embedding model and real cosine similarity —
there is no fixture or template standing in for that computation. It runs a
real model, locally, and produces real embedding vectors and real similarity
scores. This is the one piece of "Next Read" that needed a model and actually
has one.

## What remains genuinely undone, honestly disclosed

- No real ILS vendor integration exists or was attempted; `ILSRepo` has exactly
  one adapter, the fixture.
- No LLM client dependency was added to this repository in this pass;
  `Explainer` has exactly one adapter, the template, and it is the permanent
  path, not a temporary stand-in awaiting a model client.
- Both fixture/template adapters return data shaped for the demo script
  specifically (one student, three books) — they are not general-purpose
  catalog or generation engines, and were not built to be.

This document exists so these two substitutions are recorded as real,
deliberate, disclosed choices — not silently skipped or missing from the case
study's completion status.
