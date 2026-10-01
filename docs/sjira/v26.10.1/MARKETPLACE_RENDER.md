# ggen-marketplace render contract — Chicago v26.10.1

## Objective

Manufacture every Chicago consumer artifact from the RDF in this directory. Do not hand-author
operator, seller, verification or replay views.

Canonical input:

- docs/sjira/v26.10.1/goal.ttl
- docs/sjira/v26.10.1/chicago.ttl
- docs/sjira/v26.10.1/projections.ttl

Target owner:

- seanchatmangpt/ggen-marketplace
- intended pack identity: chicago-xaas-surface-pack@26.10.1

## Current observed marketplace state

At marketplace base 05233917e903cb64a3bfdf297d677fd404253ac2:

- chicago-graphlaw-court-pack exists, but it is GraphLaw-specific and its README reports the
  current corpus as REFUSED / UNVERIFIED; it is not the general XaaS Chicago renderer.
- sjira-marketplace-feedback-pack owns the residual -> Semantic Jira -> marketplace capability
  feedback edge, not consumer rendering.
- xaas-public-ash-projection-pack owns public SHACL -> Ash construction, not Chicago view rendering.

Therefore the broad Chicago renderer is currently UNSUPPORTED(generator-capability). Do not
mislabel one of the existing packs as equivalent.

## Required renderer outputs

The new marketplace pack should consume the three RDF inputs and deterministically manufacture:

1. machine projection
   - exact subject
   - root goal identity
   - required and successor layers
   - repository owner
   - capability id
   - evidence horizon
   - authority ceiling
   - projection identity
   - candidate case ids
2. verification projection
   - one row per required layer
   - no inherited standing
   - evidence/receipt slots remain absent/UNKNOWN until observed
   - candidate positive/negative scenarios listed separately from observations
3. executive/seller projection
   - customer problem
   - desired outcome
   - capabilities
   - what is demonstrated vs candidate-only
   - authority boundary
   - current evidence/standing
   - no repository mechanics required for the main narrative
4. replay projection
   - source graph identity/digest
   - exact Chicago subject
   - renderer identity/version
   - deterministic output digests

All generated outputs carry authority NONE.

## Generation law

source graph
  -> SPARQL query
  -> ggen-marketplace template
  -> generated artifact
  -> second render
  -> byte identity
  -> consumer validation
  -> receipt

The pack must refuse:

- missing exact Chicago subject;
- duplicate layer ids;
- missing capability id;
- projection authority other than NONE;
- a required layer with no repository owner;
- a generated standing claim not backed by an input receipt;
- subject drift between machine/executive/verification/replay outputs;
- nondeterministic second render.

## Consumer boundary

XaaS consumes the machine projection as representation only. AshSurface projects XaaS state.
Neither the marketplace renderer nor AshSurface becomes business-semantic or DO authority.

The target runtime topology is:

sJira RDF -> ggen-marketplace render -> XaaS -> AshSurface
                                      -> /system
                                      -> /chicago
                                      -> seller projection

The renderer may later generate LiveView/JS descriptors, but that is an extension of the same
semantic source, not a reason to author a second Chicago model.
