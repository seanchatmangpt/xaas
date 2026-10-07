# W389 — Evidence-link audit (W230-class refresh) — 2026-10-06

Subject: /Users/sac/xaas @ feat/playwright-surface (no commit; read-only audit).

## Method
- Extracted every `*.md` citation (109 unique tokens) and every bare
  `wNNN`/`rNN`/`xNN` receipt name (171 unique tokens) from:
  `_CLOSURE_PLAN.md`, `plans/_CLOSURE_RECEIPT.md`, `plans/_FRONTIER.md`,
  `plans/_WIRING_MATRIX.md`.
- `test -f` on each resolved path (plans/-relative for receipt names;
  repo-root or sibling-repo for `docs/…`, `~/…` paths).
- Sampled §1/§2 cited lib/test paths: rows 1,2,3,4,6,7,8,9,11,12,16,27,29
  (+ §2 negative-fixture files) — all exist at HEAD.

## Receipt
- Unique .md citations tested: 109 unique tokens (191 citation sites).
- Bare receipt names tested: 171.
- plans/*.md on disk: 239.
- §1/§2 sampled repo paths: 18 tested, 18 exist, 0 dead.
- OS-14..16 cite `w319` — no plans/w319-*.md (PENDING, in-flight, expected).
- w341: report-only, not cited with a file expectation — no file required (correct).

## Dead citations (4 sites, 3 distinct)
1. `_CLOSURE_RECEIPT.md:21,92,340` — "capstone evidence w236/w263b/w312 already
   on disk": `plans/w263b-*.md` and `plans/w312-*.md` do not exist (only
   `plans/w236-refusal-capstone.md` exists). False on-disk claim, 3 sites.
2. `_CLOSURE_RECEIPT.md:22` — `plans/w185-refusal-batch6-receipt.md` MISSING
   (self-documented at the citing line as missing at W352 check time;
   w185 batch6 receipt is a known residual/in-flight residual).
3. `plans/_FRONTIER.md:6` — `docs/sjira/v26.10.5/v26.10.5 _LANES.md` —
   verbatim: `docs/sjira/v26.10.5/_LANES.md` — no such path
   (v26.10.5 dir has no _LANES.md; prior-campaign stale pointer).

## Verified-clean highlights
- Sibling-repo paths in §4 Phase-4 rows resolve:
  `~/ash_pplan/docs/demonstration.md`, `~/ggen/docs/CHANGELOG.md`,
  `~/ggen-marketplace/docs/standing.md`... precisely
  `~/ggen-marketplace/docs/context/standing.md` — all exist.
- `eu-ai-act-nist-coverage-map.md` cited at `_CLOSURE_PLAN.md:263` (OS-14) and
  the w319 map path `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` both
  resolve — file exists at `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md`.
- Other bare-name misses (w9, w19, w21, w36–w38, w42–w48, w50, w53–w56, w59,
  w79, w90–w93, w95, w98–w102, w104–w107, w109, w112–w119, w121–w125, w127,
  w130, w133, w184b, w185, w186, w193, w195, w202, w208, w229) are already
  self-documented in the docs themselves as receipt-absent (historical lanes
  whose receipts were never filed or live as appendix prose in `_INDEX.md`) —
  known gaps, not new dead citations.

## Verdict per doc
- `_CLOSURE_PLAN.md` — CLEAN (sibling-repo §4 paths + coverage map resolve;
  OS-14..16 cite in-flight w319 → PENDING, expected).
- `plans/_CLOSURE_RECEIPT.md` — 3 dead-citation sites (w263b/w312 "already on
  disk" false) + self-documented w185-residual MISSING.
- `plans/_FRONTIER.md` — 1 dead citation (`docs/sjira/v26.10.5/_LANES.md`).
- `plans/_WIRING_MATRIX.md` — CLEAN (all cited receipt files exist).

## In-flight lanes cited but without receipt files (PENDING, expected)
w319 (OS-14..16 owner; eu-ai-act map path itself exists). All other cited
w317–w340 receipt files exist: w317, w321–w329, w331, w333–w340. w341+ not
cited with file expectations; w342–w388 receipts present except uncited
in-flight lanes w345, w352, w366, w369, w370, w372, w379–w382, w384–w388
(none of which are cited by the four docs, so no dead citations arise).
