# Closed-Loop Stability Verifier — detect oscillation/divergence across Observe→Plan→DO cycles

## Summary

Once a process can observe, plan, execute, and observe again, it is a feedback
controller and can oscillate or diverge even when every individual transition
is lawful. This workstream adds a verifier layer that evaluates the stability
of the closed loop across repeated Observe→Plan→DO cycles, distinct from the
lawfulness of any single transition within a cycle.

## Status

Candidate / Not Yet Implemented

## Scope

Required components:

- process-state vector projection
- cycle/oscillation detector
- fixed-point convergence detector
- contractivity estimator
- Lyapunov-candidate interface
- passivity verifier interface
- spectral-radius evaluator
- retry/fairness policy monitor
- divergence guard
- stability refusal receipt
- stability metrics exporter

## Key Invariant(s)

- `TransitionValid(A→B)` is not sufficient for `ClosedLoopStable({A→B→A→B→...})`.
  A sequence may be lawful at every step while the whole is pathological.
- Admit repeated execution only when the applicable stability regime remains
  satisfied — i.e. `Admit(repeat) ⇒ StabilityRegime(cycle) holds`, checked per
  cycle, not once at the first transition.

## Relationship to Existing Work

Not specified in the source material beyond the general Observe→Plan→DO
(closed-loop control) framing; no other ticket/PR relationship was given and
none is asserted here.

## Falsifiers / What Would Defeat This

- A repeating state sequence (e.g. `A→B→A→B→...`) that the cycle/oscillation
  detector fails to flag despite every individual transition being
  independently `TransitionValid`.
- A process-state trajectory that diverges (unbounded growth) under a
  spectral radius or contractivity estimate that the evaluator reports as
  stable.
- A case where the divergence guard permits continued execution past the
  point a Lyapunov-candidate or passivity check would show the loop is not
  converging.
- A stability refusal that occurs without a corresponding stability refusal
  receipt being emitted, or a metrics export that does not reflect an actual
  refusal event.
