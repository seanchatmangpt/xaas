# W771 — EU AI Act export endpoint deepening (OS-14, lane W771)

- **Subject**: /Users/sac/xaas @ `feat/playwright-surface`, HEAD `a0723bf6` (canonical checkout, uncommitted lane work; coordinator owns commits)
- **Wave**: v26.10.6 deepening lane, backlog OS-14 export endpoint (W620 landing, W712 contract, W723 token matrix)

## What landed

`test/xaas_web/eu_ai_act_export_deepening_test.exs` (new, 10 tests, real ConnCase
HTTP over the real `XaasWeb.EuAiActExportController` + real
`Mix.Tasks.Xaas.EuAiActPack.build/1` reading the real on-disk evidence tree;
no mocks):

- **(a) happy-path shape**: real 200 body top-level keys pinned to exactly
  TSV columns generated_at, subject, source_map, articles, refusal_corpus, typed_gaps;
  every section's representative pinned against the real `build/1` output
  (articles keyset equality + `art5` entry; `subject.head_sha` == real
  `git rev-parse HEAD`; `source_map.path`; refusal_corpus PRESENT/ABSENT shape
  with counts/subject when PRESENT; typed_gaps lines all matching the real
  `GAP(` / `OS-1[4-9]` extraction filter). Not a snapshot file.
- **(b) fail-closed 503 (W712 contract)**: cwd pointed at an empty temp dir
  (per-process `File.cd!` + ConnCase same-process dispatch = the controller
  genuinely reads the empty root) -> exact 503 body
  `{"schema": "xaas.eu_ai_act_pack_refusal/v1", "refused": inspect({:REFUSED_COVERAGE_MAP_MISSING, "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"})}`.
- **(c) token floor (W723 matrix over this route)**: wrong bearer -> 401 exact
  `{"error": "unauthorized", "detail": "missing or invalid Bearer token"}`;
  no bearer + env set -> 401 exact; unset env + no bearer -> 503 exact
  `{"error": "internal_api_misconfigured", "detail": "INTERNAL_API_TOKEN is not set on the server"}`;
  unset env + wrong bearer -> still 503 (fail-closed wins). Real env
  swap with restore in `after`/`on_exit`.
- **(d) determinism x2**: pinned `now` -> two `build/1` calls encode
  byte-identical (`Jason.encode!` equality); two live GETs identical modulo
  `generated_at` (which provably differs).
- **(e) headers**: 200 and 503 responses both `content-type:
  application/json; charset=utf-8`, `conn.state == :sent` (real plug_send).

## Verification (real run, this lane's build root)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW771 \
  mix test test/xaas_web/eu_ai_act_export_deepening_test.exs
..........
Finished in 0.7 seconds (0.00s async, 0.7s sync)
Result: 10 passed
```

First run was 9/10: my own post-restore `assert {:refused, ...} = build()`
(after cwd restoration) was wrong — build correctly returned `{:ok, pack}`;
removed, fail-closed is pinned by the in-root 503. Not a product defect.

## Standing

- **Standing: ALIVE** for the deepened surface — observed real HTTP execution
  through the real token floor + real fail-closed pack build at HEAD a0723bf6,
  10/10 passing.
- Falsifiers held: a pack-shape drift or keyset change, a refusal-body change,
  a token-floor matrix change, or nondeterminism would fail this file.

## Typed gaps / notes

- GAP(RETENTION): the endpoint still generates on request; persistence of the
  pack artifact remains open (disclosed in the controller moduledoc; unchanged
  by this lane — test-only lane).
- Per-process `File.cd!` relies on BEAM per-process cwd + same-process
  ConnCase dispatch; safe under `async: false` (ConnCase default here); an
  `async: true` move of this file would need re-review of that idiom.
- No git state commands run; no commit (coordinator owns transitions).
- Lane build root `_build-laneW771` left intact for the coordinator
  (deletion command was permission-denied in this lane; per dispatch contract
  either outcome is lawful — coordinator deletes at integration).
