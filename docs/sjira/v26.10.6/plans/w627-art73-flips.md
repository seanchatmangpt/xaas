# W627 — Art 73-family flips (Titles VI-XIII), lane receipt

Date: 2026-10-06 · Repo: /Users/sac/xaas @ feat/playwright-surface (canonical checkout) ·
Build root: `_build-laneW627` (lease — coordinator deletes at integration) ·
Contract files: `test/eu_ai_act/title_vi_xiii_test.exs` (Art 73 family only),
this receipt.

## Coordination outcome (W625c / W627)

Read `test/eu_ai_act/title_vi_xiii_test.exs` fresh immediately before work, per the
coordination directive. **W625c's flips were already fully present**: evidence-map
entries for 73.1 / 73.2 / 73.2.s2 / 73.3 / 73.4 / 73.5 / 73.6 / 73.6.s2 (lane tag
W538/W625/W625c) + typed NOT_APPLICABLE clause for 73.9, plus the `Deepenings`
art73 blocks (`refused_receipt/0`, `art73_duty/0`, `art73_full/0`,
`art73_cooperation/0`, `deepening/1` clauses 73.1–73.6.s2). **Zero edits to the
test file were required** — verify-only lane. Nothing to fill; nothing missed.

## Evidence-surface verification (all paths confirmed on disk)

- lib/xaas/semantics/incident_report.ex — `build/2` derives classification
  (`:INFRINGES_UNION_LAW` from `REFUSED_EUAIA_*` atoms; `:MALFUNCTION` from
  `status: :refused`; `:HARM_TO_RIGHTS` from rights/harm atoms/flag);
  `transmit/1` returns `{:ok, %{status: :PREPARED_NOT_TRANSMITTED, reason: ...}}`
  ("typed OPEN per corpus 73.4-73.5") — honest, never silent "sent".
- lib/xaas/semantics/authority_channel.ex — typed registry: 3 authority channels
  `:art73_market_surveillance`, `:corpus_3_49_transparency_family`,
  `:art27_1f_fria_notification` (`endpoint: :OPEN`); 2 EVIDENCED channels
  (`:internal_escalation_receipt_corpus` RECORDED over cited receipt-corpus
  paths, `:board_audit_fiduciary` over the witness chain, both path-verified at
  call time with typed :OPEN degradation on drift); unknown id →
  `{:error, :REFUSED_UNKNOWN_CHANNEL}`; zero app-env (fail-closed).
- Cited receipts exist: w538-art73-incident-report.md, w625-authority-channel.md,
  w473b-quiescent-suite.md; quiescent_stop.ex present.

Per-line API cross-check of every Deepenings 73.x assertion against the actual
module sources: fields (`classification` sorted list, `originating_receipt_digests`,
`incident_id` INC-HEX, `temporal.last_observed`, `channel_id`, `endpoint`) and
refusals all match — the deepening calls are real calls, not prose.

## Per-line table

| line | verdict | basis | deepening |
|---|---|---|---|
| 73.1 | EVIDENCED | W538/W625 — build/2 classification + AuthorityChannel typed registry, honest PREPARED_NOT_TRANSMITTED caveat | art73_full (real build + transmit over :art73_market_surveillance + :internal_escalation_receipt_corpus RECORDED + REFUSED_UNKNOWN_CHANNEL refusal) |
| 73.2 | EVIDENCED | W538 — report from witnessed causal evidence (refused receipt), temporal window | art73_duty (real build/2 + transmit/1) |
| 73.2.s2 | EVIDENCED | W538 — severity = classification breadth, deterministically sorted | art73_duty |
| 73.3 | EVIDENCED | W538 — REFUSED_EUAIA_* → :INFRINGES_UNION_LAW | art73_duty |
| 73.4 | EVIDENCED | W538/W625 — gravest-class envelope built; typed OPEN registry caveat | art73_full |
| 73.5 | EVIDENCED | W538/W625 — immediate minimal receipt set → valid envelope; PREPARED_NOT_TRANSMITTED | art73_full |
| 73.6 | EVIDENCED | W538 — deterministic multi-trigger classification, stable incident_id | art73_duty |
| 73.6.s2 | EVIDENCED | W625/W379 — internal RECORDED + typed authority seam + quiescent-stop surface | art73_cooperation |
| 73.9 | NOT_APPLICABLE (typed) | Annex III dedup scoping, authority-side; no obligation beyond the evidenced 73.1 seam | verdict-mapping clause only |

## Verification ladder (real runs, MIX_ENV=test, asdf pinned toolchain)

1. Direction A — honest full run, no exclude
   (`mix test test/eu_ai_act/title_vi_xiii_test.exs --include eu_ai_act`):
   **470/476 passed.** Failures = exactly the 5 by-design OPEN_GAP flunks
   (74.12, 74.13.a, 74.13.b, 86.2, 86.3) + 1 pre-existing non-73 flake:
   `99.4 zero_liability` — `Xaas.Semantics.EuAiActAdmission.describe/1`
   FunctionClauseError on a seeded junk candidate. **Zero Art 73 failures.**
2. Direction B — gate run
   (`--include eu_ai_act --exclude eu_ai_act_open_gap`):
   **471 passed, 5 excluded, exit 0** (green; 99.4 passed on this run — flaky,
   pre-existing W619 deepening, outside this lane's Art-73 contract).

## Standing

- Art 73 family (9/9 lines): dispositioned — 8 EVIDENCED, 1 typed NOT_APPLICABLE.
- Open (owned elsewhere): 74.12/74.13.a/74.13.b, 86.2/86.3 remain honest
  OPEN_GAPs; 99.4 deepening flake (W619) noted for its owner lane.
- Transport to a real market-surveillance endpoint remains typed OPEN by design
  (operator-supplied endpoint data via `AuthorityChannel.with_endpoint/3`; the
  code is never edited and no socket is opened by the semantics surface).

## Transport failures encountered (disclosed)

- First cold-lane compile hit a transient syntax error in
  `lib/mix/tasks/xaas.release_audit.ex` (concurrent lane mid-write; file parses
  clean on re-read — outside this lane's contract, untouched, fix-forward
  observed in the concurrent lane's tree).
- One run hit the 99.4 describe/1 flake described above (non-deterministic,
  passes on rerun).
