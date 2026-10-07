# W711 — Evidence–Claims Index refresh (receipt)

- **Subject**: /Users/sac/xaas @ `feat/playwright-surface`, HEAD `a0723bf6`, uncommitted (no commit per lane contract)
- **Artifact written**: `docs/cro/artifacts/evidence-claims-index.md` (extended in place; W405 rows 1–12 and format preserved verbatim)
- **Method**: every cited receipt read in full (or in full-relevant-part) before its row was written; grade records what the receipt actually observes (real test/probe/parse execution = witnessed; grep/stat derivation = grep; file presence = existence), never the wave's intent.

## Rows before / after

- Before: 12 (W405 audit, 2026-10-06)
- After: 32 (rows 13–32 added 2026-10-07: OS-21 closure w640, §4 refresh w700, AIRo 14/14 w668, ten per-repo AIRo pins w675/677/678/680/681/682/683/685/686/687/690/695, 71-variant ledger refresh w705, margin hardening w676, malfunction fix w679, plug-order court w703, diataxis reconciliation w689)

## Grades

witnessed 17 · grep/existence 3 (#14 w700, #28 ledger half, #32 w689). #28's
kill evidence is witnessed in its source receipts (w676, w703, w640, w653b,
w659d).

## DRIFT findings (3, none fatal)

1. **#18 w678**: ledger claims "8/8 cited paths" for autofde-lab; the graph
   holds 7 distinct `file:` citations (all exist). Count error, substance holds.
2. **#19 w680 / #21 w682**: `airo-wiring-ledger.md` has no row for ex4pm or
   ash_pplan despite both carrying committed AIRo surfaces (w645b, w635).
   The w668 "14/14" verdict is over the ledger's own 14 repos only — a
   coverage gap, not a wiring defect. Coordinator: add both rows.
3. **#13/#14 uncommitted-landing caveat**: OS-19/OS-21 landings (and the OS-16
   marking leg) live on the uncommitted lane build at a0723bf6; coordinator
   integration pending.

## Standing

PARTIAL_ALIVE — every claim added is backed by a receipt that was actually
read, and the index now states its own grades; ALIVE for the index itself
requires coordinator integration (the index edit and this receipt are
uncommitted on the canonical checkout).
