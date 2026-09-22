# STOGAF Semantic Pack

The WD CS2 pack now contains a semantic architecture layer in addition to the original quality-loop ontology.

## Files

```
priv/packs/wd_cs2_pack/
├── ontology.ttl
├── stogaf.ttl
├── stogaf-core.ttl
├── stogaf-wd-instance.ttl
├── stogaf-shapes.ttl
├── gates/
│   ├── 010_architecture_episode_complete.rq
│   ├── 020_authority_ceiling.rq
│   ├── 030_view_projection.rq
│   ├── 040_machine_experience.rq
│   └── 050_requirement_traceability.rq
└── queries/
    ├── conformance.rq
    ├── requirements.rq
    └── views.rq
```

Any gate result is a refusal/failure to qualify that projection.

The pack is deliberately bounded to repository-local architecture evidence and does not grant production authority.
