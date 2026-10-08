# W650k4 — Fleet tag-truth verdict incorporated into closure receipt

Lane W650k4, v26.10.7 fleet seal. Repo: `/Users/sac/xaas`. Read-only +
two writes (`plans/w650k4-seal-verdict.md`,
`docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md`). No commits, no mix commands,
no tag mutations.

Task: record W650k3's tag-truth verdict (`plans/w650k3-tag-verdict.md`,
re-read in full at lane start) in the closure receipt's tag section (§5)
and open-items register (§8).

## Verdict recorded (all from W650k3, cited, not re-derived)

1. **8/8 tags truthful**: every `v26.10.7` tag across the 8 repos is
   annotated and peels to an ancestor of that repo's local HEAD
   (W650k3 §3 table).
2. **xaas audited tree ≠ tagged subject**: local HEAD `1b14ec1e` is 42
   commits ahead of the tag peel `56325fa5`; the 42 include real
   remediation subjects (`428ae270` W650k2 audit remediation,
   `5997a4a9` graphlaw courts, `bae6bdc1`, `ea886c6a`). Audit-green is
   at HEAD, not at tag. W628b convention applies — tag re-point NOT
   required; disclosure required instead.
3. **New transport finding (BLOCKED-class for coordinator)**:
   `56325fa5` is NOT reachable from `origin/main` (`5fc56da2`, which is
   *behind* the tag — `rev-list 56325fa5..origin/main` = 0). The tag is
   pushed to origin, but the seal commit is branch-local to
   `feat/playwright-surface` until the coordinator merges to main.
4. **Post-tag drift in sibling repos**: ash_pplan carries 2 post-tag
   commits incl. `847f487b` (W650j version-companion fix — arguably
   release content; v26.10.8 re-cut vs W628b acceptance is an operator
   call). ash_a2a drift is docs-only (`13dd1a57`, already recorded as
   W628b in the receipt).

## §5/§8 diff summary (the two writes)

- **§5 (Fleet tags)**: appended a "W650k4 tag-truth verdict (W650k3,
  2026-10-07)" block: 8/8 ancestry-truthful; xaas 42-commit post-tag
  drift incl. `428ae270`; seal wording requirement ("audit-green at HEAD,
  not at tag"); branch-local seal transport finding; ash_pplan `847f487b`
  operator item; ash_a2a docs-only. Standing: PARTIAL_ALIVE (truthful
  with disclosures, per W650k3) — superseding the unqualified "8/8 ALIVE"
  in the standing summary for the tag surface.
- **§8 (open items)**: added rows 11 (seal branch-local until
  feat/playwright-surface → main merge — coordinator BLOCKED-transport)
  and 12 (ash_pplan `847f487b` post-tag release-content decision —
  operator, v26.10.8 vs W628b), both citing `plans/w650k3-tag-verdict.md`.
- **Standing summary**: tag line amended to cite the W650k3
  PARTIAL_ALIVE verdict and the two new open items.

## Receipt-section diff summary

Two files written (lane receipt + closure receipt edit), zero code, zero
commits. All verdict content cited from `w650k3-tag-verdict.md` without
re-derivation; W650k3's HEAD-at-observation (`1b14ec1e`) is the same HEAD
at W650k4 observation time.

## Standing

ALIVE (documentation-incorporation lane). Falsifier: closure receipt §5/§8
does not carry the four verdict points above, or carries them with a
different receipt citation than `plans/w650k3-tag-verdict.md`.
