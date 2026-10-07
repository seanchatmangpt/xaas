# W984cm — Witness-family depth court (MINUS covered slices)

Lane: W984cm · xaas v26.10.6 · 2026-10-07 · branch `feat/playwright-surface`

## Subject

- Test file (new, only code touched):
  `/Users/sac/xaas/test/xaas/witness/w984cm_certified_receipt_lifecycle_test.exs`
  — 5 tests, module `Xaas.Witness.W984cmCertifiedReceiptLifecycleTest`.
- Receipt: `/Users/sac/xaas/docs/sjira/v26.10.6/plans/w984cm-witness-depth.md`.
- No lib/ changes. Nothing committed (per lane contract).

## Coverage scope read fresh

Read fresh: `lib/xaas/witness/{certified_receipt,verification_key,catalog,audit_chain}.ex`,
`test/xaas/witness/{catalog_test,catalog_durability_test,witness_surface_deepening_test,
ml_dsa_signed_receipt_test,audit_chain*}.exs`. Per task: audit_chain is covered by existing
courts + W984bn's 11 tests; certified_receipt graphql wiring is historical. Verified via
grep that `ingest_refused`/`key_registration_refused` tuples, the algorithm `one_of` enum
refusal, cross-baseline key idempotency, verdict polarity, and verified_at authority had
zero prior court coverage.

## The 5 courts (mutation rationale per test)

1. **Subject-collision semantics** — the `unique_subject_payload` identity is COMPOSITE;
   a same-subject/different-payload re-ingest is ADMITTED as a second row, while a
   full-pair re-ingest stays idempotent (table stays at 2). Also pins that
   `Catalog.ingest` results list only that ingest's admissions, not prior rows.
   Falsifier: narrowing the identity to subject alone fails the row-count asserts.
   (First draft wrongly expected `{:ingest_refused, _, _}` here — the real run falsified
   my premise; the court records the actual admitted-pair semantics.)
2. **Verdict polarity + timestamp authority** — `record_verification(receipt, false)`
   still records `verified=true` (the action accepts `[]` and ignores the
   `verification_result` context), and the caller-supplied `at` is NEVER persisted:
   `verified_at` is action-minted, asserted `> before` with a forged 2000-01-01 attempt.
   Falsifier: a change reading the caller context's `verified_at` fails the
   `:gt` assert; both rows end write-once-locked.
3. **Algorithm `one_of` enum typed refusal on BOTH resources** — `:rsa2048` on
   `CertifiedReceipt.ingest` and `VerificationKey.register` each yields typed
   `%Ash.Error.Invalid{}` with `InvalidAttribute field: :algorithm`, and no row is
   written. Falsifier: dropping the constraint from either resource fails both asserts.
4. **Cross-baseline key idempotency + deterministic kid** — same key material under two
   distinct `subject_commit`s registers exactly ONE key row; both receipts share its
   material; `kid` re-derived independently as `"ed25519-" <> binary_part(sha256("ed25519:bb"),0,16)`.
   Falsifier: a salted/unstable kid makes the key row count 2.
5. **Mixed admitted/skipped surfaces** — exact typed skip tuples with ORIGINAL vector
   indices ({1, "DILITHIUM3", ...}, {3, "RSA-PSS-SHA256", ...}), receipts preserve
   ordering across skipped gaps, skipped vectors contribute no keys (3 keys for 5
   vectors). Falsifier: post-filter indexing makes the first skip index 0, failing the
   exact-tuple assert.

## Coverage evidence (grep, 2026-10-07, pre-write)

- `ingest_refused|key_registration_refused|rsa2048|one_of` across `test/xaas/witness/` +
  `test/xaas/ultracode/`: 0 prior assertions on these paths.
- `list_by_algorithm`, per-vector payload hash, idempotent re-ingest, write-once
  verification, missing-subject_commit raise, no update/destroy: all already covered
  (`catalog_test.exs`, `catalog_durability_test.exs`, `witness_surface_deepening_test.exs`)
  — excluded from this lane.

## Execution receipt (real commands, real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cm \
  mix test test/xaas/witness/w984cm_certified_receipt_lifecycle_test.exs
```

- Run 1 (fresh lane build root, first full compile): 4/5 — failure was the test's own
  wrong premise (`ingest_refused` unreachable via payload change); premise corrected to
  the actual composite-identity semantics.
- Run 2: 4/5 — brittle sorted-slice assert; replaced with a set-difference assert.
- Run 3: **5 passed, exit 0** (`/tmp/w984cm_run3.out`).
- Run 4 (×2 confirmation): **5 passed, exit 0** (`/tmp/w984cm_run4.out`).

Environment notes (shared-checkout interference, disclosed): two mid-run compile aborts
from OTHER lanes' in-flight edits (`lib/mix/tasks/xaas.release_audit.ex`,
`lib/xaas/actuation/quiescent_stop.ex`); resolved by backoff-and-retry per the
compile-freeze SLA, no shared files touched by this lane.

## Standing

- Test suite: **ALIVE** (5/5, two consecutive passing runs, exit 0, real Postgres
  sandbox, real Ash actions, no mocks).
- Lane build root: `_build-laneW984cm` deletion was DENIED by the permission system —
  left in place for the coordinator (426 MB), per the lane contract's fallback.
- Non-goal disclosed: `Catalog`'s `{:error, {:key_registration_refused, kid, error}}`
  branch remains uncourted — no public-API path reaches it (create is only refused when
  the kid already exists, which the `key_exists?` fallback absorbs); typed disposition:
  unreachable-by-construction rather than covered.
