# W650y — Coverage burn-down probe (Billing FIBO admission boundary)

Lane: W650y, xaas v26.10.6 campaign, 2026-10-07.
Subject: branch `feat/playwright-surface`, working tree (uncommitted test file only).
Scope honored: tests under `test/xaas/` only + this receipt; no commit.

## Census (fresh, CamelCase-aware, 2 candidate families)

Grep over `test/` for CamelCase module references per candidate module:

**Billing family** (`lib/xaas/billing/**`):
- subscription/prorate/charge-on-activate → taken by W984dd
  (`subscription_tier_proration_depth_w984dd_test.exs`); no ChargeSchedule module
  exists (grep: zero hits).
- approval_* resources → covered (controller tests + `approval_lifecycle_deepening_court_test.exs`,
  `atomic_retrofit_court_test.exs`, `billing_multitenancy_court_test.exs`).
- `revenue.ex` / `revenue_recognition.ex` → covered (`fibo_revenue_actuation_test.exs`).
- **`Xaas.Billing.FiboRevenueProfile` (284 lines) — THIN.** Existing court
  (`fibo_revenue_actuation_test.exs`, 6 tests) covers only happy paths: named-profile
  breadth, one generic-FIBO map admission, revision mismatch, non-FIBO IRI, one
  non-revenue binary. Uncourted: all map-form requiredness refusals
  (`:source_label_required`, `:source_family_required`, missing-IRI
  `{:non_fibo_revenue_source, nil}`, map-form non-revenue keys), atom/other dispatch
  (`admit_source/1` on atom, integer, nil, list), `fibo_iri?/1`/`non_revenue?/1`
  totality, and named↔non-revenue disjointness. → **Courted here.**

**Platform family** (`lib/xaas/platform/**`): every module referenced by tests —
route_projects/route_secrets/route_feature_flags/route_orgs_custom_domain (controller
tests + `platform_route_deepening_test.exs` 9-section court), backups (4a–4c incl.
retention sweep), custom domains (3a–3c + W984bq test 5), webhooks (W984bq tests 1–4,
deliver/lifecycle/stress tests), platform checks/changes (approve maker-checker 6a–6d).
No state-bearing uncovered module found. → **Disposition: COVERED (typed). No
platform work in this lane; remaining surface is webhook delivery internals already
court-owned by W984dc.**

## Court

File: `test/xaas/billing/fibo_profile_admission_boundary_w650y_test.exs` — 7 tests
(5 planned invariants + dispatch split into 3 describe-grouped string/atom tests),
all asserting real module output, zero mocks, typed refusals asserted as-real:

1. Named binary admission pins exact family/label and `generic?: false` (kills
   family/label tuple corruption and `generic?` flag drop).
2. Unknown binary → `{:unknown_revenue_source, _}`; full non-revenue set refuses
   through the binary form; non-revenue arm outranks named arm (kills cond-arm
   reordering that would admit principal flows as revenue).
3. Atom form delegates to binary; integer/list → `{:invalid_revenue_source, _}`;
   **discovered and pinned as-observed**: `admit_source(nil)` returns
   `{:error, {:unknown_revenue_source, "nil"}}` (nil is an atom → stringified) —
   typed refusal, never a raise.
4. Map-form requiredness: empty/missing label → `:source_label_required`; empty
   family → `:source_family_required`; missing IRI → `{:non_fibo_revenue_source, nil}`;
   wrong revision → `{:unadmitted_fibo_revision, "1999", pinned}`.
5. Map-form defaults + string-keyed maps + map-form non-revenue keys refuse (kills
   the debt-proceeds-in-a-map bypass of the binary-form refusal).
6. Closed-world consistency: named keys and non-revenue set are disjoint and
   deterministically sorted; every named source admits with `generic?: false`,
   pinned revision, cash-flow anchor IRI (kills split-brain edits adding a key to
   both maps).
7. `fibo_iri?/1` and `non_revenue?/1` totality on non-binary input (kills catch-all
   clause removal → FunctionClauseError crash instead of typed refusal).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650y \
  mix test test/xaas/billing/fibo_profile_admission_boundary_w650y_test.exs
→ 7 passed, 0 failures (exit 0)
```

First run: 6/7 (my expectation for `admit_source(nil)` contradicted real behavior —
nil routes through the atom clause; test corrected to the observed typed refusal,
rerun green).

## Receipt

- Subject: `test/xaas/billing/fibo_profile_admission_boundary_w650y_test.exs` (new,
  uncommitted) + `docs/sjira/v26.10.6/plans/w650y-probe.md`.
- Standing: **PARTIAL_ALIVE** — FiboRevenueProfile admission boundary now courted
  green on this subject; uncommitted per lane scope. Platform family typed COVERED.
- Falsifier: `mix test test/xaas/billing/fibo_profile_admission_boundary_w650y_test.exs`
  goes red on any mutation named above.
- Cleanup: `rm -rf _build-laneW650y` was permission-denied in this session —
  **left in place for the coordinator** to delete (lane instruction permits this).
