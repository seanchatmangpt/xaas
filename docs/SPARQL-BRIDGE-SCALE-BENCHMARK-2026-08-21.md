# SPARQL Bridge Scale Benchmark — 2026-08-21

Measure-phase follow-up to the Define-phase scoping of
`sparql_count_by_class/0` (`lib/mix/tasks/xaas.close_coverage_gap.ex`, lines
132–183). Define established the real cost breakdown and a real concern
threshold of roughly 30,000–50,000 total K-graph rows. This benchmark
re-measures the real production code path at smaller, currently-plausible
scales (100 / 1,000 / 10,000 rows) using Turtle shaped exactly like
`Xaas.SparqlBridge.to_turtle/0`'s real output, to check whether the pattern
is safe well below the Define-phase concern zone.

## Method

- Real, isolated benchmark — no production tables touched.
- Turtle generator (`gen_real_shape_ttl.py`, scratchpad) reproduces
  `Xaas.SparqlBridge.to_turtle/0`'s exact predicate shape per class, taken
  directly from `lib/xaas/sparql_bridge.ex`'s `render_individual/2`:
  - `aacm:PlannerCandidate` — 6 predicates/row (`a`, `aacm:query`,
    `aacm:trajectorySha256`, `aacm:solver`, `aacm:domain`,
    `aacm:requestedAt`)
  - the other 4 tracked classes (`PlannerCatalogRequest`,
    `PlannerMatchRequest`, `PlannerCacheStatsRequest`,
    `PlannerCacheHotsetRequest`) — 3 predicates/row (`a`, `aacm:query`,
    `aacm:requestedAt`; `trajectorySha256` real-omitted for these, matching
    the moduledoc's stated real-nil behavior for non-solve calls)
  - rows spread evenly across the 5 classes, real UUIDv4 subject ids, real
    `xsd:dateTime` literals, real sha256 hex digests for
    `trajectorySha256`
- Query script (`prod_query_script.py`, scratchpad) is a byte-for-byte copy
  of the `python_script` heredoc in `sparql_count_by_class/0` — same
  `rdflib.Graph().parse(..., format="turtle")` call, same
  `SELECT ?class (COUNT(?s) AS ?n) WHERE { ?s a ?class . FILTER(...) }
  GROUP BY ?class` query, same JSON-to-stdout shape.
- Timed with `/usr/bin/time -p python3 prod_query_script.py <ttl>` — a real
  `python3` subprocess spawn per run, real wall-clock (`real` field), same
  invocation pattern `System.cmd("python3", [script_path, ttl_path], ...)`
  uses. Each scale run 3 times; table reports the median, both other real
  runs are listed since the first 10,000-row run showed a one-time
  cold-filesystem-cache outlier.
- Environment: this machine, `python3 3.14.3`, `rdflib 7.6.0` — same
  versions the Define-phase measurement and the production code's own
  comment cite.

## Results

| Total rows (5 classes) | Triples in file | Real wall time (3 runs) | Median | vs. threshold |
|---|---|---|---|---|
| 100 | 360 | 0.33s, 0.32s, 0.22s | **0.32s** | well under "a few seconds" |
| 1,000 | 3,600 | 0.57s, 0.33s, 0.33s | **0.33s** | well under "a few seconds" |
| 10,000 | 36,000 | 3.62s\*, 1.46s, 1.48s | **1.48s** | under "a few seconds" |

\* First 10,000-row run was a cold-filesystem-cache outlier (first read of
a freshly-written 2.8MB file); the two repeat runs against the same file
(1.46s, 1.48s) are the representative, reproducible cost.

Current real production scale is 27 rows across the same 5 classes
(Define-phase finding) — none of these three tested scales (3.7x, 37x,
370x current scale) come close to the Define-phase concern threshold of
30,000–50,000 rows, where a single call was measured at ~4–17s.

## Recommendation

**Fine as-is up to at least 10,000 total K-graph rows** (real predicate
shape, not the thinner 2-predicate synthetic shape Define used at that same
row count — this run is the more faithful, harder measurement and it still
lands at ~1.5s median, comfortably inside the "a few seconds fine" bar for
a single Analyze call, and under ~3s for the full before/Act/after loop's
two calls combined).

No code change is warranted at this scale. The Define-phase recommendation
stands unchanged by this data: revisit the subprocess-per-call
`python3`+`rdflib` pattern in `sparql_count_by_class/0` — moving to a
long-lived process or an in-process query engine — only if/when the real
K-graph approaches the 30,000–50,000-row concern zone Define measured
directly (where a single call crosses from ~4s to ~17s and the two-call
loop crosses into "tens of seconds"). At 10,000 rows the two dominant real
costs (fixed python3/rdflib-import subprocess tax, and rdflib's
in-memory-store aggregate-query cost) are both still small relative to that
zone.

## See Also

- `lib/mix/tasks/xaas.close_coverage_gap.ex` — the real production code
  measured (`sparql_count_by_class/0`, lines 132–183)
- `lib/xaas/sparql_bridge.ex` — the real Turtle shape this benchmark's
  generator reproduces (`render_individual/2` and the five
  `*_to_turtle/1` clauses)
