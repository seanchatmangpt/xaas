# v26.9.23 prose candidates (GC23-0, PRD PR-002, ARD §5.2-5.3)

Pipeline for `../prd-ard.md` (accepted prose, byte-identical, sha256:7c8797b2...0658212):

1. **extract (the LLM edge, recorded as one)**: an LLM reads the prose and writes `prd-ard.extract.json`,
   a list of `{kind, statement, quote, occurrence?, required_by?, boundary_class, hints?}`. This file is the
   raw O; `sj:extractedBy "llm:claude-opus-5-5@wave-B0/V23-X"` names the extractor on every candidate.
2. **emit (deterministic)**: `python3 scripts/sjira/prose_spans.py emit --source docs/sjira/v26.9.23/prd-ard.md
   --extract <json> --out prd-ard.ttl --source-path docs/sjira/v26.9.23/prd-ard.md --extracted-by <id>`
   binds each quote to its unique UTF-8 byte span and writes PVOCAB Turtle (DRIVER.md), sorted, byte-stable.
3. **check (deterministic)**: `prose_spans.py check --source ... --candidates prd-ard.ttl --require-gates 13
   [--extract <json>]` re-verifies digest, span bytes, IRI, kind, boundary class, standing UNKNOWN and that
   every gate GC23-0..12 has a candidate; `--extract` also refuses hand edits (re-emit must be byte-equal).
   `--summary <json>` writes the verified tally (kinds, per-target `sj:requiredBy` counts including the root
   `GC-26.9.23`, not-required count, `required + not_required = candidates`); receipts copy counts from it.
4. **admit (not here)**: candidates stay `sj:candidateStanding "UNKNOWN"`; admission into O* is ggen_igniter
   `compile_prose` (lane V23-C). Never edit `prd-ard.ttl` by hand: edit the JSON and re-emit.

No LLM runs in emit, check or admission; a second LLM pass over the same accepted revision is not
permitted (ARD §5.5). Tests: `python3 -m unittest discover -s scripts/sjira -p 'test_*.py' -v`.
