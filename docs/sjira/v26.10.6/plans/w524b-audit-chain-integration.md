# W524b — Audit Chain Integration (Theorem 4.1 vs the Real Actuation Receipt Stream)

Lane W524b, EU-AI-Act wave. Contract: no lib edits; integration witnessed via the EXISTING
receipt stream.

## Mapping (real receipt → chain entry)

Real subject: `%Xaas.Operations.ActuationReceipt{}` emitted by `Xaas.Actuation.run/4`
(`:actuate_status` on `Xaas.Marketplace.Provider`; mirror of
`test/xaas/actuation_test.exs` setup: sandboxed Postgres, `authority: %{kind:
"test_authority", source: "w524b_audit_chain"}`, unique idempotency key per run).

| chain entry field | real receipt source |
|---|---|
| `actuation_id` | `receipt.id` (sealed receipt UUID) |
| `payload_digest` | `SHA-256(JCS(canonical_payload(receipt)))` — canonical form is the string-keyed map `{id, intent_id, attempt, status, resource_module, action, subject_id, ontology_projection_hash, input_hash, result_hash, replay_token, started_at, completed_at}` (atoms→strings, datetimes→ISO-8601), RFC 8785 via the `Jcs` dependency already used by `AuditChain.hash_receipt/2` |
| `sig_slot` | `receipt.replay_token` (nil on first attempts) |
| `t`, `prev_hash` | assigned by `AuditChain.append/2` |

## Test

`test/xaas/witness/audit_chain_actuation_integration_test.exs` — 4 Chicago tests, real
`Xaas.Actuation.run/4`, no mocks:

1. **chain of 2 real receipts verifies :ok** — two real actuations (new keys), appended,
   `verify_chain/2 == :ok` (also with `expected_length: 2`); head reproducible; digests
   deterministic and distinct.
2. **tamper detection with exact attribution** — forge the first captured receipt's payload
   in-memory (flip `result_hash`, recompute digest, splice): `{:error, {:tampered, 0}}`
   (0-based indexing; successor-consistency per Definition 4.2 docstring — a content tamper
   of receipt k breaks the (k, k+1) link); malformed digest on receipt 1 →
   `{:error, {:tampered, 1}}`. NOTE: the task contract's `{:tampered, 1}` for a
   first-receipt tamper is 1-indexed; the landed module (W503) attributes 0-based, so the
   test asserts the module's real semantics and this doc discloses the discrepancy.
3. **martingale monotone on real receipts** — `[1, 1]` untampered; `[0, 0]` after first-link
   tamper; property sweep over every tamper position: M_t never increases.
4. **replay does not grow the chain** — same idempotency key → same receipt id, byte-identical
   digest, no new persisted receipt row; `AuditChain.append/2` is append-only by design, so
   dedup belongs to the stream layer (asserted by receipt identity, not faked).

## Command + result

```
MIX_BUILD_ROOT=_build-laneW524b MIX_ENV=test PATH=$HOME/.asdf/shims:$PATH \
  mix test test/xaas/witness/audit_chain_actuation_integration_test.exs
```

Result: 4/4 passed, 0 warnings (final run — see receipt below).

## Standing

ALIVE for the exact subject: two real actuations' sealed receipts feed `Xaas.Witness.AuditChain`,
links verify, tamper detected with exact attribution, martingale monotone. Falsifier was: a
real receipt's digest failing verification, or M_t increasing — neither observed.
