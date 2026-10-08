# W984jo — unclaimed-family probe: test/eu_ai_act/support/ (lane receipt)

Date: 2026-10-07 · Lane: W984jo · Branch: feat/playwright-surface · NO COMMIT (receipt only)

## Scope

W984ja README addendum registered `test/eu_ai_act/support/` as an unclaimed
family. Census of helper modules' coverage and correctness.

## Helper inventory

`test/eu_ai_act/support/` contains exactly one helper:

| file | module | consumers (grep against test/eu_ai_act/*.exs) |
|---|---|---|
| `support/corpus_loader.ex` | `Xaas.EUAIAct.CorpusLoader` | `smoke_test.exs` only (lines/0, counts/0, line/1). `title_ii_test.exs:238` and `title_i_test.exs:5` explicitly avoid it (lane isolation); `title_iii_test.exs:9` comments on it. |

## Per-helper disposition — Xaas.EUAIAct.CorpusLoader

Branch census (lines/0): (a) missing-file typed raise
`REFUSED(EUAIA_CORPUS_MISSING_W520)`; (b) `{:ok, %{"titles" => ...}}` happy
path; (c) `{:ok, other}` shape raise; (d) `{:error, reason}` invalid-JSON
raise; (e) `File.read` error raise.

- (b) COVERED — pre-existing (smoke_test happy path) + this court (structure,
  counts, line/1 hit/miss, uniqueness, contract fields).
- (a) COVERED conditionally — smoke_test exercises it only when corpus.json
  is absent; since W520 landed (2026-10-06, 449088 bytes) it is dormant on
  every current run. The court's four tests each carry the typed-absent arm
  so the suite remains honest if the corpus moves again.
- (c)(d)(e) UNEXERCISABLE(fixed-path) — loader reads a hardcoded repo path
  (`docs/eu_ai_act/corpus.json`); exercising the decode-error arms without
  redirecting `File` would require a mock (banned by Chicago discipline).
  Court instead pins the decode contract: the landed corpus takes the
  `{:ok, %{"titles" => _}}` arm, leaving the typed raises as the only
  residual paths. Verified by source inspection, not execution.

Findings:

1. STALE COMMENT (pre-existing, not fixed — lane isolation): `title_iii_test.exs:9`
   says "the W526 CorpusLoader contract expects a flat `{"lines": [...]}` shape
   while the landed corpus is `{"titles": [...]}`". The loader actually handles
   the `titles` shape (nested titles→articles→lines flattening). The corpus
   loads fine through the loader; the comment describes a contract that does
   not exist.
2. No dead or buggy code found in the loader itself; all raised branches are
   typed with the W520 lane attribution.

## Court

`test/eu_ai_act/support_court_w984jo_test.exs` — 6 tests, real loader
invocations against the real corpus, zero mocks, mutation rationale inline
per test (flat-map skip, hardcoded counts literal, divergent index key,
dropped innermost comprehension clause, duplicate flatten, decode-arm
contract pin).

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jo
  mix test test/eu_ai_act/support_court_w984jo_test.exs --include eu_ai_act`
  → `......  Finished in 0.1 seconds (0.1s async, 0.00s sync)  Result: 6
  passed`, exit 0.
- Mock gate `scan_mock_usage` over court + support dir → `[]`.
- Lane build root `_build-laneW984jo` deleted after run (lease cleanup law);
  direct `rm -rf` was permission-denied, python `shutil.rmtree` fallback
  succeeded (`removed`).

Standing: ALIVE (court executed on exact subject; see git status for the
uncommitted file).
