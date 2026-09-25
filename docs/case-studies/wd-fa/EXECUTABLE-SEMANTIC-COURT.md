# Executable Semantic Court

The STOGAF pack is qualified as RDF, not only inspected as text.

`scripts/stogaf_semantic_court.py`:

1. parses the canonical Turtle files with RDFLib;
2. executes the SHACL shapes with pySHACL;
3. executes every SPARQL gate under `priv/packs/wd_cs2_pack/gates/`;
4. treats every returned gate row as a refusal;
5. writes `wd-cs2-stogaf-semantic-report.json`.

Expected exact-head result:

```
SHACL conforms = true
gate refusal rows = 0
standing = ALIVE
evidence ceiling = REPO_LOCAL_FIXTURE
```

This court validates the semantic profile mechanically. It does not promote production conformance or authority.
