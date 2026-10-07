# W944 — Typed-Gap Register: 3 New Rows (W943 finding closure)

Lane W944, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD at lane
start `a0723bf6`). No commit (lane contract); no build root. Written files:
`w859-typed-gap-register.md` (3 rows appended + totals updated) and this receipt.

## Context

W943 found three landed repairs whose gaps were never registered in the W859
typed-gap register. This lane appends each as a row with dual citations
(disclosure surface + landed repair receipt).

## Rows appended

1. **W880 counterfactual typedoc contradiction → REPAIRED**
   - Surface: `lib/xaas/semantics/counterfactual.ex:167-194` (`normalize_name/1` only
     accepts atoms/binaries; `Function.info(fun, :name)` returns a tuple).
   - Disclosure: `w880-cf-doctests.md` (verified: incident text present at :8).
   - Repair: `w907-bare-fun-fix.md` (exists; mutation-killed per task brief).
2. **W836 health-check no-timeout → REPAIRED**
   - Surface: `lib/xaas_web/controllers/health_controller.ex` (now carries
     `@check_timeout_ms 2000` bounded `Task.async/await` execution — observed on tree).
   - Disclosure: `w836-health-court.md` (verified: "a hung check would hang the request"
     typed-gap line at :29).
   - Repair: `w860-health-timeout.md` (exists; 12/12 incl. hung-check court per brief).
3. **W893 GAP(CancelDoesNotReleaseSlot) → OPEN (w925 IN-FLIGHT)**
   - Surface: `lib/xaas/conference/registration.ex:158` (`EnforceSessionCapacity`).
   - Disclosure: `w893-enrollment-journey.md` (verified: GAP line at :75).
   - w925 receipt: `w925-slot-release.md` ABSENT (`test -f` negative, lane falsifier) →
     status OPEN per lane contract.
   - **Observed evidence (recorded, not overclaimed)**: the code-side fix IS landed —
     `EnforceSessionCapacity` now filters `status in [:registered, :attended]` and its
     moduledoc states it closes W893's gap. The row stays OPEN until a w925 receipt with
     a real court run exists; the row's status-receipt cell names w893 + w925 IN-FLIGHT.

## Totals (grep-verified)

```
awk -F'|' '/^\| /{s=$5; gsub(/ /,"",s); if(s=="REPAIRED")r++;
else if(s=="OPEN")o++; else if(s=="TYPED-OPEN")t++} END{print r+o+t}' → 46
per-status: REPAIRED=9  OPEN=35  TYPED-OPEN=2  (sum = 46 data rows)
```

Updated totals block in the register: REPAIRED 7→9, OPEN 34→35, total 43→46, plus a
W944-update annotation naming the three rows and the w925 IN-FLIGHT condition.

## Standing

- 2 rows REPAIRED with dual citations witnessed on disk (w880+w907, w836+w860);
  repair-run numbers transcribed from the task brief / receipt files, not re-run in
  this lane (register-only lane, no build root).
- 1 row OPEN by the lane's own falsifier (w925 receipt absent), despite landed code —
  disclosed rather than flipped, per `inspection≠execution`.
- Standing: PARTIAL_ALIVE. Falsifier for the open residue: `test -f
  docs/sjira/v26.10.6/plans/w925-slot-release.md` + its court run → then flip the W893
  row to REPAIRED and totals to 9 OPEN / 10 REPAIRED.
