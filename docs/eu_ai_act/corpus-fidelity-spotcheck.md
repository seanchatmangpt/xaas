# Corpus Fidelity Spot-Check — EU AI Act corpus.json

Lane: W473, EU-AI-Act Chicago-test wave. Subject: `/Users/sac/xaas/docs/eu_ai_act/corpus.json`
(as fetched 2026-10-07T02:21:26Z from the artificialintelligenceact.eu AI Act Explorer mirror).

## Method

Second independent source: `saidbazyar/eu-ai-act-corpus`
(`data/en/articles.json`, fetched 2026-10-06 from raw.githubusercontent.com), whose text is
sourced directly from EUR-Lex CELLAR (Publications Office) — an independent publication
channel from the FLI mirror used to build corpus.json.

Direct EUR-Lex (`eur-lex.europa.eu`) was attempted first and blocked this network with a
13 KB bot-check page on both the CELEX HTML, ELI `OJ:L_202401689`, and PDF routes
(transport failure recorded, text unavailable via that hop).

Comparison: 8 sampled lines, wording compared after normalization (NFKC, whitespace
collapse, smart-quote/dash folding). Article-count integrity checked for ids 1..113.

## Per-sample comparison table

| line_id | subject | verdict |
|---|---|---|
| 3.1 | 'AI system' definition | MATCH |
| 5.1.a | prohibited manipulative/subliminal practices | MATCH |
| 10.3 | data governance — training/validation/test data | MATCH |
| 13.1 | transparency of high-risk systems | MATCH |
| 14.4.e | human oversight 'stop' button | MATCH |
| 15.1 | accuracy/robustness/cybersecurity | MATCH |
| 50.1 | provider disclosure of AI interaction | MATCH |
| 99.3 | penalties — prohibited-practice fines | MATCH |

Every sampled paragraph is byte-equal after whitespace/typographic normalization against
the CELLAR-sourced text. Raw comparison output preserved at `/tmp/cmp_report.txt`
(corpus segment and independent-source segment shown side by side per sample).

## Article-count integrity

- corpus.json: 113 articles, ids 1..113 all present, zero missing, zero duplicates.
- Independent source also contains 113 articles.
- Spot-checked titles (1, 3, 5, 50, 99) agree; differences are capitalization only
  ("Subject Matter" vs "Subject matter") — formatting, not substantive.

## Verdict

**FIDELITY-CONFIRMED** for the sampled surface.

- Matches: 8/8. Diffs: 0. Mismatches: 0.
- Known disclosed caveat unchanged: the mirror renders pre-amendment text for paragraphs
  replaced by later amendments (per corpus structure_note); this is a coverage policy of
  the source, not a wording defect, and was not contradicted by any sample here.
- Title-capitalization variance between the two publications is formatting-only.

## Sources

- [saidbazyar/eu-ai-act-corpus (EUR-Lex CELLAR sourced, EN articles)](https://github.com/saidbazyar/eu-ai-act-corpus)
- [EUR-Lex CELEX:32024R1689 (attempted; blocked — transport failure recorded)](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32024R1689)
- [artificialintelligenceact.eu (the corpus's own first source, cross-touched)](https://artificialintelligenceact.eu/)
