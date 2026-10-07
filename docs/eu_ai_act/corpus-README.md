# EU AI Act Chicago-Test Corpus

Machine-readable corpus of every normative line of Regulation (EU) 2024/1689
(Artificial Intelligence Act), built for the Chicago-test wave: every line
becomes exactly one test.

## Files

- `corpus.json` — the corpus. `python3 -m json.tool corpus.json` validates.
- `corpus-README.md` — this file.

## Structure

```
{"regulation", "fetched_from", "fetched_at", "structure_note",
 "titles": [                          # 13 title-units (I–XIII)
   {"num": "I", "name": "General Provisions",
    "articles": [
      {"id": "1", "title": "Subject Matter",
       "lines": [
         {"line_id": "1.1", "text": "...", "kind": "...", "addressee": "..."}
       ]}]}]}
```

- `line_id` is `{article}.{paragraph}` with lettered sub-paragraphs dotted
  (`5.1.a`, `10.2.f`, roman depths `5.1.c.i`). A lead-in paragraph with no
  number is bare (`94`, `113`). When the source repeats one id across the
  successive unlabelled subparagraphs of a numbered paragraph, the 2nd+ get
  `.s2`, `.s3` (`41.1.s2`, `113.s3`).
- `kind`: `prohibition | obligation | definition | procedure`
  (heuristic: Art 3 / "`X' means" → definition; Art 5 / "prohibited" →
  prohibition; "shall" → obligation; else procedure).
- `addressee`: `provider | deployer | both | authority`
  (heuristic from explicit mentions in the line text; unmentioned → `both`).
  Both fields are routing hints for test authors, not legal conclusions.

## Counts

- Articles: 113 (all of them, 1–113)
- Lines: 1068

Per title (lines):

| Title | Name | Lines |
|---|---|---|
| I | General Provisions (1–4) | 111 |
| II | Prohibited AI Practices (5) | 26 |
| III | High-Risk AI Systems (6–49) | 391 |
| IV | Transparency Obligations (50) | 8 |
| V | General-Purpose AI Models (51–56) | 57 |
| VI | Measures in Support of Innovation (57–63) | 101 |
| VII | Governance (64–70) | 78 |
| VIII | EU Database for High-Risk AI Systems (71) | 6 |
| IX | Post-Market Monitoring ... Market Surveillance (72–94) | 147 |
| X | Codes of Conduct and Guidelines (95–96) | 19 |
| XI | Delegation of Power and Committee Procedure (97–98) | 8 |
| XII | Penalties (99–101) | 53 |
| XIII | Final Provisions (102–113) | 63 |

Per kind: obligation 518, procedure 439, definition 80, prohibition 31.
Per addressee: both 543, authority 305, provider 174, deployer 46.
(Counts are post-punctuation-normalization; kind/addressee shifted by a few
from the first build pass — regenerate this table when regenerating the JSON.)

## Provenance

- Canonical source: EUR-Lex CELEX 32024R1689
  (https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32024R1689).
  EUR-Lex serves a JS shell to plain HTTP clients; full text was taken from
  the AI Act Explorer mirror at artificialintelligenceact.eu
  (`/article/N/`, N = 1..113), fetched 2026-10-06.
- The mirror renders a consolidated act (later amendments folded in with
  `om-old`/`om-new` markers). To reconstruct the original Regulation (EU)
  2024/1689 as published: replaced paragraphs use the pre-amendment (`om-old`)
  text; paragraphs inserted by later amendments are excluded. ~120 amendment
  markers across arts 1, 2, 3, 4, 5, 6, 10, 11, 17, 25, 27–30, 40, 42, 43,
  50, 56–60, 63, 64, 69, 70, 72, 75–77, 95–97, 99, 111, 113 were resolved
  this way.
- Tooltips (embedded term definitions) are stripped from line text; wording
  otherwise verbatim from the source.

## Test-mapping contract

Each `line_id` maps to exactly one Chicago test. Test name convention:
`test/eu_ai_act/<title>/<article>_test.exs`, one `test "line_id ..."` block
per line. Each test asserts exactly one of:

- `EVIDENCED(path)` — the repo contains real evidence (a test, a policy
  module, a generated artifact, a receipt) that satisfies the line; the
  assertion must execute real code and check real state, not introspect
  source text.
- `NOT_APPLICABLE(reason)` — the line does not bind this system (e.g.
  penalties for Member States, notified-body procedure); the reason must
  name the binding scope and why xaas is outside it.
- `OPEN_GAP` — the line binds and is not yet evidenced; fail-closed, these
  are the wave's work queue.

Fail-closed: any line with no test, or a test asserting none of the three
verdicts, fails the corpus coverage check. Definitions (`kind:
"definition"`) become typed-vocabulary assertions (the term used in
downstream tests resolves to this definition), not behavioral tests.

## Current status (W646 refresh, 2026-10-06)

Appended without rewriting the contract above; cited receipts live under
`docs/sjira/v26.10.6/plans/`.

- **Aggregation-4 (W622)** — `w622-euaia-aggregation-4.md`: full corpus suite
  1100/1110 passed, exit 2 on the unexcluded run, the 10 failures being
  exactly the `eu_ai_act_open_gap`-tagged tests; **typed open-gap census 10**
  (was 19 at W605) at that tree, enumerated per-title in the receipt (Art 4.1,
  8.1, 27.1.b/e/f, 74.12, 74.13.a/b, 86.2, 86.3).
- **Aggregation-8 (W645c)** — in flight at refresh time; no receipt path yet,
  so none is cited (fail-closed: this README cites only `test -f`-verified
  paths).
- **Deepening** — `w616-deepening.md` (Titles I–II), `w623-title-iii-deepening.md`
  (Title III), `w626c-deepening-iv-xiii.md` (Titles IV–XIII): evidenced-line
  tests upgraded from path-existence to real-behavior assertions, 90+ lines
  across the three lanes.
- **Flips** — `w607-349-41-closures.md` (Art 3(49) family + 4.1) and
  `w625c-art73-flips.md` (Art 73 family, 9 provider/both lines): OPEN_GAP →
  EVIDENCED against the W538 incident builder
  (`lib/xaas/semantics/incident_report.ex`) and W625 authority-channel registry.
- **Vendored-TTL pin** — `w621b-airo-pin.md`: AIRo vendored vocabulary pinned
  by test (`test/xaas/semantics/airo_vendored_pin_test.exs`).
- **Falsifier-class example** — `w636-rpc-repoint.md`: the rpc-check repoint
  (`lib/mix/tasks/xaas.release_audit.ex`, W632 STALE-AUDIT-REFERENCE) — a
  stale audit reference that survived source inspection and only failed a real
  run; the canonical example of why verdicts require executed commands, not
  path existence.

Corpus counts unchanged since first build: 113 articles, 1068 lines
(re-verified 2026-10-06 by JSON parse).

## See Also

- `docs/eu_ai_act/corpus.json` — the corpus itself
