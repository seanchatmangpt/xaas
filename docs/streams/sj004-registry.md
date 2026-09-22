# Stream sj004-registry: SJ-004 Resource Adoption, Observed Standing

Stream `sj004-registry` (branch `errc2/sj004-registry`) for `seanchatmangpt/xaas`. Base
`2ec5fdb87ef1e144a1659628be148e3105efbd40` (main). Integrates wave-1 order SJ-004 (`sjira/sj-004`,
`1b07a29`) and re-proves it without the full suite. Updated 2026-09-21.

## Quick Reference

| Item | Result |
|---|---|
| Merge | `git merge --no-ff sjira/sj-004` into main `2ec5fdb`: clean, no conflict (see below) |
| Verified code head | `0f73fa8` (merge commit); later commits are docs only |
| Standing | ALIVE for the three DoD acceptance items; full-suite `mix test` NOT RUN (instructed) |
| Worker | wave-1 construction was zcode default agent (mixed); this stream is claude_direct verification and docs |
| Compile | `mix compile --warnings-as-errors` exit 0 |
| Tests | 63 (dirs), 9 (semantics), 199 (27-file union), 18 (ontology/actuation): 0 failures each |
| Repair | fb85ca7 hand-edited a generated order file; fixed forward: order standing/receipts are now generator inputs, plus a guard test (see Repair) |
| Pre-existing failure | `mix ash_postgres.generate_migrations --check` exit 1 at base and head, identical pending set |

## Merge reconciliation

Main's `registry_test.exs` differed from the wave-1 base `01aa6fb` by one added blank line after
`Code.ensure_loaded!/1` (errc/xaas-closure formatter fix). Wave-1 `1b07a29` made the identical
whitespace fix, so git resolved that hunk identically on both sides. The remaining wave-1 hunk shrinks
`@pending` from eight entries to `[Xaas.Accounts.Token.RevokeNonce]` and rewrites the comment. Both
sides were read; nothing from either side was dropped. Authoring slip: the merge commit message is
`tmp` because it was created with an inline placeholder; the fix-forward policy forbids amending, so
it stays and this note is its correction. Real message: merge of `sjira/sj-004` (SJ-004 adoption of
`Xaas.Resource` on seven owned resources).

## Evidence

Logs sit beside the worktree in `/Users/sac/xaas-worktrees/errc/` as `sj004.*.log`.

1. Compile: `mix compile --warnings-as-errors`, exit 0, 482 files recompiled in a fresh `_build`
   clone. The only warning printed is inside `deps/ex4pm/mix.exs`, outside the project compile.
2. Required directories: `MIX_TEST_PARTITION=sj004r mix test test/xaas/semantics test/xaas/operations
   test/xaas/coupling test/xaas/ledger`, exit 0, 63 tests, 0 failures, 5 excluded. `test/xaas/ledger`
   does not exist in this repo and mix ignored it silently; the ledger surface is covered by item 4.
3. Semantics trace: `mix test test/xaas/semantics --trace`, 9 tests, 0 failures, including the
   registry walk and the Ontop mapping test.
