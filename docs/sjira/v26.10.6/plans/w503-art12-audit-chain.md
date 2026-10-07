# W503 — Art.12 Audit Chain (Def 4.2 + Thm 4.1)

Lane: W503, EU-AI-Act wave, repo /Users/sac/xaas @ feat/playwright-surface,
build root `_build-laneW503`.

## Scope (contract)

Only: `lib/xaas/witness/audit_chain.ex`, `test/xaas/witness/audit_chain_test.exs`,
this plan doc.

## Design

- **Pure module** over a list of `%Xaas.Witness.AuditChain{}` receipts
  (Chicago: real data, no GenServer process needed).
- **Def 4.2**: `R_t = {t, actuation_id, payload_digest, prev_hash, sig_slot}`;
  `H_t = SHA256(JCS(R_t) <> H_{t-1})`; `H_0 = 64 hex zeros`.
- **Honest crypto (w405)**: SHA-256 over JCS canonical JSON via the existing
  `Jcs` dependency — the same one used by
  `Xaas.Deployment.ReleaseSnapshot.portable_digest/1`
  (lib/xaas/deployment/release_snapshot.ex:356). No extraction needed;
  `Jcs.encode/1` was already a direct dependency. **BLAKE3 is not present in
  lib/ and is NOT added** — documented as upgrade path only.
- **Signature slot**: `sig` field holds an optional `(receipt -> boolean)`
  verify callback; `nil` (default) means **unsigned mode** — documented,
  not faked. ML-DSA wiring is W510's lane.
- **verify_chain/1**: recomputes every link from `H_0`; first mismatch →
  `{:error, {:tampered, t}}`; `:expected_length` opt →
  `{:error, {:truncated, n}}`; rejecting `sig` → `{:error, :invalid_signature}`.
- **martingale/1**: M_t = 1 until the first invalid link, 0 thereafter —
  the Thm 4.1 observable, asserted monotone non-increasing over the stream.

## Falsifiers (all executed, mix test)

1. append 25 → verify_chain :ok
2. tamper payload at k=4 → `{:error, {:tampered, 4}}` exactly
3. tamper prev_hash at k → tampered at k
4. truncation detected with `expected_length`; valid prefix still :ok without hint
5. determinism: same receipts → same hash sequences
6. property: M_t monotone non-increasing over n∈1..30 × tamper k∈0..n-1
7. property: untampered chain M_t all ones (non-vacuous base)

## Receipt

- Honest-crypto: SHA-256/JCS now; BLAKE3 = upgrade path (no NIF added).
- Module strict-compiles clean: `elixirc` exit 0, zero warnings
  (against `_build-laneW503/test/lib/jcs/ebin`).
- Tests: 17/17 passed via real ExUnit run
  (`elixir -pa <jcs ebin> -pa <module ebin> -e 'ExUnit...; ExUnit.run()'`),
  "Result: 17 passed", 3.8s async.
- BLOCKED (cross-lane, not this lane's files): full-app `mix test` through
  `_build-laneW503` currently fails compiling OTHER lanes' untracked
  in-flight files — observed `lib/xaas/actuation/quiescent_stop.ex`
  (pin-operator error), then `lib/xaas/semantics/counterfactual.ex`
  (missing terminator). Both `??` untracked, both outside the W503 write
  contract; retry mix when those lanes land. Isolated execution above is
  the executed verification receipt for this lane.
- Verdict: PARTIAL_ALIVE — module ALIVE under isolated execution;
  whole-app mix gate blocked by sibling lanes' transient build break.
