# Baseline → Gap → Target

## Baseline architecture

The case prompt describes failure-analysis knowledge fragmented across:

- image-heavy PowerPoint;
- Confluence;
- Excel;
- structured test results;
- rework history;
- BOM;
- lot/line provenance;
- firmware/build context.

The baseline operating assumption is that engineers repeatedly reconstruct context before they can decide the next useful diagnostic action.

## Target architecture

A governed semantic operating loop where:

```
failed subject
→ evidence graph
→ candidate hypotheses
→ deterministic admission
→ semantic work
→ engineer disposition
→ verification
→ MachineExperience
→ future replay
```

The target does **not** require replacing existing source systems.

## Machine-addressable gaps

| Gap | Current condition | Target condition | Closure evidence |
|---|---|---|---|
| G-01 Identity | context reconstructed from documents | stable subject/object identities | OCEL object graph |
| G-02 Provenance | citations may be prose-level | source-bound evidence objects | evidence references |
| G-03 Admission | similarity can be confused with applicability | deterministic rule + evidence closure | KNOWN/PARTIAL/UNKNOWN court |
| G-04 Work | next steps live in analyst prose | typed obligation/owner/evidence | sJira projection |
| G-05 Authority | human loop is informal | explicit human gate | SELECT_CONSTRUCT_ONLY |
| G-06 Replay | prior case is retrieved but not executable | verified experience replay | UNKNOWN→KNOWN fixture |
| G-07 Views | each audience gets manually rebuilt artifact | viewpoint projection of O* | browser/STOGAF view |
| G-08 Manufacture | runtime implementations drift | generated projection from canonical semantics | target ST-5 |
| G-09 Autonomics | humans reconstruct routine context | admitted events select/construct work | target ST-6 |
| G-10 Production consequence | no live WD authority/evidence | bounded authorized production consequence | ST-7 UNKNOWN |
| G-11 Closed-loop production | no observed production consequence | receipt reconciles outcome | ST-8 UNKNOWN |
| G-12 Organizational learning | no production longitudinal data | verified work lowers future cost | ST-9 UNKNOWN |

## Design consequence

Friday work should attack G-01 through G-09 only. G-10 through G-12 are deliberately outside the evidence ceiling.
