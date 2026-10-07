# W953 — Depth-Suite 9-Failure Adjudication (post sibling landing)

Standing: **ALIVE** — all 9 deterministic W929 failures adjudicated on the current
settled tree; final combined rerun of the 9's six files: **49 passed, 0 failed,
EXIT=0** on HEAD `fab56ae1` (dirty shared tree, sibling lanes landed; one
transient sibling syntax error in `capability_liveness_regressions.ex` settled
mid-lane, polled 340s).

## Exact subject

- Repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `fab56ae19051c6bc2b501e4a1d6c91312344e2c3`.
- Toolchain: asdf elixir 1.20.2-otp-28, MIX_ENV=test, `MIX_BUILD_ROOT=_build-laneW953`
  (rm denied in lane — left in place for coordinator cleanup).
- Logs: `/tmp/w953-combined.log` (interim 47/49), `/tmp/w953-final.log` (final 49/49).

## Adjudication table

| # | Test | Verdict | Root cause (evidence) |
|---|---|---|---|
| 1 | `AuthorityDecouplingTest` axiom A gate error-shape | **STALE-TEST-FIXED** (test-side, W953) | Real contract CHANGE, correctly landed: W773's seal-boundary normalization (`Xaas.Actuation.Kernel.seal/2`, `lib/xaas/actuation.ex:490`) seals DO-step failures as a real `:failed` receipt and surfaces `{:error, raw_reason}` instead of the old rollback-as-wrapped `{:reactor_failed, %Reactor.Error.Invalid{}}`. The DO step's `{:error, :subject_id_required}` (from `get_subject/5`, `lib/xaas/actuation.ex:833`) now flows through `seal/2` → `normalize_transaction_result({:ok, %{status: :failed, error: reason}})`. Test updated in `test/xaas/semantics/authority_decoupling_test.exs:176` with citation; the test's real invariant (outcome is a pure function of opts; DO failure is NOT the authority gate) is preserved — `refute gate_refused?` kept and passes. 8/8 green. |
| 2 | `AuditLogEntryTest` rollback | **ENVIRONMENTAL-FIXED** (purge; test logic sound) | Test adds a real `CHECK` constraint via DDL; 202 stray **committed** `audit_log_entries` rows (cross-lane sandbox escape into shared `xaas_test`) made `ADD CONSTRAINT ... CHECK (action = 'IMPOSSIBLE...')` fail validation on existing rows. After purge: 13/13-file's tests pass. W728's after_action/2 fix is sound; no code or test change. |
| 3 | `RecommendationPipelineReactorTest` 6-factor ranking | **ENVIRONMENTAL-FIXED** (purge) | 10 stray **committed** `library_books` rows — the exact `Xaas.DevSeeds` fixture titles (`The Hidden Orchard` … `Senior Year, Zero Gravity`), inserted 12:14 and again 14:31 by concurrent lanes' sandbox-escaped `dev_seeds_test`/DevSeeds.run — inflated the candidate pool to 10/limit. After purge: passes. Not W928 hygiene (test-only edits) nor W902 borrow cap (borrow-guard, not rank). |
| 4-6 | `AuditExportTokenControllerTest` 404 ×3 | **FIXED-BY-LANDED** (W935) | Routes exist on the CURRENT tree: resource-declared AshJsonApi routes in `lib/xaas/governance/audit_export_token.ex` (`json_api do routes base("/audit_export_tokens") … patch(:use/:revoke)`), served by `XaasWeb.ApiRouter` (Governance domain mounted). No controller file exists or is needed. The 404s were the mid-compile race W929 witnessed (`audit_export_token.ex:121` in-flight edit). Rerun: all pass. |
| 7-8 | `RankerTest` empty-catalog ×2 (incl. exclude_read) | **ENVIRONMENTAL-FIXED** (purge) | Same 10 DevSeeds stray books: 0-book and all-checked-out catalogs returned 10 recommendations. After purge: `[]` as asserted. exclude_read semantics are correct; the "cause" was neither W928 nor W902 — it was the W902-disclosed shared-DB stray-row class. |
| 9 | `NextReadDeepeningTest` (c) RecommendationLog | **ENVIRONMENTAL-FIXED** (purge) | Two-layer: (a) 10 stray books → `length(scored) == 10 vs 3`; (b) after (a) cleared, 202 stray committed `library_recommendation_logs` rows → `length(logs) == 1` failed. Both purged; passes. |

## Final combined rerun (all 9's six files)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW953 \
  INTERNAL_API_TOKEN=test-token mix test \
  test/xaas/semantics/authority_decoupling_test.exs \
  test/xaas/governance/audit_log_entry_test.exs \
  test/xaas/library/reactors/recommendation_pipeline_reactor_test.exs \
  test/xaas_web/controllers/audit_export_token_controller_test.exs \
  test/xaas/library/ranker_test.exs \
  test/xaas/library/nextread_deepening_test.exs
# EXIT=0 — Result: 49 passed, 0 failed
```

## Falsifier & residual risk

- Falsifier for the environmental class (shared `xaas_test` stray committed rows):
  a concurrent lane can re-seed DevSeeds fixtures mid-run (observed live at 14:31
  during this lane — purge→rerun raced a re-seed once). Full-suite depth rerun
  on a QUIESCENT tree is the only durable 0-failure proof; recommend the
  coordinator either serialize shared-DB-dependent suites or adopt per-lane test
  DBs (W902's disclosed suggestion).
- Failure (1) is the only durable tree change from this lane: one stale
  expectation in `authority_decoupling_test.exs` updated test-side with citation
  (no lib code touched). Note: `test/xaas/actuation_refusal_negative_test.exs:66`
  still pins the OLD wrapped shape for the same underlying contract change and
  is red for the same reason (outside the W929 9; flagged for the coordinator,
  not edited by this lane — out of scope).

## Standing

W953 adjudication: **ALIVE** — 9/9 resolved with real rerun evidence (final
49/49, EXIT=0). Depth-combine suite falsifier for full ALIVE (combined rerun,
0 failures on quiescent tree) remains coordinator-owned.
