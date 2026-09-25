# HANDWRITTEN ledger (DfCM)

Hand-written product-surface artifacts, admitted per contract section 2.
Monotonically shrinking per milestone is the requirement for this list.

| path | semantic element | missing capability | intended owner pack | date |
|---|---|---|---|---|
| sprtool.py | SPR document parser/validator/renderer (rules S1-S4, corpus-derived bounds) | no admitted pack expresses SPR-format semantics (statement extraction, succinctness fences, round-trip render) | dfcm-agent-pack: spr-format family (proposed; pack.toml + ontology facts + gates via marketplace admission) | 2026-09-16 |
| tests/test_sprtool.py | executable proof for sprtool (16 cases, corpus + negatives + CLI exits) | no pack generator owns test scaffolding for this artifact | same spr-format family, gate templates | 2026-09-16 |

Paydown plan: extract the S1-S4 rule constants and document model as ontology
facts plus templates in the proposed spr-format family; sprtool.py and its
tests then become generator projections and these rows retire.
