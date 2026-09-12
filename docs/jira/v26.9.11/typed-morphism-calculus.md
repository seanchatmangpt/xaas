# Typed Morphism Calculus — replace overloaded μ with a family of typed transformations

## Summary

Replace the single overloaded realization operator μ (as used in the original
`A = μ(O)` equation, which is not well-typed under `μ ∘ μ = μ` unless `A ⊆ O`)
with an explicit family of typed morphisms:

```
O --μ_a--> O* --μ_s--> K --μ_p--> P --μ_π--> Π --μ_i--> Intent  ReceiptInput --μ_r--> R
```

## Status

Candidate / Not Yet Implemented

## Scope

Required components (verbatim from the vetted body content):

- morphism ontology
- source/target type declarations
- composition validator
- identity morphisms
- deterministic composition identities
- morphism versioning
- morphism provenance
- morphism receipt generation
- illegal-composition refusal
- replay by morphism chain

## Key Invariant(s)

- Original (defective) equation: `A = μ(O)`
- Problem: `μ ∘ μ = μ` is not well-typed unless `A ⊆ O`
- Replacement chain: `O --μ_a--> O* --μ_s--> K --μ_p--> P --μ_π--> Π --μ_i--> Intent  ReceiptInput --μ_r--> R`

## Relationship to Existing Work

Not established beyond the equation this ticket supersedes (`A = μ(O)`). No
other ticket/PR relationship was stated in the vetted source material for
this workstream.

## Falsifiers / What Would Defeat This

- A composition of two declared morphisms in the chain type-checks (source/target
  types align) yet the composition validator accepts it despite no such edge
  being declared in the morphism ontology — proves the validator is not
  enforcing the declared ontology.
- An illegal composition (e.g. `μ_p` applied directly to `O` instead of `K`)
  is silently accepted rather than refused — proves illegal-composition
  refusal is not implemented or not enforced.
- A replay of a receipt's morphism chain (`R` back through `μ_r`, `μ_i`, `μ_π`,
  `μ_p`, `μ_s`, `μ_a`) produces a different intermediate artifact than the one
  originally recorded — proves replay-by-morphism-chain is not deterministic.
- Two morphisms in the chain carry no version or provenance metadata, or the
  same morphism name resolves to different implementations across runs without
  a version distinguishing them — proves morphism versioning/provenance is
  absent.
