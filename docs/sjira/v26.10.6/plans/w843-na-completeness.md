# W843 — NOT_APPLICABLE completeness court (eu_ai_act suite)

- Subject: xaas @ `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6` (+ lane file below)
- Lane: W843, v26.10.6 campaign, canonical checkout, no worktree
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW843 mix test test/eu_ai_act/not_applicable_completeness_test.exs --include eu_ai_act`
- Exit: 0 — `Result: 5 passed` (0.00s async / 3.6s sync)

## What landed

`test/eu_ai_act/not_applicable_completeness_test.exs` (new, sole lane file):

- (a) every classification-map key and rule-referenced line id cites a real
  `docs/eu_ai_act/corpus.json` line id (real JSON read, 1068 ids; real AST
  extraction from suite sources);
- (b) every NOT_APPLICABLE disposition carries a non-empty typed
  deployer-class reason (>= 20 chars or non-empty interpolation);
- (c) cross-file partition: no corpus line claimed BOTH evidenced and
  NOT_APPLICABLE across all suite files; plus a real runtime read of
  `Xaas.EUAIAct.TitleVIXIII.Lines` (`not_applicable/0` / `evidenced/0`);
- (d) determinism: extraction and corpus decode are pure — two passes
  byte-identical;
- walker non-vacuity pins (falsifiers for the extractor itself): known
  classification facts per file (`title_ii` NA `5.8/5.1.h.i/5.1.s2`;
  `title_i` evidenced `3.1/1.2.b`; `title_iii` evidenced `9.5.a/14.3.a` + NA
  `14.5/14.5.s2`; `title_iv_v` evidenced `50.1`; `title_vi_xiii` NA
  `86.2/86.3/73.9/74.12/74.13.b`).

## Findings on the backlog item's question

- Title III carries the W535-era per-line NOT_APPLICABLE map (literal
  `{:not_applicable, reason}` values in `evidence_map/0` — `14.4`, `14.5`,
  `14.5.s2`): real, courted here.
- Title II has an *equivalent but different-shaped* completeness discipline:
  clause rules over the 26 real corpus lines plus its own closure test
  ("every corpus line_id classified", asserting 26 == evidenced+NA); no
  literal per-line map — its NA ids surface from `id in [...]` guards and are
  courted here.
- Extraction fact counts (from the run): title_i evidenced 21, title_ii NA 7,
  title_iii evidenced 12+ / NA 3, title_iv_v evidenced, title_vi_xiii NA 6.

## Verification ladder

- Narrow: the new file, 5 tests, exit 0, `Result: 5 passed`.
- Boundary: full `mix test test/eu_ai_act --include eu_ai_act` —
  `1352/1353 passed`, 1 failure = pre-existing honest-gap flunk
  (`EUAI-ACT 49.3 — OPEN_GAP` in `title_iv_v_test.exs:453`, flunks by
  design; present independent of this lane — lane file adds no lib code).
- Determinism double-run: identical.

## Generated vs handwritten

Handwritten (no framework generator profile for meta-courts); no generated
surface touched; no mocks (Jason decode of real corpus, real AST of real
sources, real module dispatch).

## Standing / gaps

- Standing: ALIVE on the exact subject above (observed execution, real
  output).
- Typed gaps:
  - AST extraction is a static under-approximation: article-range NA rules
    (e.g. title_i "Art.1/2 scope", title_iv_v Arts 28-58) resolve ids at
    runtime from corpus lines, so those NA populations are courted only via
    each suite's own closure tests, not id-by-id here. Typed as
    STATIC_UNDERAPPROX_W843.
  - `Code.compile_file` fallback for the title_vi_xiii runtime read degrades
    to AST-only facts when compile raises mid-suite. Typed
    RUNTIME_READ_FALLBACK_W843.
  - Pre-existing failure disclosed: 49.3 OPEN_GAP flunk (not session
    introduced; full-dir include surfaces it by design).
- Lane build root `_build-laneW843` left in place for the coordinator
  (delete blocked by lane permissions); it is a lease, not an asset — delete
  at integration.
