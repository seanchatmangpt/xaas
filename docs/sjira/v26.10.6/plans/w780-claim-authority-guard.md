# W780 — Claim-Shaped Authority Guard (closes XAAS-W763-G1)

Subject: /Users/sac/xaas @ feat/playwright-surface, base HEAD a0723bf6 (uncommitted lane diff).
Lane: W780, v26.10.6 campaign.

## Before (W763 measured gap)

`Xaas.Actuation.run/4` -> `admit_authority/2`
(`lib/xaas/actuation.ex`, ~line 599) accepted ANY nonempty map as delegated
authority evidence — including a `%Xaas.Semantics.ComputationClaim{}` — so a
CANDIDATE claim could authorize actuation (measured: actuation succeeded, the
Provider row flipped, real consequence crossed the boundary).

## After

Structural guard in `admit_authority/2`: a struct-shaped authority map
(`Map.has_key?(authority, :__struct__)`) is refused with the new closed-set
atom `:claim_shaped_authority_refused`.

Refusal atom choice (documented per task): NEW closed-set atom, not the
delegated-evidence family — `:delegated_actuation_requires_authority_evidence`
names MISSING evidence, while a ComputationClaim is POWERLESS evidence; the
distinction is court-load-bearing, and `Xaas.Ultracode.RuntimeSurface.Failure.from_term/1`
maps the delegated atom to "UNAUTHORIZED" already, so overloading it would
misclassify the refusal. No other existing atom fits.

Lawful-shape survey (all call sites, lib/ + test/): ultracode lease
(`ultracode_lease_actuation`), sa2a executor (`machine_policy`), maker-checker
bridge (`maker_checker_approval`), stripe webhook, liveview librarian, revenue,
gymact, quiescent stop, every court — lawful authority evidence is ALWAYS a
plain map (never a struct). Zero lawful struct authorities exist, so the guard
refuses no declared-lawful shape.

## Files

- `lib/xaas/actuation.ex` — guard + provenance comment only.
- `test/xaas/sa2a_computation_boundary_test.exs` — `:w763_measured_gap` test flipped to assert the typed refusal (kept `@tag :w763_measured_gap`, added `:w780_closed`; old succeeded-shape assertion retained as mutation-rationale comment).
- `docs/sjira/v26.10.6/plans/w780-claim-authority-guard.md` — this receipt.

## Mutation rationale

Drop the guard → `admit_authority/2` accepts the claim → the call returns the
old `{:ok, %{status: :succeeded, replay?: false}}` shape → the FIRST assert to
fail is the refusal-shape match in the `:w763_measured_gap` / `:w780_closed`
court at `test/xaas/sa2a_computation_boundary_test.exs:180`, and the Provider
row flips to `:active` (second assert also fails).

## Verification (real runs, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW780)

- `mix test test/xaas/sa2a_computation_boundary_test.exs` → 21 passed, exit 0
  (log `/tmp/w780_boundary2.log`).
- `mix test test/xaas/actuation_test.exs` → 5 passed.
- `mix test test/xaas_web/execution_fabric_deepening_test.exs` (W745) → 15 passed.
- `mix test test/xaas/actuation/run_idempotency_deepening_test.exs` (W747) → 10 passed.
- Measured refusal wire shape:
  `{:error, {:reactor_failed, %Reactor.Error.Invalid{errors: [%Reactor.Error.Invalid.RunStepError{error: :claim_shaped_authority_refused}]}}}`.

## Standing

ALIVE (lane-local, uncommitted). Transport notes: first compile attempt hit
ENOSPC (concurrent-lane disk pressure, transient) and one mid-compile ENOENT
(concurrent lane deleted `lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex`
during my compile — shared-checkout race, not my diff); both cleared on retry.
`_build-laneW780` deleted at integration per lane-lease cleanup law.
