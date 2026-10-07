# W20 — ash_pplan failure adjudication (receipt, partial/interim)

*Backfilled by coordinator from lane interim status report.* Subject: /Users/sac/ash_pplan @ fix/ggen-verify-header 414a393, 2026-10-06. Lane still running at backfill time — final verdict pending.

## Findings to date
- Root cause of the failure cluster: 55 directories (deps/*/priv|src|include, priv/) had owner execute bit stripped (drw-------) — same environmental fault class as W91/W75/W151 (fleet-wide, OS-11). Restored to verified fixpoint (0 non-traversable).
- Residual suspect: unused-clause warning `defp rank(_), do: 9` at lib/ash_pplan/fond/policy_supervisor/offers.ex:132 under ggen_igniter's --warnings-as-errors verify (ManufactureTest).
- Full-suite run 3 contaminated by concurrent lanes on the shared checkout; plan: narrow reruns (manufacture_test.exs + one pack court) for an uncontaminated verdict. ETA ~20-30 min from status report.

## Coordinator endorsements
Permission-bit class confirmed fleet-wide (OS-11); narrow-rerun plan endorsed; the rank/9 clause should be checked against the pre-dirty tree before classifying session-introduced.

(Final verdict: append to this file when the lane lands.)
