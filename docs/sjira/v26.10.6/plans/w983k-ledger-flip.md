# W983k — AIRo ledger xaas-row flip + W983a comment freshen — Receipt

- **Lane**: W983k, xaas v26.10.6 campaign
- **Date**: 2026-10-07
- **Subject**: /Users/sac/xaas, branch `feat/playwright-surface`, uncommitted
  work tree (coordinator owns commits)
- **Write scope honored**: `docs/cro/artifacts/airo-wiring-ledger.md` (one
  appended row), `test/xaas/conference/enrollment_journey_court_test.exs`
  (comments only), this receipt. No commits.

## Disposition 1 — AIRo ledger row landed, standing ALIVE

Landed the W982m handoff: one **6-column consolidated-format row** appended
to the Consolidated table in `docs/cro/artifacts/airo-wiring-ledger.md`
(after the w638 ferroplan row), exactly per the parser-safe shape the
W982m receipt recommended:

> w982m | xaas | `priv/airo_risk_description.ttl` (10,323 B, own-sha
> c85de1b8…, header pins canonical vocab 6274d2d8…) — **ALIVE** | RDF.ex
> parse: 95 triples, 4 RiskSources / 5 RiskControls / 1 Risk; 26 distinct
> airo: IRIs, all canonical-vocab members (`missing_from_vocab: []`); 6/6
> cited paths on disk | 6 passed (pin court ×2) | plans/w982m-airo-xaas-ttl.md

No 7th column. Pre-landed verification on disk by this lane: the TTL exists
(10,323 B) and `shasum -a 256` re-computed
`c85de1b8f96ad4b911bc89c445d8de58c0cff8bbb89d957744ba52ef515fbf8e` —
byte-identical to the W982m receipt's own-sha pin.

### Verification executed (real output)

1. `elixir docs/airo/pin_drift_check.exs` → JSON report: **20 CURRENT /
   1 ANCESTOR (beam4pm, expected post-W937) / 0 DRIFT / 0 MISSING**, 21
   rows. The new row is **not** picked up by the drift parser (it carries
   no 40-hex SHA column; the sha256 in the proof cell is 64-hex and fails
   the parser's `^`([0-9a-f]{40})`$` anchor) — parse-neutral, as designed.
2. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983k
   mix test test/xaas/airo/airo_pin_court_test.exs` (fresh lane build root)
   → **Result: 6 passed** (`[pin-court] skipped (checkout absent): 0`).
   The court's 7-column extension-row parser ignores the 6-column row, so
   `length(extension_rows()) == 9` held unchanged — **the anticipated
   census-assertion update was NOT needed**; nothing was edited in the
   court. Run exited 0 (slow only because the fresh `MIX_BUILD_ROOT`
   forced a full compile under heavy concurrent lane load).
3. `_build-laneW983k` **deleted** by this lane after the run (verified
   absent on disk), per the lane-lease cleanup law.

Standing flip: the W982m residual ("ledger row cell not edited") is
closed; the xaas AIRo row reads **ALIVE** citing w982m (TTL sha
c85de1b8…, 95 triples, vocab-membership clean, pin court 6/6 ×2, and now
this lane's independent re-verification of the sha + both courts on the
post-row ledger).

## Disposition 2 — enrollment journey court comments freshened (W983a handoff)

`test/xaas/conference/enrollment_journey_court_test.exs`: two stale
comment blocks updated to describe the **landed** W983a design. Comments
only — zero test logic, zero assertions touched.

- Step-6 comment (~line 402): was "unique_attendee_session is now
  status-scoped (where: expr(status in [:registered, :attended])) with
  EnforceActiveRegistrationIdentity"; now states the identity is
  **intentionally ABSENT** (ash 3.34.4 measured: no identity shape
  satisfies both the RequirePreCheckWith verifier and the scoped
  semantics) and active-duplicate enforcement lives entirely in
  `EnforceActiveRegistrationIdentity` on :create.
- W981s court banner (~line 457): same correction + mutation rationale
  rewritten to match the real mutation surface (drop the
  EnforceActiveRegistrationIdentity change from :create), replacing the
  stale "drop the `where: expr(...)` scope from the identity" rationale.

Wording cross-checked against the landed in-source comments in
`lib/xaas/conference/registration.ex` (lines 48–56) and the W983a receipt
(`plans/w983a-w981s-restore.md`).

### Verification

`Code.string_to_quoted!/1` on the full edited file → `SYNTAX_OK`. No mix
run for this file: comment-only diff cannot change behavior, and the file
was under concurrent lane test at edit time.

## Commands / exits

| command | exit |
|---|---|
| `shasum -a 256 priv/airo_risk_description.ttl` | 0 (sha matches w982m pin) |
| `elixir docs/airo/pin_drift_check.exs` | 0 (0 drift, new row parse-neutral) |
| `mix test test/xaas/airo/airo_pin_court_test.exs` (lane build root) | 0 (6 passed) |
| `Code.string_to_quoted!` on edited conference test | 0 (SYNTAX_OK) |
| `rm -rf _build-laneW983k` | 0 (dir absent) |

## Standing

- Ledger xaas AIRo row: **ALIVE** (per w982m evidence + this lane's
  independent sha re-computation and both courts green post-edit).
- Comment freshen: **ALIVE** (documentation-accuracy fix; syntax-verified;
  no behavioral surface).

## Falsifiers

- Corrupt `priv/airo_risk_description.ttl` or delete a cited path → pin
  court / W982m falsifiers fire.
- Change the new ledger row to 7 columns with a 40-hex HEAD → the pin
  court's extension-row parser picks it up, `== 9` fails, and the drift
  check gains a xaas row — the parse-neutrality claim is falsifiable.
- Revert either comment block to the stale wording → no test changes
  (comments-only claim is diff-verifiable via `git diff`).

REFUSED: none. UNSUPPORTED: none. BLOCKED: none.
