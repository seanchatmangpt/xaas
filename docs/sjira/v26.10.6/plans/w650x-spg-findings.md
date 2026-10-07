# W650x — SpgGate Findings Adjudication (C23)

Lane W650x, xaas v26.10.6 campaign. Branch `feat/playwright-surface`.
No commit (per lane law). Adjudicates W984dj2's witnessed findings per
C23 pruner discipline. Documentation lane only: no code changes, no mix
runs.

## Subject

`Xaas.Actuation.SpgGate` (`lib/xaas/actuation/spg_gate.ex`) as courted
by W984dj2 (`w984dj2-spg-gate.md`). Inputs = that receipt's findings
F1/F2/F3 and its standing call; all read from the receipt on disk this
session, not from session memory.

## 1. Caller question — grounded

Re-grep 2026-10-07, `grep -rn SpgGate` over `lib/` and `test/`: exactly
two files hit — the module itself and `test/xaas/actuation/
spg_gate_test.exs`. **Zero call sites in `lib/`.** Confirms W984dj2's
finding unchanged.

Disposition: forward capability awaiting integration, same class as the
wasm host before W638 — an unadmitted-but-real kernel, not pruner
fodder. The receipt's standing call holds and is re-affirmed:
**PARTIAL_ALIVE as a capability, UNKNOWN as an integrated path**. The
zero-caller fact is what defers the F2 refinement (below): there is no
production seam whose caller shape could fix a refusal contract yet.

## 2. F1 (state-vocabulary case sensitivity) — DESIGN-ACCEPTED

`admit/1` accepts only `:admitted` / `"ADMITTED"`; lowercase `"admitted"`
refuses with typed `{:error, :spg_not_admitted}`.

Reasoning per the module's own admission contract: the refusal is
already typed and fail-closed (F3's exact-boundary property), so the
caller loses nothing but gets a precise atom. Normalizing case inside
the gate would *widen* a consequential-DO admission surface — the one
drift direction this module must never take. A caller with a rawer
vocabulary normalizes at its own boundary, with its own disclosure.
Not a refinement candidate.

## 3. F2 (KeyError on string-keyed fingerprint) — RECOMMENDED, deferred

`fingerprint_token/1` raises untyped `KeyError` on the string-keyed
shape `admit/1` itself accepts. The crash IS fail-closed (input is
refused), but untyped — inconsistent with the module's otherwise
all-typed refusal surface.

Disposition: typed-refusal refinement **RECOMMENDED for the integration
lane's work order**, not this lane. Zero callers today means no real
caller shape exists to fix the correct refusal contract (guard head
vs. `is_map/1` check vs. Map.get default); inventing one now would be
unreceipted design against a seam that does not exist. Recommendation
recorded in the appended follow-up section of
`w984dj2-spg-gate.md` for the integration lane.

## 4. F3 — no action

Typed refusal shape at the exact boundary; already ALIVE per court.
Not an open finding.

## Artifacts

- Appended "Follow-up adjudication (appended by lane W650x, 2026-10-07)"
  section to `docs/sjira/v26.10.6/plans/w984dj2-spg-gate.md`
  (append-only; original receipt text unmodified).
- This receipt.

## Verification

Read-back confirms both files on disk: the w984dj2 receipt now ends with
the W650x follow-up (caller re-grep result, F1 DESIGN-ACCEPTED, F2
RECOMMENDED-deferred); this receipt exists with the adjudications. No
`.ex`/`.exs` files touched (grep evidence above shows the only SpgGate
references remain the module and its test file, both unmodified).

## Standing

- `Xaas.Actuation.SpgGate`: PARTIAL_ALIVE (capability) / UNKNOWN
  (integrated path) — re-affirmed, unchanged by this lane.
- F1 disposition: DESIGN-ACCEPTED (final for this campaign).
- F2 disposition: typed-refusal refinement RECOMMENDED, owned by the
  future integration lane.
- Falsifier for the deferral: if a caller lands in `lib/` without the
  F2 typed-refusal refinement in the same diff, the integration lane
  inherited this receipt's recommendation and ignored it — that diff
  should be refused or amended.
