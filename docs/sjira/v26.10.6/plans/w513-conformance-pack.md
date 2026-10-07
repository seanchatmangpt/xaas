# W513 — EU AI Act Conformance Pack (doc-level export, runtime export half of OS-14)

Lane W513, 2026-10-06. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Build root: `_build-laneW513` (deleted at integration per cleanup law).

## Task

Assemble the machine-readable EU AI Act conformance evidence bundle from REAL
on-disk evidence — the runtime/export half of OS-14 (`GAP(NO_RUNTIME_EXPORT_API)`
narrowing chain). Consumer-facing Art. 12(3)/Annex IV delivery surface.

## Delivered

- `lib/mix/tasks/xaas.eu_ai_act_pack.ex` — `mix xaas.eu_ai_act_pack --out <path>`:
  - one JSON pack: `{schema, generated_at (explicit field, so determinism is
    assertable), subject{branch, head_sha via git rev-parse}, articles{...},
    refusal_corpus, typed_gaps}`.
  - article keys: `art5`, `art9/10`, `art11/12`, `art13/14`, `art15`, `art50`,
    `art72/86`; each carries a verdict traced to the coverage-map rows
    (`docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md`) and an evidence array
    of receipt/artifact paths.
  - fail-closed generation: every cited path is `File.exists?`-verified at
    generation time; a missing path raises
    `REFUSED_EVIDENCE_PATH_MISSING` and nothing is written. Missing map →
    `REFUSED_COVERAGE_MAP_MISSING`; empty typed-gaps extraction →
    `REFUSED_EMPTY_TYPED_GAPS`.
  - refusal-corpus stats from `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`
    (counts/subject/notes) when present, else a typed `{status: ABSENT,
    expected_path}` marker — no fabricated numbers either way.
  - typed-gaps section: verbatim `GAP(...)`/`OS-14..19` lines extracted from the
    map at generation time. The pack never claims gaps closed.
- `test/mix/tasks/xaas_eu_ai_act_pack_test.exs` — generates to /tmp; asserts
  schema/subject/articles shape, real ledger stats (62/62), every cited evidence
  path exists on disk, typed-gaps present and non-empty, and determinism (two
  runs identical modulo `generated_at`, which is strictly increasing).
- Fail-closed contract tested directly against the real filesystem
  (`verify_paths!/1` public — no mocks).

## Status note (OS-14)

Doc-level export is now real and machine-generated: the conformance pack is
produced by `mix xaas.eu_ai_act_pack --out <path>` from live on-disk evidence,
fail-closed. The remaining OS-14 gap is unchanged in kind: there is still no
automated **runtime** export API (an HTTP/OTP surface inside the running
`Xaas` app) and no retention artifact — the pack is a generation-time CLI over
the repository tree, not a runtime surface. `GAP(NO_RUNTIME_EXPORT_API)` stands,
narrowed by this receipt to `GAP(NO_RUNTIME_EXPORT_API)` with the doc-level
export leg landed.

## Verification (receipt)

- `MIX_BUILD_ROOT=_build-laneW513 MIX_ENV=test mix compile --strict --force` → exit 0
  (pre-existing warnings only; no errors).
- `MIX_BUILD_ROOT=_build-laneW513 mix test test/mix/tasks/xaas_eu_ai_act_pack_test.exs` →
  `Result: 4 passed` (4/4, 0 failures).
- Sample generation observed: `wrote /Users/sac/.cache/tmp/eu_ai_act_pack_test_1.json
  (7 articles)`; verdict summary line emitted per run.

## Environment note (2026-10-06)

During this lane's run, an unrelated lane's in-progress untracked file
(`lib/xaas/semantics/counterfactual.ex`) transiently broke whole-lib compile;
the retest after that lane's write completed passed 4/4. Per-lane build root
`_build-laneW513` is a lease — deleted at integration by the coordinator.
