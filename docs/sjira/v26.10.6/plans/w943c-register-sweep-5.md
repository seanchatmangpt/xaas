# W943c — Register Sweep 5 Receipt

Lane W943c, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD `fab56ae1`).
Register-write only: no lib/ or test/ code touched, no commit, no build root.

## Changes to `w859-typed-gap-register.md`

### 1. W838-G1 row refined (not auto-REPAIRED)

Prior row (sweep 4): TYPED-OPEN, "root cause UNKNOWN: Phoenix.PubSub/:pg + OTP 28.5
candidate". Refined per real file reads:

- `w909-pubsub-g1-rootcause.md` — root cause identified: **harness-shape limitation, NOT a
  Phoenix.PubSub/:pg/OTP-28 defect** (R1/R2 all-delivered; R3 exact-W838-shape repro shows
  duplicate delivery into the awaiting test process — itself a real subscriber — plus a
  topic-prefix-only `await_relay` requeue-scan that lets a stale duplicate satisfy a later
  await). Upstream semantics check clean; no upstream finding warranted.
- `w918b-awaiter-hardening.md` — repair landed: every await uniquely bound to the expected
  payload id (11 call sites); 9/9 ×3 real runs (seeds 812311/865813/184771); mutation
  evidence rerun.

New wording: REPAIRED with the harness-limitation documented and the honesty boundary kept
in the row — **suite-shape masking means the mutation is non-killing on the current court;
W909's R3 repro is the killing evidence for the failure class** (R3 rerun 2026-10-07 still
firing, expected — it IS the harness-shape demonstration). Status receipt: `w918b-awaiter-hardening.md`.

### 2. W765 GAP-B / GAP-C flipped OPEN → REPAIRED

- `w935-spec16-impl.md`: SPEC-16 `update :use` action (stamps `used_at`,
  `increment(:use_count, amount: 1)`, `AuditExportTokenNotAlreadyUsed` guard, `patch(:use)`
  json_api route) + SPEC-17 `AuditExportTokenExpiredTokenRefused` (typed `Ash.Error.Invalid`
  on `:expires_at`) on the `:use` path. 21/21 ×2 real runs; both mutations (remove
  NotAlreadyUsed; remove ExpiredTokenRefused) kill exactly the corresponding court at 20/21.
- `w940b-spec16-commit.md`: committed as **`fab56ae1`** (`feat(governance): SPEC-16/17
  audit export token use action (w935)`), per-path porcelain clean, 21 passed re-run on
  committed tree.

### 3. W938 dead-branch row — already landed, no append

Grep-verified: the W938 dead-branch row (`maybe_refusal/2` `[:refused, :failed]` clause dead
on the admitted fabric path, registered by `w938-dead-branch-register.md`) is present at
register line 64 since sweep 4. No append performed.

## Totals (re-derived by awk field-5 verification, not copied)

```
$ awk -F'|' '/^\| /{s=$5; gsub(/ +/,"",s); n[s]++; t++} END{for(k in n) print k, n[k]}' w859-typed-gap-register.md
Status 1        (header row)
TYPED-OPEN 2
OPEN 31
REPAIRED 15
TOTAL 49        (48 data rows)
```

**48 rows = 31 OPEN + 15 REPAIRED + 2 TYPED-OPEN.** Delta vs sweep 4 (33+12+3): OPEN −2
(GAP-B, GAP-C), REPAIRED +3 (GAP-B, GAP-C, W838-G1), TYPED-OPEN −1 (W838-G1).

Note: sweep 4 (w943b) appended rows 65-66 (W902 environmental, W838-G1) and flipped
W793/W796-G1/W849-backlog-1 but left the totals section stale at the W944 numbers; this
sweep rewrote the totals section to the re-derived numbers and appended the sweep-5 note.

## Concurrent-edit disclosure

The register was modified on disk twice mid-lane by concurrent lanes (Edit tool reported
"file had been modified on disk since you last read it"). All edits applied cleanly; totals
were computed from the post-edit disk state, so concurrent sweeps' flips (if any landed
after my final awk run) are not reflected in this receipt's numbers.

## Standing

- This receipt: ALIVE (register-write only, all facts from real file reads + awk/grep output
  quoted above; no build, no tests claimed).
- W838-G1 row: REPAIRED (harness-limitation documented; honesty boundary in-row).
- W765 GAP-B/GAP-C rows: REPAIRED (witnessed by w935 21/21 ×2 + mutations, committed fab56ae1).
- Register totals: RE-DERIVED (48 = 31 + 15 + 2).
