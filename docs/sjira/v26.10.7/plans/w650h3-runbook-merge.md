# W650h3 — Receipt: runbook relationship audit (v26.10.7 vs v26.10.6)

- Lane: W650h3 (v26.10.7 fleet seal)
- Repo: /Users/sac/xaas (branch `feat/playwright-surface`); read-only, no commit, no git transitions.
- Date: 2026-10-07

## Verified state of both files (on disk, 2026-10-07)

### docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md

- **EXISTS.** 774 lines, 53,763 bytes, mtime 2026-10-07 10:29.
- Title: `# INTEGRATION RUNBOOK — v26.10.6 closure`. This is the campaign's actual
  consolidated integration runbook: commit sequences (W214 G1–G11 as amended),
  lease cleanup, W946d "FINAL CONSOLIDATED INTEGRATION SECTION", W984e operator
  section, lane tables, gate tables.
- **Contains no "Conventions" section and no W650x sweep-lane note.** `grep -i
  convention` matches only the gymact tag-convention line 133; zero mentions of
  W650 anywhere in the file.

### docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md

- **EXISTS.** 5 lines, 276 bytes, mtime 2026-10-07 16:07 (created by W650g5b).
- Content: `# v26.10.7 Fleet Seal — Integration Runbook` + a `## Conventions`
  section with one sweep-lanes note (campaign-versioned receipt dirs; enumerate
  all `docs/sjira/*/plans/` dirs; cites W650g3 wrong-dir miss / W650g4 correction).
- Has an H1 title; not titleless. Confirms its own scope ("v26.10.7 Fleet Seal").

## Relationship verdict

**The v26.10.7 file is a new-campaign runbook seed, not an accidental duplicate**
of the v26.10.6 runbook — but it is nearly empty and carries the only copy of the
sweep-lanes convention note. The task brief's premise that the v26.10.6 runbook
holds "W946d's consolidated section + W650e's sweep note" is **half-correct**:
W946d's consolidated section is present; **the W650e/W650g4 sweep-lanes note is
NOT in the v26.10.6 runbook** — its only on-disk copy is the v26.10.7 file.

## Recommendation (record only; execution belongs to owner/integration lane)

**Keep both files, do not delete or merge-and-delete.** Concretely:

1. **Keep** `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md` as the v26.10.6-closure
   runbook — it is the authoritative consolidated runbook for that campaign and is
   history-locked (W946d/W984e supersession markers rely on it staying whole).
2. **Keep** `docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` as the v26.10.7
   runbook seed. It already has a proper H1 title ("v26.10.7 Fleet Seal —
   Integration Runbook"), so it cannot be mistaken for a stub. If the owner wants
   stronger disambiguation, add one line under the H1: `Status: seed — conventions
   only; see v26.10.6 runbook for the consolidated closure runbook it inherited
   from.`
3. **Optional cross-link (either direction):** append the sweep-lanes convention
   note to the v26.10.6 runbook as a `## Conventions` section so future v26.10.6
   receipt-writers (the note's actual audience) see it where they work; the v26.10.7
   copy stays as the new campaign's seed. The note is applicable to both campaigns —
   it governs receipt-dir selection, not campaign content.

**Not recommended:** deleting the v26.10.7 file after merging the note into
v26.10.6 — the v26.10.7 campaign has no other runbook; deleting it would leave the
new campaign runbook-less and orphan W650g5b's receipt citation.

## Standing

ALIVE for the file-state observations (both files read directly from disk this
session, sizes/mtimes/head content quoted above). ALIVE for the recommendation as
a recorded proposal; execution of any merge/cross-link belongs to the owner or
integration lane, not W650h3. No mix commands run (read-only lane); verification
was direct file reads + grep over both files.
