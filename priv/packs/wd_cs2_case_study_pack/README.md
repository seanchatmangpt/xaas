# wd-cs2-case-study-pack

Projection queries and templates for the WD Case Study 2 Semantic Case Study.
Driven by `python3 tools/wd_deck/wd_deck.py case-study [--check]`, which merges
`priv/packs/wd_cs2_pack/{case-study,claims,stogaf-core}.ttl`, the deck TTL under
`docs/case-studies/wd-fa/presentation/` and a computed `revision.ttl` into one
ontology, then runs `mix ggen_igniter.sync --engine sparql --pack-dir` once per
template. Rows are sorted in the templates (the sparql engine's ORDER BY is not
relied on).
