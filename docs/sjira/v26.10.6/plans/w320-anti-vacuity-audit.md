# W320 — Anti-Vacuity Mutation Audit (spot-verify, 6 mutants)

Lane W320, v26.10.6 convergence campaign. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
ONE canonical checkout, no worktrees, no commit. Private build root: `/Users/sac/xaas/_build-laneW320`
(lease NOT deleted — `rm -rf` denied by permission system; coordinator must delete at integration
per the 2026-10-01 cleanup law).

## Method

Per mutant: one-line minimal edit → `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW320 mix test <single file>` → record pass/fail →
revert by re-applying the inverse edit (git checkout FORBIDDEN) → `git diff --stat` must
return to baseline.

Baseline (pre-session, NOT mine): `castle.ex | 16 +++++++-`, `actuation.ex | 8 ++++++-`;
`r2rml.ex`, `vkg.ex`, `require_internal_api_token.ex` pristine. Post-revert state verified
identical: castle 16+1−, actuation 8+1−, others zero-diff.

Green baselines on private root before mutation:
- `require_internal_api_token_test.exs` — 7 passed
- `r2rml_refusal_test.exs` + `vkg_refusal_negative_test.exs` + `actuation_refusal_negative_test.exs` — 10 passed
- `castle_refusal_negative_batch6_test.exs` — 18 passed

## Per-mutant receipt

| # | family | file:line mutated (original → mutant) | test file | result | revert-verified |
|---|---|---|---|---|---|
| 1 | castle intent-verification `verify_outer_intent/3` | `lib/xaas/castle.ex:372` `outer.ontology_projection_hash != context.projection_hash ->` → `false ->` | `test/xaas/castle_refusal_negative_batch6_test.exs` | **KILLED** — 17/18, failed test: `REFUSED_XAAS_PROJECTION_MISMATCH — caller context hash diverges from the outer row` (line 187), `assert {:error, :REFUSED_XAAS_PROJECTION_MISMATCH} =` match failed | yes (16+1− restored, mutant line count 0) |
| 2 | castle `required_string/2` (REQUIRED_FIELD) | `lib/xaas/castle.ex:499` `if is_binary(value) and value != "",` → `if true,` | `test/xaas/castle_refusal_negative_batch6_test.exs` | **KILLED** — 16/18, failed: `witness refuses {:REFUSED_REQUIRED_FIELD, :authority} for a blank authority` and `... :subject} when the intent omits subject` | yes (16+1− restored) |
| 3 | r2rml NON_UNIQUE_SEMANTIC_IDENTITY `subject_map/1` | `lib/xaas/semantics/r2rml.ex:182` `if primary_key == [] do` → `if false do` | `test/xaas/semantics/r2rml_refusal_test.exs` | **KILLED** — 0/2 passed; both tests failed (`a resource with no primary key refuses...` + audit-standing test) | yes (zero diff) |
| 4 | vkg EMPTY_CATALOG `observe_all/1` | `lib/xaas/semantics/vkg.ex:40` guard `ids when ids != [] <- AshR2RML.VKG.Catalog.ids(catalog)` → `ids <- ...` (empty-catalog branch at vkg.ex:52 unreachable) | `test/xaas/semantics/vkg_refusal_negative_test.exs` | **SURVIVED — anti-vacuity gap** — 3 passed, suite green with the law's branch unreachable | yes (zero diff) |
| 5 | actuation `external_admission_identity_mismatch` | `lib/xaas/actuation.ex:539` `intent.id != admission.intent.id or receipt.id != admission.receipt.id ->` → `false ->` | `test/xaas/actuation_refusal_negative_test.exs` | **SURVIVED — anti-vacuity gap** — 5 passed, suite green with the identity comparison disabled | yes (8+1− restored) |
| 6 | plug fail-closed 503 | `lib/xaas_web/plugs/require_internal_api_token.ex:96` `nil -> {:error, :misconfigured}` → `nil -> {:error, :unauthorized}` | `test/xaas_web/plugs/require_internal_api_token_test.exs` | **KILLED** — 6/7, failed test: `unset INTERNAL_API_TOKEN with no header fails closed with 503` (line 75) | yes (zero diff) |

## Result: 4/6 killed, 2 SURVIVED

### Gap 1 (mutant 4) — `:REFUSED_VKG_EMPTY_CATALOG` is a dead law

`lib/xaas/semantics/vkg.ex:40-53`: `Catalog.ids/1` returning `[]` can never reach the
`[] -> {:error, :REFUSED_VKG_EMPTY_CATALOG}` clause (line 52), because an empty sources/ dir is
refused earlier at the manifest/registry layer. The corpus has NO test that kills a weakening of
this branch — the only "EMPTY_CATALOG" test
(`test/xaas/semantics/vkg_refusal_negative_test.exs:78-101`) explicitly asserts the OPPOSITE
refusal (`%Refusal{code: :REFUSED_VKG_MANIFEST, subject: :sources}`) and its comment concedes the
branch is "defensive": with the guard dropped and the branch unreachable, the suite stayed 3/3 green.
Either the branch is deleted (with the law retired from the corpus claim) or a test must construct
a catalog that loads with zero contract ids — none exists today.

### Gap 2 (mutant 5) — `:external_admission_identity_mismatch` has no kill

`lib/xaas/actuation.ex:539-540`: disabling
`intent.id != admission.intent.id or receipt.id != admission.receipt.id` leaves
`test/xaas/actuation_refusal_negative_test.exs` fully green (5/5). Static cross-check: no test in
the corpus asserts `:external_admission_identity_mismatch` — the foreign-intent test (line 129) is
caught one clause earlier by `:external_receipt_intent_mismatch` (line 537), and the forged-projection
test (line 104) passes the identity clause unchanged. A mutant that lets a checkpoint run against a
foreign admission (mismatched intent+receipt pair bound into `admission`) is not killed by any test.

## Real command tails (mutant runs)

```
# M1 castle.ex:372 → false ->
Result: 17/18 passed / Failed: 1 test
  1) test REFUSED_XAAS_PROJECTION_MISMATCH — caller context hash diverges from the outer row
     code:  assert {:error, :REFUSED_XAAS_PROJECTION_MISMATCH} =   (match (=) failed)
# M2 castle.ex:499 → if true,
Result: 16/18 passed
  1) test witness refuses {:REFUSED_REQUIRED_FIELD, :authority} for a blank authority
  2) test witness refuses {:REFUSED_REQUIRED_FIELD, :subject} when the intent omits subject
# M3 r2rml.ex:182 → if false do
Result: 0/2 passed
  1) test a resource with no primary key refuses with REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY
  2) test the same refusal is visible through audit standing, isolated from admitted resources
# M4 vkg.ex:40 guard dropped
Result: 3 passed          <-- SURVIVED
# M5 actuation.ex:539 → false ->
Result: 5 passed          <-- SURVIVED
# M6 plug.ex:96 → :unauthorized
Result: 6/7 passed
  1) test unset INTERNAL_API_TOKEN with no header fails closed with 503
```

Standing: PARTIAL_ALIVE for the corpus claim — 86-test green does NOT imply anti-vacuity for all
laws; two laws (VKG EMPTY_CATALOG, actuation admission identity) are currently mutant-immune.
No mutant left in the tree. No commit made.
