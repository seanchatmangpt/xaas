# ZOE whole-event DfCM + SA2A simulation

## Boundary

This candidate composes the complete event loop without manufacturing real-world authority:

Planning Center observation
+ registration/check-in observation
+ volunteer/admin observation
+ security/incident observation
-> Xaas.Zoe.EventSimulation
-> SA2A obligations (CANDIDATE only)
-> downstream authority + CommandBus + receipt (not executed here)

DfCM preserves the entire candidate set before any irreversible selection. Capacity numbers are never invented by the simulator: registration throughput, security capacity, and minimum administration staffing are explicit policy inputs. Missing policy fails closed.

## Whole-event phases

The court traverses pre_event -> arrival -> live_event -> closeout.

It can expose candidate obligations for completing the roster, requesting administration reinforcement, requesting registration reinforcement, resolving registration exceptions, requesting security reinforcement, reporting every observed security incident or near miss, and submitting final attendance.

Every manufactured obligation carries a stable identity, exact observation sequence, phase, capability identity, input projection, authority=NONE, authority_boundary=CONSTRUCT_ONLY, standing=CANDIDATE, and dispatch=NOT_EXECUTED.

## SA2A law

The simulator does not duplicate ash_a2a authority, grants, CommandBus, durable receipt, or replay logic. It manufactures only the candidate capability request that a real SA2A runtime can later admit or refuse.

Simulation != Authority
Candidate != Command
Construct != DO
No receipt => no execution claim

## Evidence ceiling

A green repository court proves deterministic whole-event simulation and SA2A-shaped candidate construction at the exact XaaS revision. It does not prove live Planning Center reads, a real ZOE event, SA2A dispatch, provider mutation, deployment, or cross-repository ALIVE standing.
