# W176 — Refusal-Coverage Delta Recount (vector-2 authoritative metric)

Date: 2026-10-06. Lane: W176 integration, v26.10.6 convergence.
Read-only on `lib/` and `test/`; only this receipt written. Repo: `/Users/sac/xaas`.

## Method (replay)

```bash
grep -rhoE "REFUSED_[A-Z0-9_]+" lib/ | sort -u > /tmp/refusals_lib.txt   # 62 tokens
grep -rhoE "REFUSED_[A-Z0-9_]+" test/ | sort -u > /tmp/refusals_test.txt # 49 tokens
comm -23 /tmp/refusals_lib.txt /tmp/refusals_test.txt > /tmp/refusals_delta.txt
wc -l < /tmp/refusals_delta.txt   # → 16
```

## Headline

**Baseline 50 → current delta 16** (lib total 62 distinct tokens, test total 49).
Token-level coverage: 46/62 = **74.2%**. The 34-token reduction versus the vector-2
baseline is real: the REFUSED_CASTLE_* negative-fixture family, the VKG refusals,
and 6 of the 9 w67-adjudicated REFUSED_XAAS_* tokens now have exact-token assertions
in the test tree (`castle_refusal_negative*.exs`, `semantics/vkg_refusal_negative_test.exs`).

## Per-item classification (all 16 delta tokens)

Every declaration site was located and read. **None are covered-by-behavior** under a
different token form (no test asserts any of these refusals via tuple element, struct
field, or paraphrase), and **none are structurally unreachable** (each branch is
reachable via a stale/tampered outer intent or receipt, a missing required field, or
a degenerate Ash resource). All 16 are **genuinely uncovered**: reachable negative
paths with no negative fixture.

### A. Castle outer-intent / outer-receipt verification gate — 13 tokens

`lib/xaas/castle.ex`, functions `verify_outer_intent/3` (360), `verify_outer_receipt/3`
(390), `verify_checkpoint_receipt/3` (415); reachable via `Xaas.Castle.witness/3`
(castle.ex:274,290-291) whenever the outer `RouteCastleRun` intent or receipt row is
stale or tampered. The only negative test touching this gate is
`REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED` (`castle_refusal_negative_batch2_test.exs:62`);
no test tampers the outer intent/receipt past the context check, so all 13 branch
atoms lack a fixture. Note: `_CLOSURE_PLAN.md:73` lists `REFUSED_XAAS_INTENT_NOT_EXECUTING`
among the 9 tokens "ADJUDICATED via w67 combined 44/44 run" — the token-level recount
refutes that for this token.

| token | declaration (lib/xaas/castle.ex) | classification |
|---|---|---|
| REFUSED_XAAS_INTENT_NOT_EXECUTING | 365 | genuinely uncovered |
| REFUSED_XAAS_RESOURCE_MISMATCH | 368 | genuinely uncovered |
| REFUSED_XAAS_ACTION_MISMATCH | 371 | genuinely uncovered |
| REFUSED_XAAS_SUBJECT_MISMATCH | 374 | genuinely uncovered |
| REFUSED_XAAS_PROJECTION_MISMATCH | 377 | genuinely uncovered |
| REFUSED_XAAS_PROJECTION_DRIFT | 380 | genuinely uncovered |
| REFUSED_XAAS_IDEMPOTENCY_MISMATCH | 383 | genuinely uncovered |
| REFUSED_XAAS_RECEIPT_INTENT_MISMATCH | 393 | genuinely uncovered |
| REFUSED_XAAS_RECEIPT_NOT_PREPARED | 396, 418 | genuinely uncovered |
| REFUSED_XAAS_RECEIPT_ACTION_MISMATCH | 399 | genuinely uncovered |
| REFUSED_XAAS_RECEIPT_PROJECTION_MISMATCH | 402, 421 | genuinely uncovered |
| REFUSED_XAAS_RECEIPT_INPUT_MISMATCH | 405 | genuinely uncovered |
| REFUSED_XAAS_RECEIPT_REPLAY_TOKEN | 408 | genuinely uncovered |

### B. Required-field gate — 1 token

`{:error, {:REFUSED_REQUIRED_FIELD, key}}` — `required_string/2` / `required_map/2`
at castle.ex:497-509 (`Xaas.Castle.Admission`) and duplicated at castle.ex:1031-1041
(`Xaas.Castle.Kernel.CLI`). Tuple form, key-parameterized; no test asserts the atom
in either form. Neighboring gates (digest, identity, evidence) all have batch
fixtures. Genuinely uncovered.

| token | declaration | classification |
|---|---|---|
| REFUSED_REQUIRED_FIELD | castle.ex:501, 506, 1040 | genuinely uncovered |

### C. R2RML projection refusals — 2 tokens

`lib/xaas/semantics/r2rml.ex`, emitted as `%AshR2RML.Refusal{code: ...}`:

| token | declaration | classification |
|---|---|---|
| REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY | r2rml.ex:185 (`subject_map/1`: resource with no Ash primary key) | genuinely uncovered |
| REFUSED_UNKNOWN_ATTRIBUTE | r2rml.ex:212 (`predicate_object_maps/2`: projection names an unknown Ash attribute) | genuinely uncovered |

`test/xaas/semantics/ash_r2rml_test.exs` covers only the happy path and
`UNSUPPORTED_ASH_TYPE`; neither refusal branch has a fixture.

## Final honest coverage

