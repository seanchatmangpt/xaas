# W877 — Receipt-cited-claims rule lock (harness rule)

- **Lane**: W877, xaas v26.10.6 campaign. Repo (rule checkout): `/Users/sac/.claude`.
  No commit; no build root.
- **Files written**: `~/.claude/rules/no-overclaiming-conversational.md` (one appended
  block, 5 lines, existing text untouched) + this receipt.

## Result

Codified the campaign's recurring claim-staleness lesson as one terse rule appended to
`no-overclaiming-conversational.md` (chosen over `no-overclaiming-rust.md` — the pattern is
conversational/receipt claims, not Rust code; the Rust file already covers prior-session
hearsay for command claims):

> Receipt-cited counts are re-read from the receipt at use time. A count, standing, or status
> recalled from session memory of an earlier read is stale by default — re-verify on disk
> before staging/landing, or mark the claim explicitly as-of-date.

Grounded in W711 (cited pre-edit ledger) and W781 (marked receipts missing that had since
landed), citing `docs/sjira/v26.10.6/plans/w855-claims-refresh-2.md` and
`docs/sjira/v26.10.6/plans/w781-wave-ledger-refresh.md`.

## Verification

- Re-read of `~/.claude/rules/no-overclaiming-conversational.md` after Edit: appended block
  present (lines 14–19), lines 1–13 + See Also byte-identical (Edit tool matched exact
  existing text; no other edits).
- Receipt paths cited in the rule confirmed on disk this lane (`ls` + `head` on both files).

## Standing

ALIVE (docs/rule lane) — rule text on disk at `/Users/sac/.claude/rules/no-overclaiming-conversational.md`, verified post-edit.
