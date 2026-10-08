# W650h18 — coverage burn-down continuation (census + court)

Lane: W650h18, repo /Users/sac/xaas, branch feat/playwright-surface @ 983ca0ae.
Env: PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW650h18.
Constraint honored: tests under test/xaas/ + this receipt only; no commit; no lib/ edits.

## Census (2 candidate families)

Method: for every `lib/xaas/**/*.ex` module, count test files referencing the
module's CamelCase name (`grep -rl <CamelCase> test/`), with each zero-hit
candidate re-verified by real grep and by reading the candidate plus its most
likely indirect-coverage test file (CamelCase census alone is unreliable:
acronym modules — SBBManifest, R2RML, SIP2Adapter — read as zero-hit under a
naive transform but are covered; noted as a census-method finding).

### Family A — Accounts remainder / Billing non-approval non-subscription

Zero-mention billing candidates (naive census) → verified dispositions:

| module | lines | verification | disposition |
|---|---|---|---|
| billing/validations/subscription_change_tier_not_no_op.ex | 29 | same-tier change_tier typed refusal with zero transfers: `test/xaas/billing/subscription_tier_proration_depth_w984dd_test.exs:135` | COVERED |
| billing/validations/approval_tier_downgrade_targets_lower_tier.ex | 55 | equal-tier and higher-tier downgrade creates both refused with real reloaded state assertion: `test/xaas/billing/approval_tier_downgrade_test.exs:116-146` | COVERED |
| billing/changes/subscription_charge_on_activate.ex | 124 | 3 test files reference; subscription tests + proration depth court | COVERED |
| billing/changes/subscription_prorate_tier_change.ex | 232 | 3 test files reference; w984dd proration depth court | COVERED |
| billing/revenue_recognition.ex | 175 | multitenancy + ReactorContext fence courted in billing_multitenancy_court + fibo actuation tests | COVERED |
| accounts/user/senders/*.ex | 3 files | thin I/O notification adapters (AshAuthentication sender behaviour); no real in-process state to court without a mailer double | DISPOSITION=thin (notification adapter; real-path covered by AshAuthentication lifecycle) |
| aws_repo_adapters/aws_adapter.ex | 118 | transport plumbing to 169.254.169.254 IMDS + ExAws; no in-process seam | DISPOSITION=thin (network-bound adapter, private parse) |

### Family B — fresh whole-lib census (excluding running lanes' families: governance/spg/sso)

Zero-mention (≥60 lines) candidates, each manually verified:

| module | lines | verification | disposition |
|---|---|---|---|
| semantics/r2rml.ex | 283 | courted by test/xaas/semantics/r2rml_refusal_test.exs (naive census false negative: module is R2RML) | COVERED |
| architecture/sbb_manifest.ex | 140 | test/xaas/architecture/sbb_manifest_test.exs (10 tests; census false negative: SBBManifest acronym) | COVERED |
| operations/project_measure/github_actions.ex | 151 | project_measure_github_actions_court_w984dp4_test.exs (W984dp4, done lane) | COVERED |
| ultracode/capital_census/self_digest_run.ex | 389 | test/xaas/ultracode/capital_census/self_digest_worker_test.exs runs real SelfDigest.Run.digest/1 | COVERED |
| library/ils_repo/sip2_adapter.ex | 300 | SIP2Adapter referenced by 2 test files (acronym census false negative) | COVERED |
| ocel/changes/relate_event_to_objects.ex | 70 | all 3 branches courted in test/xaas/ocel/object_centric_event_projection_test.exs:43-119 | COVERED |
| library/changes/write_actor_resolution_audit.ex | 63 | allowed + denied audit rows asserted in test/xaas_web/a2a/next_read_user_agent_test.exs:145-190 | COVERED |
| operations/validations/capability_liveness_receipt_status_gate.ex | 61 | both typed refusals courted in test/xaas/operations/capability_liveness_deepening_test.exs:87-107 | COVERED |
| platform/validations/route_projects_backups_retain_until_passed.ex | 73 | retain_until refuse/purge courted in platform_route_deepening_test.exs:324-411 | COVERED |
| platform/validations/route_orgs_custom_domain_active_requires_certificate_secret.ex | 62 | certificate_secret refuse/transition courted in platform_route_deepening_test.exs:260-292 | COVERED |
| prom_ex_plugins/cpu_plugin.ex | 63 | telemetry plugin, no in-process seam without a live collector | DISPOSITION=thin (metrics adapter) |

Family B court target: `lib/xaas/library/reactors/student_profile_sub_reactor.ex`
(61 lines, 0 direct mentions of StudentProfileSubReactor anywhere under test/,
0 indirect: no library reactor test runs it; nearest family tests
(test/xaas/library/reactors/*) court circulation_borrow, score_book_map,
recommendation_pipeline only.

Standing: PARTIAL_ALIVE (court green required to keep; see run section).

## Court

`test/xaas/library/reactors/student_profile_sub_reactor_test.exs` — 5 tests,
real `Reactor.run/2` over real checkout maps and real deterministic
`Xaas.Library.Embeddings.embed/1` (no DB, no mocks), typed invariants:

1. real 384-dim embedding + exact genre-frequency map (`flat_map` frequency
   kills map/1 mutants); mutation rationale in module docstring.
2. empty-history fallback text exactly drives the embedding (embedding ==
   embed("Grade 5 reading catalog")); kills `[] ->` clause-deletion mutants.
3. nil-book checkouts rejected, reactor survives; kills reject-clause removal.
4. determinism: identical inputs → identical embedding across two real runs.
5. nil genres nil-safety; kills `|| []` guard removal.

## Run

Fresh `_build-laneW650h18` (full dep compile). First run: 4/5 — test (3)
hypothesized nil-tolerance; real behavior is a typed failure
(`Reactor.Error.Invalid` wrapping `%BadMapError{term: nil}` from
`Enum.map(& &1.book)` running before the is_nil reject). Court repaired to
assert the real invariant (typed refusal), not the hypothesized one.

Final:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h18 \
  mix test test/xaas/library/reactors/student_profile_sub_reactor_test.exs
→ 5 passed, 0 failed (0.1s)  [exit 0]
```

Anti-vacuity note: no lib/ mutation run (lane forbidden from lib/ edits); the
non-vacuity evidence is structural — test 2 pins the exact fallback string
through the real embedding (`embedding == embed("Grade 5 reading catalog")`)
and test 1 pins the exact frequency map, both of which fail under the
documented mutant classes.

## Standing

- `lib/xaas/library/reactors/student_profile_sub_reactor.ex`: courted,
  ALIVE (5/5 real runs on exact subject).
- Family A (Accounts/Billing non-approval non-subscription): DISPOSITION=
  COVERED/thin — no uncovered state-bearing module; top candidates covered
  by real-path tests (evidence in census tables).
- Build root: `_build-laneW650h18` deleted at integration (see Cleanup).

## Cleanup

- [x] tests only under test/xaas/ + this receipt (no lib/ edits, no commit)
- [x] `rm -rf /Users/sac/xaas/_build-laneW650h18` — deleted (verified absent)
