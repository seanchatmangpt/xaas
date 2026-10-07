# W787 — Embedding Deepening (Next Read sentence-embedding path)

- **Standing**: PARTIAL_ALIVE → verified ALIVE at the module level (test-executed).
- **Lane**: W787, xaas v26.10.6, canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`, base HEAD `a0723bf6`.
- **Date**: 2026-10-07
- **Verdict**: The Next Read embedding path is **real and test-executed**, not stubbed. No UNSUPPORTED receipt needed. The "backed by sentence embeddings" claim is grounded: a deterministic, offline, 384-dim Nx hash projection (`Xaas.Library.Embeddings.embed/1`), adapted for ash_ai's `vectorize` DSL by `Xaas.Library.EmbeddingModels.LocalNx` (declared dimensions 384, `generate/2` total), feeding `Xaas.Library.Ranker`'s `semantic` factor via `compute_semantic_score/2` (cosine, clamped to [0,1]).

## What was executed

- New test file `/Users/sac/xaas/test/xaas/library/embedding_deepening_test.exs` — 12 tests, Chicago-style, real module calls only, zero mocks/fakes (mock vectors banned and not used).
- Run command (real tail):
  ```
  $ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW787 \
      mix test test/xaas/library/embedding_deepening_test.exs
  Finished in 0.3 seconds (0.3s async, 0.00s sync)
  Result: 12 passed
  ```
- Note: two earlier runs failed to compile for causes **outside this lane's files** and are disclosed: (1) W792's in-flight `lib/xaas/platform/route_feature_flags.ex` transiently had a duplicate `patch /:id` JSON:API route (transformer `ValidateNoOverlappingRoutes` refused; W792 fixed it at 04:12); (2) one run hit my own syntax error (`}` instead of `end`), fixed forward.

## Coverage per backlog item

- **(a) Determinism, identical text**: `Embeddings.embed/1` on identical text returns a bit-identical 384-float vector across 3 calls (`v1 == v2 == v3`); distinct texts do not collide; empty/punctuation-only texts deterministically return the zero vector as `{:ok, _}` (total function, single clause, `@spec {:ok, list(float())}` — no failure arm exists).
- **(b) Rank integration, real factor math**: `Ranker.compute_semantic_score/2` on real embeds — disjoint single-token texts → orthogonal hash projections → raw cosine 0.0 → clamped 0.5 (assert_in_delta 0.5 ±1e-6); identical text → 1.0; stored list embedding consumed verbatim (list arm bypasses re-embedding); composite semantic term is exactly `weights.semantic * cosine` (linear delta verified via `Xaas.Library.Config.weights/1`, weight > 0); `LocalNx.dimensions/1 == 384 == length(embed/1)` dimension contract.
- **(c) Service-unavailable path — honest typed finding**: **there is no service-unavailable failure path, by construction.** `embed/1` is total and pure (offline Nx hashing, no external model server); `LocalNx.generate/2`'s `{:error, _}` arm was already removed as dead code (disclosed in its comment). The degraded path IS the only path. Tests assert this totality: garbage/nil inputs degrade to deterministic vectors (`LocalNx.generate([nil, "", "  !  ", "ok"], [])` → 4 valid vectors; `nil` ≡ `""`), and `cosine_similarity/2` degrades empty/zero/non-list inputs to typed `0.0`, never a raise. Asserted by calling the real functions, never by faking an outage.
- **(d) Determinism ×2**: covered within (a) — repeated `embed/1` calls and repeated `LocalNx.generate/2` batches are bit-identical (`vectors_a == vectors_b`), identical strings within one batch yield identical vectors.

## Typed gaps / open items

- **GAP(w787-a)**: end-to-end `Ranker.rank_recommendations/2` with real Book rows over the sandbox DB was NOT exercised (existing `test/xaas/library/ranker_test.exs` already covers the full pipeline; this lane scoped to the embedding factor math). Also, per `LocalNx` moduledoc, the pgvector-backed stored-embedding column remains **BLOCKED** on the dev Postgres image lacking the `vector` extension — pre-existing, disclosed in `lib/xaas/library/embedding_models/local_nx.ex` and `lib/xaas/library/book.ex`; on-the-fly embedding path (used here) is unaffected.
- **GAP(w787-b)**: `_build-laneW787` was NOT deleted — `rm -rf` was denied by the session permission system. Left for the coordinator per lane instructions ("else leave for coordinator"). Size: a full test-env compile of xaas (approx. 1–2 GB).
- Environment noise disclosed: PromEx Grafana uploader warnings (nxdomain) during test boot; unrelated to assertions.

## Verification ladder position

narrow (real module calls) → unit — executed and passing. Integration (full rank pipeline) delegated to pre-existing `ranker_test.exs`/`nextread_deepening_test.exs` coverage.
