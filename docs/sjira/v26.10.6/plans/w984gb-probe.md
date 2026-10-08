# W984gb — unclaimed-family probe: `lib/xaas/witness/`

Lane: W984gb · branch `feat/playwright-surface` · 2026-10-07 · no commit (coordinator owns transitions)

## Population

`lib/xaas/witness/` = 4 modules, 576 LOC:

- `audit_chain.ex` (202) — pure chain verify/martingale/hash
- `catalog.ex` (207) — ingest context over CertifiedReceipt + VerificationKey
- `certified_receipt.ex` (104) — Ash resource
- `verification_key.ex` (63) — Ash resource

## Per-module dispositions

| module | disposition |
|---|---|
| `AuditChain` | covered (verify_chain tamper/truncation/invalid_signature/head-tamper, martingale latch, `append` invalid-attrs, `hash_receipt` term encoding incl. tuple terms — via audit_chain_{test,invariant,property}, ml_dsa_signed_receipt, eu_ai_act deepening suites) **except** the `sig_rejects?/1` fallback clause `defp sig_rejects?(_), do: false` — uncovered, courted in family_court_w984gb_test.exs |
| `CertifiedReceipt` | covered — ingest/create, read, `:record_verification` write-once refusal, action-surface immutability (`catalog_test`, `w984cm` lifecycle, `ml_dsa_signed_receipt`, `catalog_durability`, `witness_surface_deepening`) |
| `VerificationKey` | covered — register, created_at stamping, duplicate-kid identity refusal (`catalog_test`, `witness_surface_deepening:139`) |
| `Catalog` | covered (map+path baseline modes, skipped-vector reporting, idempotent re-ingest, list_by_algorithm, record_verification) **except** the `raise ArgumentError, "baseline is missing subject_commit"` boundary — uncovered, courted; and internal fault refusals `{:ingest_refused,_,_}` / `{:key_registration_refused,_,_}` — uncovered but unreachable without fault injection: every in-process create-failure route (duplicate subject+payload, duplicate kid) resolves to the idempotent branch, and remaining failure modes are environmental (DB down / races). Not courted — mocks banned. |

## Courted (test/xaas/witness/family_court_w984gb_test.exs, 3 tests)

1. `Catalog.ingest/1` raises `ArgumentError ~r/missing subject_commit/` — map mode.
2. Same raise — path mode (lazy `fetch_baseline/1` decode).
3. `AuditChain.verify_chain/2` + `martingale/1` treat a malformed sig (`:corrupted_sig_slot`) as documented unsigned mode via the `sig_rejects?/1` fallback clause.

Each test carries a per-test mutation rationale; real Postgres sandbox, real KAT fixture, zero mocks.

## Gates (actual output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gb \
  mix test test/xaas/witness/family_court_w984gb_test.exs
  -> Result: 3 passed, exit 0
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'
  -> [], exit 0
```

## Files touched

- `test/xaas/witness/family_court_w984gb_test.exs` (new)
- `docs/sjira/v26.10.6/plans/w984gb-probe.md` (this receipt)
- Did NOT touch `test/xaas/witness/catalog_durability_test.exs` (W984ep in-flight, verified still-modified in git status).

Standing: ALIVE for the three courted branches; typed COVERED for the rest of the family; typed UNSUPPORTED(no-fault-injection) for the two Catalog internal refusals.
