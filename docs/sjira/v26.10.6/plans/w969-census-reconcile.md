# W969 — Terminal-Census Count Reconciliation

- Date: 2026-10-07
- Lane: W969, xaas v26.10.6 campaign, branch `feat/playwright-surface`, canonical checkout `/Users/sac/xaas`
- Scope: doc-only reconciliation; no test runs, no build root, no commit (coordinator owns commits).
- All counts below copied verbatim from on-disk receipts / real file reads this lane.

## 1. Witness counts

| witness | receipt | subject/tree | gated pass | open-gap-tagged | census total |
|---|---|---|---|---|---|
| W821 (terminal-census-2) | `w821-terminal-census-2.md` | `a0723bf6` (live tree) | 1347 (exit 0, 1 excluded) | 1 | 1348 |
| W935b (census-count-capture) | `w935b-census-count-capture.md` | HEAD-area live tree (post-06:44 commits) | 1352 (exit 0, 1 excluded) | 34 (33 pass + 1 intentional OPEN_GAP flunk) | 1353 (per run 2: 34 + 1319 excluded) |
| W926 (terminal-census-3) | **NOT ON DISK** | — | — | — | — |

W926's receipt (`w926-terminal-census-3.md`) is not on disk. Confirmed independently by
`w961-push-fold-verify.md` ("w926 census-cert receipt also not on disk") and by this lane's
`ls`/grep. W935b also reported it absent after 3 checks. Cross-compare against W926: **UNKNOWN**.

## 2. Delta explanation (1347/1348 → 1352/1353)

Tree moved between the two witnesses via two commits touching `test/eu_ai_act` after W821's
subject `a0723bf6`:

| commit | time | files | insertions | new `test` blocks (grep on committed diff) |
|---|---|---|---|---|
| `79efb7ab` article deepening suites (W665/W667/W669/W696/W710/W692/W706/W691/W843) | 06:44 | 12 files | +2452 | 32 |
| `9a8ba282` title test updates (W732/W679/W861/…) | 06:46 | 4 files | +10 | 0 |

- W821 ran 04:55–05:20 at `a0723bf6` on the live shared checkout, so its counts may include
  then-uncommitted deepening files; the committed diff vs `a0723bf6` shows 32 new `test`
  blocks / 0 removed, while the observed gated delta is only +5. The residual (+5 observed vs
  +32 committed-block count) is not fully attributable from receipts alone — W821's live-tree
  composition at run time is unrecorded. **Flagged, not papered over.**
- The named court lanes (staleness_task_court, vendor_pin_court, health_court,
  witness_live_court, enrollment_journey, route_collision, rpc_surface) did NOT change the
  eu_ai_act census: their test files live outside `test/eu_ai_act` (verified by grep across
  `test/` and `lib/` — zero matches for the court names there). Their own receipts' counts:
  vendor_pin_court 3 (`w894`), health_court 11 (`w836`), witness_live_court 4 (`w888`),
  rpc_surface_deepening 11 (`w813`), residue-backfill probe 7 (`w898`), route_collision 4
  (`w944b`). These feed the whole-suite census (W929's 4042), not this one.
- W935b flagged and this lane confirms the tag-count anomaly: gated run excluded 1, open-gap
  run collected 34. Tag sites on disk: `@moduletag :eu_ai_act_open_gap` in
  `title_i_test.exs:577`, `title_iii_test.exs:1133`, `title_vi_xiii_test.exs:803`;
  per-test `@tag :eu_ai_act_open_gap` at `title_iv_v_test.exs:451`. Only 1 literal per-test
  tag exists; module-level tags apply to all tests in their modules, and the include/exclude
  counts reported by the two runs (1 vs 34) do not reconcile from static file reading alone.

## 3. Authoritative number for the campaign receipt

**1352 gated-pass (exit 0) + 34 open-gap-tagged = 1386 eu_ai_act tests**, from W935b's runs —
the latest deterministic gated count on the most recent tree. W821's 1347/1348 is superseded
(stale subject `a0723bf6`).

Tag-convention caveat from w962: **UNKNOWN** — no w962 receipt is on disk (grep across
`docs/sjira/v26.10.6/` and `docs/cro/` returns zero hits). The W935b-flagged 1-vs-34
include/exclude anomaly stands unresolved; any campaign-receipt citation of "open gaps"
should cite the open-gap census run (34 collected), not the gated run's excluded count.

## 4. Standing

- W969 receipt: **ALIVE** (doc-only; every number above copied from a real file read this lane).
- Census certification (w955 push-gate spec condition 1c): **half-held** — W821 ALIVE at its
  subject, W926 UNKNOWN (receipt never landed), W935b ALIVE as second witness with a
  PENDING cross-compare. This receipt performs that cross-compare where possible: counts
  moved with the tree (+5 gated), delta explained by the two 06:44/06:46 commits, residual
  +5-vs-32 attribution gap flagged.
- Follow-up: land W926's receipt or formally retire it; land w962 or drop the citation.
