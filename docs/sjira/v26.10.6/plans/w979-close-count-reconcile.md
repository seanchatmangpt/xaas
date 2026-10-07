# W979 — CYCLE-CLOSE register-count reconcile

Lane W979, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Doc-only lane: no code, no build root, no commit. Wrote only
`docs/cro/CYCLE-LOG.md` (one entry) + this receipt.

## Finding

The CYCLE-CLOSE entry (`docs/cro/CYCLE-LOG.md` item (d), W977-era) said
"25 OPEN / 23 REPAIRED". That snapshot predates W968b's 5 flips
(`plans/w968b-register-final-flips.md`: W665 kernel gap, W729 lifecycle,
W729 approve-idempotency, W731 registry-path, W893 NoServerActionForCancel —
each dual-cited and grep-confirmed on tree) and W971's subsequent flips.

## Verification (grep/awk on disk, 2026-10-07)

`grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|' w859-typed-gap-register.md | sort | uniq -c`:

- REPAIRED 31
- OPEN 17
- TYPED-OPEN 2
- (50 status rows total; matches the register's own totals line:
  "Total rows: 50 (17 OPEN + 31 REPAIRED + 2 TYPED-OPEN)")

So even W968b's post-flip 20/28 is stale — W971's 8-flip audit landed after
W968b's receipt and moved the register further (20−3 OPEN of W971's flips
fell on rows W968b had not touched).

## Change

CYCLE-CLOSE item (d): `25 OPEN / 23 REPAIRED` → `17 OPEN / 31 REPAIRED`,
with a citation appended to `plans/w968b-register-final-flips.md` and a note
that W971's later flips are included in the corrected totals. All other
content of the entry untouched.

## Standing

PARTIAL_ALIVE — corrected line is grep-verified against the register on disk
at this exact tree state; the register itself is the authority and may move
again if further lanes flip rows.
