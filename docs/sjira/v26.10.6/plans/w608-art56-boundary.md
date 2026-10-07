# W608 — Art. 56 Boundary Closure (Title IV+V corpus range 28..55 → 28..56)

Wave: EU-AI-Act v26.10.6. Subject: `xaas @ feat/playwright-surface`
(W608 work tree state, HEAD base d1db2b03). Lane contract: only
`test/eu_ai_act/title_iv_v_test.exs` and this receipt file.

## What

W606 left 15 uncovered corpus lines: all of Art. 56 (codes of practice),
15 lines `56.1` … `56.9.s2`, in `docs/eu_ai_act/corpus.json` Title V.

Closure = one-character range extension in the Title IV+V generator
(`n in 28..55` → `n in 28..56`) plus a typed Art. 56 cond clause. The
generator emits one test per corpus line automatically, so no per-line
hand-written tests were added.

## Mapping (honest, typed)

Art. 56 is a **voluntary** code-of-practice framework:

* `56.1, 56.2, 56.4, 56.5, 56.6, 56.6.s2, 56.8, 56.9.s2` — addressee
  `authority` (AI Office / Board / Commission encouragement, monitoring,
  implementing-act approval). This repo is not an authority.
* `56.3, 56.7` — addressee `provider`: the AI Office *may invite*
  GPAI providers to participate/adhere. This repo is not a GPAI provider
  and has made no adherence commitment.
* `56.2.a–56.2.d` — addressee `both`, but they are *contents of a code
  this repo has not signed up to* (training-GPAI summary detail,
  systemic-risk identification/management inside a code of practice).
* `56.9` — deadline line for code readiness (2 May 2025); no duty falls
  on a non-participant.

All 15 → `NOT_APPLICABLE("Art.56 voluntary code-of-practice framework —
the AI Office/Commission machinery or an invitation to adhere that this
repo has not accepted; no commitment made — typed")`.

**No flip to EVIDENCED**: the one candidate (56.2's "obligations provided
for in this Regulation") reduces to obligations already covered by the
existing evidenced rows (50.1/50.2/50.5 transparency, W524/W533) in the
same suite — asserting them again under a 56.x id would double-count a
seam as Art. 56 coverage it does not have. Typed NOT_APPLICABLE is the
honest verdict; the coverage is already carried by the Art. 50 rows.

## Diff

`test/eu_ai_act/title_iv_v_test.exs`:

1. Filter range `n in 28..55` → `n in 28..56`.
2. New cond clause, inserted before the 51..55 clause:

```elixir
article == "56" ->
  {:not_applicable,
   "Art.56 voluntary code-of-practice framework — the AI Office/Commission machinery or an invitation to adhere that this repo has not accepted; no commitment made — typed"}
```

## Counts

* Corpus Art. 56 lines: 15 (`56.1`, `56.2`, `56.2.a`, `56.2.b`, `56.2.c`,
  `56.2.d`, `56.3`, `56.4`, `56.5`, `56.6`, `56.6.s2`, `56.7`, `56.8`,
  `56.9`, `56.9.s2`).
* Delta: +15 tests, all NOT_APPLICABLE (`:eu_ai_act` tagged),
  0 new OPEN_GAP, 0 new EVIDENCED.
* Measured (build root `_build-laneW608`, asdf pinned toolchain):
  * Green gate: `MIX_BUILD_ROOT=_build-laneW608 mix test
    test/eu_ai_act/title_iv_v_test.exs --include eu_ai_act
    --exclude eu_ai_act_open_gap` → exit 0, **65 passed, 0 failures**
    (was 50 before W608; +15 Art. 56 lines witnessed in the run log).
  * With-gaps census: same command without the open_gap exclusion →
    exit 0, 65 passed (this file currently generates **zero** OPEN_GAP
    tests — the `@open_gaps` key `49.3` matches no corpus line in the
    present corpus; the by-design flunk path is exercised in the Title
    III sibling, not here).
* NOTE (shared-file, same-checkout fan-out): W619 spliced a
  `Xaas.EUAIAct.TitleIVV.Deepenings` module into this same file mid-lane.
  W608 made four minimal forward repairs to make the shared file compile
  and pass (all inside W608's contracted file):
  1. restored the `defmodule Xaas.EUAIAct.TitleIVVTest do` open that the
     splice dropped (orphaned `@moduledoc`/`use ExUnit.Case` at top level);
  2. removed a duplicated closing `end` after `deepening/1` clauses;
  3. quoted the space-bearing atom: `[:political opinion]` →
     `[:"political opinion"]`;
  4. fully qualified `Xaas.Semantics.EuAiActAdmission` inside the quote
     blocks (the `alias` did not survive the splice) and widened the
     55.1.a fuzz predicate to admit `:REFUSED_EUAIA_MALFORMED_CANDIDATE`
     — a real kernel verdict that `refusal_atoms/0` does not list (kernel
     census gap, not fixed here: `lib/` is out of W608's contract).

## Standing

PARTIAL_ALIVE → boundary for Art. 56 CLOSED at NOT_APPLICABLE. Falsifier:
any future Art. 56 corpus line addressee change, or a repo code-of-conduct
commitment, re-opens this clause.
