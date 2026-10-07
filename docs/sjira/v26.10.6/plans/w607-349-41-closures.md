# W607 — Title I 3.49-family + 4.1 closures

Lane W607, 2026-10-06, xaas @ feat/playwright-surface (one canonical checkout,
lane build root `_build-laneW607`). Contract: `test/eu_ai_act/title_i_test.exs`
(3.49-family + 4.1 flips only) and this receipt.

## Task

Flip the five Art. 3(49) "serious incident" OPEN_GAP lines (3.49, 3.49.a-d) to
EVIDENCED against W538's landed Art 73 builder
(`lib/xaas/semantics/incident_report.ex`), and judge Art. 4 (AI literacy, line
4.1) honestly — flip only if a real literacy surface exists.

## Flip table

| line_id | before | after | evidence asserted |
|---|---|---|---|
| 3.49 | OPEN_GAP | **EVIDENCED** (W538) | `lib/xaas/semantics/incident_report.ex` + `test/xaas/semantics/incident_report_test.exs` on disk; test file pinned at 6 test definitions; real `IncidentReport.build/2` derives `[:INFRINGES_UNION_LAW, :MALFUNCTION]` from a refused receipt; `transmit/1` returns `PREPARED_NOT_TRANSMITTED` (typed OPEN per corpus 73.4-73.5); receipt `plans/w538-art73-incident-report.md` |
| 3.49.a | OPEN_GAP | **EVIDENCED** (W538) | same seam; `build/2` over an `:error`-status receipt derives `:MALFUNCTION` |
| 3.49.b | OPEN_GAP | **EVIDENCED** (W538) | same seam; `:refused`-status receipt → `:MALFUNCTION` |
| 3.49.c | OPEN_GAP | **EVIDENCED** (W538) | `REFUSED_EUAIA_*` atom → `:INFRINGES_UNION_LAW`; `_RIGHTS_` atom additionally → `:HARM_TO_RIGHTS` (matches the moduledoc's Art 73(1) trigger mapping) |
| 3.49.d | OPEN_GAP | **EVIDENCED** (W538) | same seam; `:error`-status receipt → `:MALFUNCTION` |
| 4.1 | OPEN_GAP | **OPEN_GAP (kept)** | no real AI-literacy surface exists: `docs/cro/CRO-LOOP.md` has no operator-enablement/training section (grep: only operator-directive headers); coverage map 14(4)(e) row is automation-bias awareness, not Art. 4 literacy. Partial cited: W537 `Xaas.Semantics.OversightGovernance.fria/0` per-right evidence-citation structure. Typed reason: `GAP(NO_AI_LITERACY_SURFACE)`. Not manufactured. |

## Classification-coverage honesty note

`IncidentReport`'s classification atoms cover the corpus Art 73(1) trigger
classes at family level: Union-law infringement (`REFUSED_EUAIA_*` prefix),
rights harm (`*_RIGHTS_*`/`*_HARM_*` / `rights_harm: true`), and
malfunction/unauthorized actuation (`:refused`/`:error` status). The
sub-lines 3.49.a (death/health), 3.49.b (critical infrastructure), 3.49.d
(property/environment) share the same seam and derive `:MALFUNCTION` today;
no sub-line-distinct atoms exist. Flipped on "the reporting seam exists and
classifies", not on per-sub-line vocabulary.

## Runs

- `MIX_BUILD_ROOT=_build-laneW607 mix test test/xaas/semantics/incident_report_test.exs`
  → **6 passed** (W538 builder court, real run, exit 0).
- Green gate `MIX_BUILD_ROOT=_build-laneW607 mix test test/eu_ai_act/title_i_test.exs
  --include eu_ai_act --exclude eu_ai_act_open_gap`
  → **111 passed, 1 excluded** (4.1 gap), 0.3 s, exit 0.
- Honest census (same file, gap NOT excluded): **BLOCKED by a concurrent lane** —
  untracked `lib/xaas/semantics/airo_risk_mapping.ex:201` (not W607's file,
  owned by the AIRO lane) has had a persistent SyntaxError across 7 retry
  attempts over ~25 min; the app cannot compile while it is broken, so the
  include-everything census could not run. The only difference between the
  census and the passing green gate is the single 4.1 line, which `flunk`s by
  design (`OPEN_GAP: ... GAP(NO_AI_LITERACY_SURFACE)`).

## Result

Flipped EVIDENCED: 3.49, 3.49.a, 3.49.b, 3.49.c, 3.49.d (5). Still OPEN_GAP:
4.1 (1, kept honestly — no literacy surface manufactured).