- Token-level (the DoD metric): **46/62 = 74.2%** covered, delta 16 (baseline 50).
- Adversarial-coverage caveat: this metric is token-presence, not fixture quality;
  the 16 uncovered tokens are exactly the deep defense-in-depth gate
  (outer-intent/receipt tamper paths), one tuple-form required-field gate, and two
  R2RML degenerate-resource branches. No item reclassified as covered-by-behavior
  or structurally-unreachable survived verification; the classification table above
  is the adjudicated result.

## W202 final recount

Date: 2026-10-06 13:56 PDT, repo /Users/sac/xaas, branch feat/playwright-surface.

Recount commands (lib/test refusal token delta vs W176 baseline of 16):
`grep -rhoE "REFUSED_[A-Z0-9_]+" lib/ | sort -u > /tmp/refusals_lib2.txt`
`grep -rhoE "REFUSED_[A-Z0-9_]+" test/ | sort -u > /tmp/refusals_test2.txt`
`comm -23 /tmp/refusals_lib2.txt /tmp/refusals_test2.txt > /tmp/refusals_delta2.txt`

Result: `wc -l < /tmp/refusals_delta2.txt` = **0**. Every REFUSED_* token in lib/
is now covered by a test-side occurrence; zero residual tokens with declaration
sites. Delta 16 -> 0 since W176.

W185's files on disk: test/xaas/castle_refusal_negative_batch6_test.exs
(13313 B, mtime 13:56), test/xaas/semantics/r2rml_refusal_test.exs (2155 B,
mtime 13:54).

Test run (PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test
test/xaas/castle_refusal_negative_batch6_test.exs
test/xaas/semantics/r2rml_refusal_test.exs): 17/20 passed, 3 failed.

Residual failures (disclosed, not fixed — read-only lane):
1. test/xaas/semantics/r2rml_refusal_test.exs:54 — match (=) failed; audit
   refused list shape vs expected
   [%{resource: NoPkResource, reason: %Refusal{code: :REFUSED_NON_UNIQUE_SEMANTIC_IDENTITY}}].
2. test/xaas/castle_refusal_negative_batch6_test.exs:306 — match (=) failed;
   expected {:error, {:REFUSED_REQUIRED_FIELD, :subject}} from witness_call,
   left equals right textually per output (likely struct-vs-map or nested
   shape mismatch in actual return).
3. test/xaas/castle_refusal_negative_batch6_test.exs:224 — Postgrex.Error
   23503 foreign_key_violation on actuation_receipts.intent_id (FK
   actuation_receipts_intent_id_fkey) during receipt insert.

Standing: refusal-token delta recount ALIVE (0 residual); new-batch test suite
BUILD_PARTIAL (17/20). No fixes applied.

## W235 combined

Post-W208 verification, v26.10.6 integration lane W235: original ash_r2rml test
alongside the W208 refusal test, single combined run.

Command:
`cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test
test/xaas/semantics/ash_r2rml_test.exs test/xaas/semantics/r2rml_refusal_test.exs
2>&1 | tail -5`

Result (real output, tail):
```
Finished in 0.9 seconds (0.9s async, 0.00s sync)

Result: 9 passed
```
(the 9 = 7 from ash_r2rml_test.exs + 2 from r2rml_refusal_test.exs; per-file
runs confirm: `Result: 7 passed` and `Result: 2 passed`). All green.

Module collision check: none. ash_r2rml_test.exs defines
`Xaas.Semantics.AshR2RMLTest.GoodResource` (plus `.UnsupportedResource`);
r2rml_refusal_test.exs (W208) defines `Xaas.Semantics.R2RMLRefusalTest.NoPkResource`
and `Xaas.Semantics.R2RMLRefusalTest.PkResource` — disjoint namespaces, no
overlap with GoodResource. No redefinition warnings for these modules in the run
(only pre-existing Inspect-consolidation warnings for the AshR2RMLTest resources).

Standing: original + refusal surfaces coexist ALIVE (9/9 combined). No fixes,
no git. Pre-existing W185-era batch6 failures elsewhere in this file's history
are unrelated to these two files and unchanged.

## W232 combined battery

2026-10-06, lane W232, v26.10.6 convergence, repo /Users/sac/xaas, branch
feat/playwright-surface. Final combined court: all 6 castle refusal batches run
together in one `mix test` invocation (MIX_ENV=test, asdf shims, pinned
toolchain):

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/castle_refusal_negative_test.exs \
  test/xaas/castle_refusal_negative_batch2_test.exs \
  test/xaas/castle_refusal_negative_batch3_test.exs \
  test/xaas/castle_refusal_negative_batch4_test.exs \
  test/xaas/castle_refusal_negative_batch5_test.exs \
  test/xaas/castle_refusal_negative_batch6_test.exs
```

Real combined output (tail):

```
Finished in 7.5 seconds (0.00s async, 7.5s sync)

Result: 62 passed
```

Per-file split (separate runs, sum = 62):

| file | result |
|---|---|
| castle_refusal_negative_test.exs | 19 passed |
| castle_refusal_negative_batch2_test.exs | 12 passed |
| castle_refusal_negative_batch3_test.exs | 7 passed |
| castle_refusal_negative_batch4_test.exs | 3 passed |
| castle_refusal_negative_batch5_test.exs | 3 passed |
| castle_refusal_negative_batch6_test.exs | 18 passed |

All green, 0 failures, 0 skipped. No separate required-field test file exists in
test/xaas/ (ls grep required = empty); required-field coverage is inside the six
batches as dispatched. Note: observed total is 62, not the 64 nominal from the
dispatch note (W67 44/0 + W208 20/20); the combined court above is the real
observed count on this exact subject. No fixes, no git.
