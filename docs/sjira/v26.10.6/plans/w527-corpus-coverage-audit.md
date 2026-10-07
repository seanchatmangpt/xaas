# W527 — EU-AI-Act corpus coverage audit (lane W527)

Date: 2026-10-06 · Subject: xaas @ `/Users/sac/xaas` (feat/playwright-surface, uncommitted tree) · Corpus: `docs/eu_ai_act/corpus.json` (1068 line_ids, verified unique)

## Method

Static grep for `EUAI-ACT <id>` is insufficient: every per-title suite is
runtime-parameterized — it reads `corpus.json` at module compile time and emits
exactly one test per iterated corpus line (EVIDENCED / NOT_APPLICABLE /
OPEN_GAP), so coverage is determined by each file's title filter, not by
literal id strings. I replicated each file's iteration predicate statically and
verified the emit-one-test-per-line shape by reading the generation loops
(title_i_test.exs `for line <- titles_i_lines` + cond with `true ->` catch-all;
identical shape in title_iii / title_iv_v / title_vi_xiii).

Runtime enumeration was attempted first (`mix test test/eu_ai_act --trace`)
and is currently BLOCKED: `test/eu_ai_act/title_i_test.exs:165` fails to
compile — `%{features: %{x0 => 1.0 * i}...` references an undefined variable
`x0` (a string key `"x0"` was intended). Until that single-token fix lands,
the whole `test/eu_ai_act/` suite aborts at compile, so no runtime receipt
exists yet.

## Verdict: INCOMPLETE

- UNCOVERED: 26 — the entire Title II corpus (Art. 5), covered only
  behaviorally via 8 `@partitions` atoms + 3 synthetic ids in
  `test/eu_ai_act/title_ii_test.exs`, which never iterates corpus.json.
- DUPLICATED: 391 — every Title III line is iterated by BOTH
  `title_iii_test.exs` (filter `num == "III"`) and `title_iv_v_test.exs`
  (filter `num in ["III","IV","V"]`); one test per line in each file.
- EXTRA: 3 — `5.catch-all`, `5.live-integration`, `5.structural-gate`
  (title_ii_test.exs). Classified: synthetic partition/infrastructure ids,
  not corpus sub-line tests — they are lane W522's partition scaffolding and
  are not corpus line_ids. (The remaining grep hits — `Art.1-2`, `Title`,
  `VI-XIII`, `admission` — are prose in test names/comments, not refs.)

## Per-title coverage (corpus counts vs. iterating suite)

| Title | lines | suite | per-line coverage |
|---|---|---|---|
| I (111) | covered once | title_i_test.exs (`num == "I"`) | 1 test/line |
| II (26) | UNCOVERED | title_ii_test.exs (partitions only, no corpus loop) | 0/26 individually |
| III (391) | DUPLICATED | title_iii_test.exs + title_iv_v_test.exs | 2 tests/line |
| IV (8), V (57) | covered once | title_iv_v_test.exs | 1 test/line |
| VI–XIII (475) | covered once | title_vi_xiii_test.exs (`in_scope` VI–XIII) | 1 test/line |
| **Total** | **1068** | | 1042 covered-once + 391 duplicated + 26 uncovered |

## The title file that must add them

`test/eu_ai_act/title_ii_test.exs` — add a corpus.json iteration loop over
`title["num"] == "II"` mirroring the title_iii/title_iv_v shape (per-line
test per Title II line_id; 5.1.a–h evidenced via the existing `@partitions`,
sub-line ids `5.1.c.i`, `5.1.c.ii`, `5.1.h.i–iii`, `5.1.s2`, `5.2.*`,
`5.3.s2`, `5.5`–`5.8` classified evidenced/not_applicable/open_gap), and
relabel its three synthetic ids (`5.catch-all`, `5.live-integration`,
`5.structural-gate`) or register them as declared non-corpus tests.

## Required repairs (owners outside W527)

1. `test/eu_ai_act/title_i_test.exs:165` — `%{x0 => 1.0 * i}` →
   `%{"x0" => 1.0 * i}` (single-token compile fix; suite is currently
   BLOCKED at compile for all lanes).
2. `test/eu_ai_act/title_iv_v_test.exs:44` — drop `"III"` from the title
   filter (`num in ["III","IV","V"]` → `["IV","V"]`) to clear the 391-line
   duplication with title_iii_test.exs.
3. `test/eu_ai_act/title_ii_test.exs` — add the Title II corpus loop (26
   lines) per the section above.

## In-flight caveat

Coverage is as of NOW on this tree. Lanes W523 (title_iii), W524 (title_iv_v),
W525/W5525b (title_i) were reported in-flight; the title_i compile break and
the title_iv_v III-overlap look like mid-write states of those lanes, not
final positions. Re-run this audit after the wave settles for the final
verdict.
