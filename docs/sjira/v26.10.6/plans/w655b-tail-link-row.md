# W655b — Art 12 Tail-Link Row (counterfactual harness)

Lane: W655b, EU-AI-Act wave. Repo: `/Users/sac/xaas` @ `feat/playwright-surface`.
Scope honored: only `test/eu_ai_act/counterfactual_test.exs` (extended; W550/W624 rows intact) and this doc.

## Task

W551's M3 survivor claimed the Art 12 harness tampers link 2 of 4 only, so a
TAIL-link payload tamper verifies `:ok` — the per-link payload-digest
recomputation is never exercised by a successor. Add the tail-link row.

## Findings (from lib/xaas/witness/audit_chain.ex)

`verify_chain/2` has NO option that forces per-link payload-digest
recomputation against external payloads — `payload_digest` is just a 64-hex
field inside the receipt; only its FORMAT is checked
(`valid_payload_digest?/1`). Detection of content tamper is:

- non-tail link k: caught by successor linkage (`hd(rest).prev_hash != h`
  at audit_chain.ex:120) — this is what the existing link-2 row exercises.
- tail link, non-hex forged digest: caught by the format check (:114).
- tail link, VALID 64-hex substituted digest: NOT caught — no successor,
  format passes → `:ok`. This is the tail blind spot.
- mitigation: `expected_head` opt (:80, :96-101) — final recomputed hash
  mismatch yields `{:error, {:tampered, :head}}`.

## Row added

`"Art 12 tail link: do(tamper LAST link payload_digest) needs expected_head
— verify_chain/2 alone verifies :ok for a valid-format forged tail digest"`:

1. Build a 4-link chain, capturing the honest head from `append/2`.
2. Factual: verifies `:ok` with and without `expected_head`.
3. (a) Tail tamper with non-hex `"w655b-forged"` → `{:error, {:tampered, 3}}`
   (format check still catches).
4. (b) Tail tamper with a VALID 64-hex digest, `verify_chain/2` alone →
   `:ok` (typed finding: the tail blind spot, determinism ×2).
5. (b) Same tamper with `expected_head: honest_head` →
   `{:error, {:tampered, :head}}` (the exposed mechanism, determinism ×2).
6. No side effect: original chain still verifies.

## W551 M3 closure note

CONFIRMED, with precision: the blind spot is not "per-link recomputation is
never exercised" in general — it is that a tail link has no successor, so a
format-valid substituted digest on the last link is undetectable by
`verify_chain/2` without `expected_head`. The dissertation's per-link
recomputation claim has a tail blind spot; `expected_head` is the required
mitigation and is now asserted in the harness. No production code was
changed (contract scope); the API already exposes the correct mechanism.

## Verdict

See test run receipt in the lane report. Falsifier: run
`mix test test/eu_ai_act/counterfactual_test.exs` — the (b)-without-head
assertion `assert :ok = b1` documents the honest non-detection; if a future
`verify_chain/3` adds full recomputation, this row fails and must be updated.

## Verification tail (appended W777 anomaly fix, coordinator)

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW655b MIX_ENV=test \
  mix test test/eu_ai_act/counterfactual_test.exs
→ exit 0, 26 passed, 0 failed (29.2s)
```
All prior rows (W550/W624) intact and passing, including the new tail-link row.
