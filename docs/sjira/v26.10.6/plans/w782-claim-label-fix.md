# W782 — ComputationClaim evidence-class refusal relabel (W763 finding G2)

Subject: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface, canonical checkout.
Scope: `lib/xaas/semantics/computation.ex`, `test/xaas/sa2a_computation_boundary_test.exs` (extend only), this receipt. No commit (lane law).

## Change

W763 finding G2: `ComputationClaim.new/1` routed an out-of-vocabulary
`evidence_class` into the generic else-clause, where any failing binary was
matched by `standing when is_binary(standing)`, so e.g. `"TELEPATHIC"`
surfaced mislabeled as `{:error, {:computation_claim_standing_refused, "TELEPATHIC"}}`
— a vocabulary error wearing a standing refusal.

Fix: the evidence-class check is now an explicit `with` step via a private
`validate_evidence_class/1`, returning its own refusal atom:

```elixir
defp validate_evidence_class(evidence_class) when evidence_class in @evidence_classes,
  do: {:ok, evidence_class}

defp validate_evidence_class(evidence_class),
  do: {:error, {:computation_claim_invalid_evidence_class, evidence_class}}
```

Refusal-vocabulary closure kept: no atoms removed; one atom added
(`:computation_claim_invalid_evidence_class`); the `:computation_claim_standing_refused`
atom is now reserved for standing only.

## Court update (before/after)

`test/xaas/sa2a_computation_boundary_test.exs` — updated W763's assertion:

- before: `assert {:error, {:computation_claim_standing_refused, "TELEPATHIC"}} = claim(%{evidence_class: "TELEPATHIC"})`
- after: `assert {:error, {:computation_claim_invalid_evidence_class, "TELEPATHIC"}} = claim(%{evidence_class: "TELEPATHIC"})`

Added dedicated regression test
("a mislabeled standing refusal is not used for evidence-class failures (W782 regression)")
asserting both: standing atom still fires for genuine standing failures, and the
evidence-class atom fires for vocabulary failures.

## Mutation rationale (real run)

Reverted the lib change in-place (guard restored), reran the file:
`Result: 19/21 passed, exit=2` — the two W782 asserts
(`computation_claim_invalid_evidence_class`) fail first. The regression test is
the falsifier for this fix; reverted-revert restored green. Log: /tmp/w782_mut.log.

## Verification (real tails)

```
$ MIX_ENV=test MIX_BUILD_ROOT=_build-laneW782 mix test test/xaas/sa2a_computation_boundary_test.exs
run A: exit=0 ... Result: 21 passed      (/tmp/w782_a.log)
run B: exit=0 ... Result: 21 passed      (/tmp/w782_b.log)
post-mutation restore run C: exit=0 ... Result: 21 passed  (/tmp/w782_c.log)
```

Boundary file green ×2 (plus post-mutation confirmation run), 21/21.

## Notes / pre-existing observations

- One transient failure of the W780 guard test at :193 occurred in an early run:
  the file was edited by lane W780 mid-run; the compiled snapshot carried the
  old assertion shape while disk already had the corrected
  `{:error, {:reactor_failed, %Reactor.Error.Invalid{...}}}` shape. Current disk
  state passes; not introduced by W782. Recorded, no action.
- `_build-laneW782` deletion was denied by the permission system; the lease is
  left for the coordinator to clean per fanout cleanup law.

## Standing

ALIVE — fix observed executing on exact subject (a0723bf6 + W782 diff), green ×2
with mutation-falsified regression assert. Generated vs handwritten: handwritten
(hand-edited source module; no generator profile for this surface).
