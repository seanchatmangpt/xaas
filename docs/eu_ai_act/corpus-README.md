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

## Current status (W797 refresh, 2026-10-07)

Appended without rewriting earlier sections; cited receipts live under
`docs/sjira/v26.10.6/plans/`, each `test -f`-verified at write time.

### Test-file inventory (real `ls test/eu_ai_act/`, 2026-10-07)

The deepening wave added dedicated court files beyond the per-title suites.
File → landing receipt (each path verified present):

| File (`test/eu_ai_act/`) | Receipt |
|---|---|
| `art50_deepening_test.exs` (167 loc) | `w665-art50-deepening.md` |
| `art15_deepening_test.exs` (273 loc) | `w667-art15-deepening.md` |
| `art73_chain_deepening_test.exs` (308 loc) | `w669-art73-chain-deepening.md` |
| `art86_rights_deepening_test.exs` (183 loc) | `w710-art86-deepening.md` |
| `art99_enforcement_deepening_test.exs` (274 loc) | `w696-art99-deepening.md` |
| `title_ii_deepening_test.exs` (371 loc) | `w691-title-ii-deepening.md` |
| `counterfactual_deepening_test.exs` (311 loc) | `w692-counterfactual-deepening.md` |
| `eyerun_wire_deepening_test.exs` (170 loc) | `w706-eyerun-wire.md` |
| (pre-deepening) `counterfactual_test.exs` (1014 loc) | built in the W5xx corpus wave |

Semantics-side courts (outside `test/eu_ai_act/`, real path check):

- `test/xaas/semantics/declared_metrics_staleness_test.exs` (10 tests,
  `@moduletag :eu_ai_act` at line 16) — `w697-declared-metrics-staleness.md`.
  In scope for the `--include eu_ai_act` gate.
- `test/xaas/semantics/refusal_atom_census_test.exs` (6 tests) —
  `w713-refusal-census.md`. **Not** tagged `:eu_ai_act` (grep-verified: no
  `@moduletag` in the file), so it does not run under the `--include
  eu_ai_act` gate; run it by path. Cited here for inventory completeness.

### Run command convention (MANDATORY)

`:eu_ai_act` is on the default exclude list in `test/test_helper.exs`
(`exclude: [..., :eu_ai_act]`, real grep 2026-10-07). Every invocation MUST
pass `--include eu_ai_act`; a bare `mix test test/eu_ai_act` reports "All
tests have been excluded", exit 0 — a **vacuous pass**. This exact failure
was disclosed in `w666-ocel-egress-deepening.md` ("plain `mix test <file>`
reports 'All tests have been excluded', exit 0 — that is a vacuous pass and
was disclosed here, not counted"). Gate convention:

```bash
mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
# census run: drop the open-gap exclude (but see the tag-status note below)
```

### Gate counts (as of the W760 receipt)

- `w760-gate.md`: `mix test test/eu_ai_act --include eu_ai_act --exclude
  eu_ai_act_open_gap` → **1198/1200 passed, 2 failed** (exit 2, 57.2s);
  census run (without the exclude) gave the identical set and totals.
  W760 HEAD `a0723bf6`, staged working tree at gate time.
- W778 verification receipt: **not landed** at this refresh (no
  `w778-*.md` under `docs/sjira/v26.10.6/plans/`, real `ls`). The 1198/1200
  figure is **as of the W760 receipt** and must be re-stamped when W778's
  verification lands.
- W760's two deterministic failures: F1 title_i_test.exs:547 (3.49, W679
  orphaned court expectation vs. MALFUNCTION suppression) and F2
  title_iii_test.exs:766 via deepen_kind/1:1032 (15.5.s3, self-refuting
  staged test hunk, discarded triaged struct). Both court-side repairs,
  enumerated in `w760-gate.md`.

### Open-gap tag mechanism status

- **W760 runtime-inert finding**: the `@moduletag :eu_ai_act_open_gap`
  declarations exist in source (title_i_test.exs:575, title_iii_test.exs:1132,
  title_vi_xiii_test.exs:803, title_iv_v_test.exs:446 — grep-verified at gate
  time) but the tag **selects 0 tests at runtime**
  (`--only eu_ai_act_open_gap` → "0 tests selected, 1200 excluded",
  `w760-gate.md`). The gate convention is currently self-consistent (no open
  gap silently excluded) but the tag-based census mechanism is inert.
- W779 diagnosis receipt: **not landed** at this refresh (no `w779-*.md`,
  real `ls`). Status stays "runtime-inert, undiagnosed pending W779"; re-stamp
  this section when it lands.

Corpus counts unchanged: 113 articles, 1068 lines.

## Current status (W815 refresh, 2026-10-07)

Appended without rewriting earlier sections; cited receipts `test -f`-verified
at write time (`w760-gate.md`, `w779-opengap-tag.md` under
`docs/sjira/v26.10.6/plans/`).

### Typed open-gap census: exactly 1 — Art. 49(3)

- **49.3 — deployer EU-database registration duty** (Art. 49(3): before
  putting into service or using a high-risk AI system listed in Annex III,
  the deployer must register itself and the system in the EU database). The
  line binds xaas and is not evidenced; there is **no registration seam in
  this repo** — the honest refusal shape is the flunk row itself, not an
  invented closure. Its flunk row now **generates honestly** since W779's
  scope fix (`w779-opengap-tag.md`): the IV+V generator's title-num filter
  had silently dropped every Art. 49 line from generation, making the
  `@open_gaps["49.3"]` declaration dead; the filter is removed, all 10 Art. 49
  corpus lines bind (9 as NOT_APPLICABLE, 49.3 as the sole real OPEN_GAP row,
  tagged `:eu_ai_act_open_gap`).
- All other gap inventories are genuinely empty (Title I `@gap_details ==
  %{}` since W648b; Title III `Lines.open_gaps/0` → `[]`; Titles VI–XIII
  likewise). **One typed open gap (49.3) + zero others.** This corrects any
  earlier "zero open gaps" reading (W760's "0 open gaps is real" — see the
  tag-status note above, now superseded).

### Census-vs-gate delta mechanism (verified)

The census convention — green gate = `--include eu_ai_act --exclude
eu_ai_act_open_gap`, census = same without the exclude — is now witnessed,
not inert. Per `w779-opengap-tag.md` (real runs, pinned toolchain,
`MIX_BUILD_ROOT=_build-laneW779`):

| Run | Result |
|---|---|
| `--only eu_ai_act_open_gap` | 1 selected / 1347 excluded, flunks honestly (0/1) |
| green gate (`--exclude eu_ai_act_open_gap`) | 1346/1347 passed, 1 excluded |
| census (no exclude) | 1346/1348 passed |

Delta: census total (1348) − green-gate total (1347) = **1 = the real
open-gap count**. The two runs differ by exactly the tag-selected set — the
invariant the census convention requires. The pre-W779 state (0 selected /
1200 excluded) had the tag selecting nothing, so the delta carried no bits.

### Totals re-stamp

Green gate / census totals are now **1347/1348** (was 1200 at the W760
receipt). Movement is additive and disclosed in `w779-opengap-tag.md`:
+10 from W779's Art. 49 scope fix (this lane's attributable change) and
+137 from other lanes' consolidation waves landed in the shared tree during
W779 (present identically in its before/after runs). The one green-gate
failure remains pre-existing F2 (`EUAI-ACT 15.5.s3`, title_iii_test.exs,
owned by the W540/W623 lane) — unchanged, not repaired by W779 or W815.

Corpus counts unchanged: 113 articles, 1068 lines.

## See Also

- `docs/eu_ai_act/corpus.json` — the corpus itself
