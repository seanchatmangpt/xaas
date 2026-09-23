# WD FA reference first mile (lane V23-W; PRD 9.2, Friday G12)

Western Digital FA Morning Brief System, phase one, compiled through the v26.9.23 first-mile
pipeline. Successor order `v23:WO-V23-W` (typed Successor under `v23:GC-26.9.24`): nothing here
can hold GC-26.9.23 open. Status: DRAFT (the WBPR awaits operator acceptance).

## Pipeline (replay from the xaas root)

1. `wbpr.md` -- DRAFT WBPR (provenance, not authority; PR-001, AR-003).
2. `wbpr.extract.json` -- the LLM candidate extraction (the only LLM edge,
   `llm:claude-opus-5-5@wave-B1c/V23-W`) -> `candidates.ttl`:
   `python3 scripts/sjira/prose_spans.py emit --source docs/sjira/v26.9.23/wd-fa/wbpr.md
   --extract docs/sjira/v26.9.23/wd-fa/wbpr.extract.json --out docs/sjira/v26.9.23/wd-fa/candidates.ttl
   --source-path docs/sjira/v26.9.23/wd-fa/wbpr.md --extracted-by llm:claude-opus-5-5@wave-B1c/V23-W`
3. `goal.ttl` (GC-WDFA-PILOT, gates WDFA-0..6, `wd-fa:` capabilities) -> `compiled/` (GENERATED):
   `GGEN_IGNITER_DIR=/Users/sac/wt/v26922/fri/ggen_igniter-int sh docs/sjira/v26.9.23/courts/gi_mix.sh
   semantic_jira.compile_prose --source $PWD/docs/sjira/v26.9.23/wd-fa/wbpr.md --candidates
   $PWD/docs/sjira/v26.9.23/wd-fa/candidates.ttl --goal $PWD/docs/sjira/v26.9.23/wd-fa/goal.ttl
   --out-dir $PWD/docs/sjira/v26.9.23/wd-fa/compiled [--check]`
4. `supplied/*.txt` -- text projections of the operator-supplied deck (`probes/deck_text.py`),
   digest-bound by `receipts/WDFA-SUPPLY.json`.
5. `claims.ttl` -- the canonical claims ledger (every claim SUPPLIED | PUBLICLY_OBSERVABLE |
   ARCHITECTURAL_INFERENCE | WD_DEPENDENT_UNKNOWN) -> `proposal.md` (GENERATED; never edit):
   `python3 scripts/sjira/wd_claims.py render --ledger docs/sjira/v26.9.23/wd-fa/claims.ttl
   --out docs/sjira/v26.9.23/wd-fa/proposal.md`
6. Court (the V23-W lane gate):
   `python3 scripts/sjira/prose_spans.py check --source docs/sjira/v26.9.23/wd-fa/wbpr.md
   --candidates docs/sjira/v26.9.23/wd-fa/candidates.ttl && python3 scripts/sjira/wd_claims.py check
   --ledger docs/sjira/v26.9.23/wd-fa/claims.ttl --proposal docs/sjira/v26.9.23/wd-fa/proposal.md`

## Receipts (`receipts/`, fleet R schema, each ADMITTED by validate_receipt.py)

| receipt | subject | observes |
|---|---|---|
| WDFA-SUPPLY | xaas 757be45 | deck zip -> supplied texts replay byte-identically |
| WDFA-COMPILE | xaas 757be45 | 61 candidates admitted, 37 work orders, `--check` byte-identical, goal admitted |
| WDFA-KERNEL-PROBE | autofde-lab eb93405c | K1..K10 on the deterministic kernel (no TPOT), 4 no-TPOT court tests |
| WDFA-PACK-COURT | ggen-marketplace 420bc91e | ggen-rendered witness court: 5 gates x pass/fail |
| WDFA-COURT | xaas d6fb40e | wd_claims.py tests, revert mutations, F3 guard |

## Later steps (not done here)

The DOCX/PDF render of the proposal and the operator's text freeze follow operator acceptance;
both regenerate from `claims.ttl`. `courts/wdfa_gate.sh WDFA-0` stays UNKNOWN until an
`acceptance.json` records the operator's and a Western Digital sponsor's acceptance.
