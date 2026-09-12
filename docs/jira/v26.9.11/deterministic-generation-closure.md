# Deterministic Generation Closure — absolute boundary between canonical graph and generated projections

## Summary

Enforce `g(CanonicalGraph) -> Projection` as the only lawful path from the canonical
graph to any generated artifact, and forbid `CanonicalGraph + ManualPatch` as a path.
This applies across generated Ash resources/changes, planner models, HDDL, PDDL, POWL,
RDF/R2RML, SHACL, OCEL schemas, process adapters, receipt schemas, validation code,
docs, and test fixtures.

## Status

Candidate / Not Yet Implemented

## Scope

Required components (verbatim from the source workstream description):

- Canonical generation manifest
- Generator capability registry
- Source-to-projection dependency graph
- Deterministic generation lock
- Generated-file provenance headers
- Generated-file modification detector
- Regeneration verifier
- Projection hash manifest
- Generator-unsupported receipt
- Irreducible handwritten-residue registry

## Key Invariant(s)

- `g(CanonicalGraph) -> Projection` is the only lawful generation path.
- `CanonicalGraph + ManualPatch` is a forbidden path — no projection may be produced
  by patching a generated artifact by hand instead of regenerating it from the
  canonical graph.

## Relationship to Existing Work

No relationship to other tickets, PRs, or branches was specified in the source
material for this workstream. (Per task instructions, the `codex/causal-admission-closure`
branch / commit `38d9933efec49a8006456a7a77f61e89689eb460` check applies only to the
`causal-admission-pr44-ci-transport-fix` slug, which this ticket is not.)

## Falsifiers / What Would Defeat This

- A generated file (Ash resource/change, planner model, HDDL/PDDL/POWL artifact,
  RDF/R2RML/SHACL/OCEL schema, process adapter, receipt schema, validation code, doc,
  or test fixture) exists whose content differs from what regenerating it from the
  current canonical graph would produce, with no corresponding entry in the
  irreducible handwritten-residue registry.
- The generated-file modification detector fails to flag a manual edit to a file
  carrying a generated-file provenance header.
- The regeneration verifier passes on a projection whose hash does not match the
  projection hash manifest.
- A generator capability gap is worked around with a handwritten patch instead of
  producing a generator-unsupported receipt and registering the gap in the
  irreducible handwritten-residue registry.