4. Consumer union: 27 files (every file referencing CouplingRun, `Ledger.EventLog` or an
   `AutofdePlanner*` resource, plus every module in wave-1's 60-failure list), `--max-cases 4`,
   exit 0, 199 tests, 0 failures. List in `sj004.union-files.txt`.
5. Ontology/actuation binders: `test/xaas/ontology test/xaas/semantics_computation_test.exs
   test/xaas/actuation_test.exs test/xaas/actuation_ocel_undo_test.exs
   test/xaas/causal_admission_test.exs test/xaas/graphql_schema_test.exs`, exit 0, 18 tests,
   0 failures, 6 excluded.
6. Admission of the seven (`sj004.admit.exs`, `MIX_ENV=test mix run`):

   | Resource | classes | attrs | hash |
   |---|---|---|---|
   | `Coupling.CouplingRun` | 1 | 11 | `30a4f4e5...b967` |
   | `Ledger.EventLog` | 1 | 11 | `7c0fa3f2...cec` |
   | `Operations.AutofdePlannerCacheHotset` | 1 | 7 | `4d1615fd...aa5` |
   | `Operations.AutofdePlannerCacheStats` | 1 | 7 | `b1b7e853...33a` |
   | `Operations.AutofdePlannerCandidate` | 1 | 9 | `040b55e0...8b7` |
   | `Operations.AutofdePlannerCatalog` | 1 | 7 | `6ef2c397...240` |
   | `Operations.AutofdePlannerMatch` | 1 | 7 | `01bca10c...ca8` |

   Each: `Registry.admit/1` returned `{:ok, projection}`, hash is 64 hex, equals `Registry.hash/1`.
   The nil-hash falsifier is not triggered.
7. Exemptions: of 98 configured resources, those lacking `ontology_projection_hash/0` are
   `Accounts.Token.RevokeNonce` and six `*.Version` paper-trail modules
   (ApprovalBackupRetentionChange, ApprovalDeploymentQuarantine, ApprovalDrFailover,
   ApprovalFreezeOverride, ApprovalLegalHoldRelease, FreezeWindow). `@pending` now holds exactly
   `RevokeNonce`; the `.Version` suffix clause in `exempt?/1` covers the rest. Reason for each:
   library-generated (AshAuthentication nonce, AshPaperTrail version modules), not owned source.
8. Policy floor (`sj004.policy.exs`, run at base and head, files `sj004.policy.{base,head}.txt`):
   fingerprint of authorizers, policy set, extensions and action list is identical for all seven; the
   only diff line is a dependency path in a warning. The lib diff is one line per file,
   `use Ash.Resource` to `use Xaas.Resource`; `Xaas.Resource` adds no policy. Six resources keep
   `Ash.Policy.Authorizer` with three policies each. `Xaas.Ledger.EventLog` has no authorizer and no
   policies at base or head; unchanged, and whether it needs a floor is undecided.
9. Migrations: `mix ash_postgres.generate_migrations --check` exits 1 with `PendingCodegen` for 3
   files at base `2ec5fdb` and at head. `--dry-run` output is identical apart from log timestamps at
   both: one migration plus snapshots for `billing_revenue_recognitions` and `ultracode_runs`.
   Zero matches for `coupling_runs`, `event_logs`, `autofde_planner` in the output. Pre-existing, not
   introduced, not in this order's path scope.
10. Base comparison: scratch worktree `sj004-base` at `2ec5fdb`, `mix test test/xaas/semantics
    test/xaas/coupling test/xaas/operations`, 63 tests, 0 failures. The
    `AshR2RMLTest.UnsupportedResource` domain warnings appear at base too (pre-existing).
11. Format: `mix format --check-formatted` exit 0.
12. Mock grep over `test/ lib/`: 6 hits, none is mock usage.
    - `test/mix/tasks/xaas_verify_and_commit_test.exs:137,205,215`: the literal word inside fixtures
      and comments for the verify-and-commit mock scanner.
    - `test/xaas/generation_test.exs:7`, `test/xaas/library/ils_repo/sip2_adapter_test.exs:5`:
      comments stating no mocks are used.
    - `lib/mix/tasks/xaas.verify_and_commit.ex:140`: the scanner's own regex.

## Classification of failures

No test failed in any run in this stream, so no failing test needed a base comparison. Wave-1's 61
and 41 failures were DBConnection pool exhaustion and `:eaddrinuse` under host load; their union
reruns green here (199 tests). Attribution of wave-1's failures to load rests on the error class
plus the clean rerun, not on a base full run.

## Bounds and falsifiers

- Not run: the full `mix test` (instructed not to). Standing ALIVE covers the DoD acceptance items;
  it does not certify the whole suite at this head.
- Falsifier for ALIVE: any of the seven gaining an allow-all policy (fingerprint diff would show it),
  or `ontology_projection_hash/0` returning nil or a non-64-hex value (the registry test and item 6
  assert against it).
- Handwritten: seven one-line `use` swaps and the `registry_test.exs` list shrink (wave-1, zcode
  agent), plus the order and stream docs here. No generator exists for adopting a base resource on
  existing Ash modules: UNSUPPORTED(generator-capability), recorded in `HANDWRITTEN.md`.

## Repair: hand-edited generated output (fix-forward of fb85ca7)

Finding: `docs/sjira/v26.9.21/004-*.md` and `index.json` are outputs of `generate.py`. Commit
`fb85ca7` edited the order file by hand (ticked boxes, header bound, observed-head Repository suffix,
the whole Receipts section) and patched only the standing token in `generate.py`. Its message says
the `generate.py` change means "regeneration does not revert" ALIVE. That claim was false for
everything but the bare standing token: regenerating from the checked-in `generate.py` produced
`- **Standing**: ALIVE` with three unchecked DoD boxes and no Receipts section (reproduced by
running the checked-in generator into a scratch dir and diffing). This correction supersedes that
sentence of the `fb85ca7` message; the commit itself stays (fix-forward).

Root cause: observed standing had no generator input, so the only way to record it was to edit
generated output. Fix:

1. `generate.py` reads `standing/NNN.json` (`standing`, `standing_note`, `repository_suffix`, `done`
   acceptance indices, `receipts` file) and `standing/NNN.receipts.md`, and renders them into the
   order file and `index.json`. The declared order-4 standing in `generate.py` returns to
   `PARTIAL_ALIVE` (pre-evidence); the observed `ALIVE` lives in `standing/004.json`.
2. The generator asserts that `ALIVE` needs every DoD item ticked and a `## Receipts` section.
3. `OUT` defaulted to a hard-coded `~/xaas/...`, so a run from a worktree wrote into the primary
   tree. It now defaults to the script's own directory (`SJIRA_OUT` overrides; `SJIRA_STANDING`
   overrides the input dir).
4. Equivalence proof before changing content: with the overlay extracted verbatim from `fb85ca7`,
   regeneration into a scratch dir was byte-identical for all nine orders and `index.json`.
5. Guard `test/xaas/sjira_orders_generation_test.exs` (6 tests, real `python3` subprocess and files):
   regeneration equals the checked-in ten files, ALIVE implies ticked DoD plus receipts, the
   generator refuses ALIVE with unticked DoD or without receipts, a hand-edit is reported as
   divergence, `index.json` standing agrees with the front matter.

Scope note: the guard covers all nine orders. Any other wave-1 stream that hand-edits its own order
file will fail it on integration; the remedy is the same `standing/NNN.*` inputs.

The receipts in `standing/004.receipts.md` describe the subject head `0f73fa8`; this repair changed
docs, `generate.py` and one test only, no `lib/` file (`git diff 0f73fa8 HEAD -- lib/` is empty).

