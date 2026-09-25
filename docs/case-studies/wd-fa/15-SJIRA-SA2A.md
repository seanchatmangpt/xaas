# sJira + SA2A in WD Case Study 2

## Semantic Jira

sJira is the work/evidence projection.

For a PARTIAL case:

```
subject: FailureCase
obligation: acquire timeout waveform
owner: failure_analysis
precondition: drive/build identity resolved
required evidence: waveform
authority: none for construction
verifier: FA policy court
standing: OPEN / PARTIAL
```

The ticket is not canonical truth. It is a projection of the obligation already present in architecture state.

## Semantic A2A

SA2A is the capability interaction plane.

Representative bounded capabilities:

| Capability | Plane | Authority |
|---|---|---|
| reconstruct_subject | OBSERVE | none |
| retrieve_prior_cases | OBSERVE | none |
| rank_hypotheses | SELECT | none |
| test_applicability | SELECT | none |
| construct_diagnostic_work | CONSTRUCT | none |
| project_sjira | CONSTRUCT | none |
| verify_receipt | OBSERVE | none |
| compile_machine_experience | CONSTRUCT | requires verified input |
| production_actuation | DO | not part of Friday demo |

## Crossover criterion

The experiment succeeds at ST-6 when an admitted event can, without human context reconstruction:

```
select capability
→ construct semantic work
→ manufacture projection
→ execute verification court
→ produce replayable receipt
```

No LLM is required on a KNOWN class.
