# W984ge — Probe Receipt: open-items register truthing, `_CLOSURE_RECEIPT.md` §8

- Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (docs-only lane, no
  commit; working tree only)
- File: `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md` (sibling-owned; rows updated
  in place, dated addendum added — no structural rewrite)
- Date: 2026-10-07

## Per-row verification (real git/disk evidence)

**Row 1/1b (W984dj census, W650b incorporation) — unchanged, still CLOSED.**
`plans/w650b-open-items.md` present in `docs/sjira/v26.10.7/plans/`; §1 of the
receipt already carries the W650b closure. No action.

**Row 2 (W638 Wasmex host commit) — CLOSED.**
Prior: "landed-uncommitted". Evidence: `git log --oneline -3 --
lib/xaas/semantics/graphlaw_wasm.ex` → `2f2748b3 feat(semantics,hddl): W650g
integration — graphlaw WASM host (W638/W644) + mermaid depth (W984cz2)`;
`git branch --contains 2f2748b3` → `feat/playwright-surface`;
`git diff --stat HEAD -- lib/xaas/semantics/graphlaw_wasm.ex` → empty (clean
vs HEAD). Receipt `plans/w638-wasmex-host.md` unchanged.

**Row 3 (W640 differential court) — CLOSED.**
Prior: "no landed receipt". Evidence: `plans/w640-differential-shacl.md`
present — standing ALIVE, 5/5 ×2 fresh roots, host/guest conform-boolean +
focus-set agreement across C1–C4, C0 typed-refused. Court artifact
`test/xaas/semantics/w640_differential_shacl_test.exs` committed:
`git log --oneline -1 -- <file>` → `a5f81439 test(security,semantics,actuation):
W650g2 restage — owner-complete straggler tests + security.ex`; `git status
--short` on the file clean.

**Row 4/5 (ash_surface, ggen-marketplace version-commit lanes) — unchanged,
still BLOCKED(version-commit-pending).** No counter-evidence on disk: no new
W650x receipt claims either commit landed; W650k3/W650k4 rows still current.

**Row 11 (seal branch-local) — re-verified STILL TRUE.**
`git fetch origin main` then
`git merge-base --is-ancestor 56325fa5 origin/main` → exit 1 (NOT reachable).
Coordinator merge to main still owed.

**Row 12 (ash_pplan 847f487b operator item) — re-verified STILL OPEN,
untouched.**
`git -C ~/ash_pplan log --oneline -1` → `847f487 fix(release): align version
companions with 26.10.7 bump (W650j)`; `git -C ~/ash_pplan describe --tags` →
`v26.10.7-2-g847f487` (2 commits ahead of the tag). Operator decision still
owed.

**Row 13 (idempotency-deepening 3F) — CLOSED by W650h23.**
`docs/sjira/v26.10.6/plans/w650h23-repair.md` present: real failure class =
unscoped global reads (`Ash.read!(ActuationIntent, authorize?: false) == []`)
colliding with committed foreign rows in shared `xaas_test` under READ
COMMITTED; zero lib/ changes. Commit receipt
`docs/sjira/v26.10.7/plans/w650h23-commit.md` (commit `8a5f7ea7`).
Added as new register row 13.

**Row 14 (W984ee court file loss → W984fo restoration) — STILL OPEN,
restoration NOT closed.**
- `test/xaas/compat/otp29_map_update_court_test.exs` present on disk, 92
  lines, W984ee/OS-20 guard semantics + real File.read! census court.
- BUT untracked: `git status --short <file>` → `??`; and
  `git log --oneline --all -- <file>` → empty (never committed on any ref).
- No `w984fo` receipt in `docs/sjira/v26.10.6/plans/` or
  `docs/sjira/v26.10.7/plans/` (glob checked, zero matches).
- Owed before any DRAFT clear: commit of the court file + a landed W984fo
  receipt.
Added as new register row 14.

## DRAFT flags (§5 and header)

- `DRAFT(W638-commit-pending)` — CLEARED, precondition met (commit
  `2f2748b3`).
- `DRAFT(W640-differential-pending)` — CLEARED, precondition met (receipt
  `plans/w640-differential-shacl.md` + committed artifact `a5f81439`).
- Header `DRAFT-pending-final-runs` — NOT cleared. Still owed: item 14
  (court file commit + W984fo receipt), coordinator item 11 (merge to main),
  operator item 12 (ash_pplan v26.10.8 decision).

## Diff receipt

```
$ git diff --stat docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md
 docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md | 47 ++++++++++++++++++++++-----------
 1 file changed, 32 insertions(+), 15 deletions(-)
```

Verified on disk post-edit: `grep -n "W984ge" _CLOSURE_RECEIPT.md` → 9
matches (rows 2, 3, 11, 12, 14, addendum, standing summary, seal verdict,
§5 flags). Docs-only; no commit; no build root.

## Standing

- Register truthed: 6 rows updated, 2 rows added, 2 flags cleared with
  met preconditions, header DRAFT retained (unmet preconditions itemized).
- Lane standing: ALIVE (docs-only, evidence per row above).
