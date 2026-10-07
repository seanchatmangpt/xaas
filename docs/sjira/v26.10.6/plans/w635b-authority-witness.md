# W635b — 73.6.s2 internal-escalation end-to-end witness — receipt

Lane W635, repo /Users/sac/xaas @ feat/playwright-surface, build root `_build-laneW635`.

## Chain diagram

```
EuAiActAdmission.admit(%{techniques: [:deceptive], ...})
  = {:error, :REFUSED_EUAIA_MANIPULATIVE}                    (real typed refusal, Art 5(1)(a))
    -> refused-receipt record %{digest, refusal_atom, status: :refused, observed_at}
      -> IncidentReport.build([receipt])
         = {:ok, %{incident_id: "INC-...", classification: [:INFRINGES_UNION_LAW],
                   originating_receipt_digests, temporal}}
        -> AuthorityChannel.transmit({:ok, report}, :internal_escalation_receipt_corpus)
           = {:ok, %{status: :RECORDED, channel_id, incident_id, classification, where}}
          -> AuditChain.append([], %{actuation_id: incident_id, payload_digest}) -> head
          -> AuditChain.append(chain, second link) -> head2
            -> verify_chain(chain, expected_length: 1, expected_head) = :ok
            -> verify_chain(chain2, expected_length: 2, expected_head2) = :ok
            -> martingale clean [1,1]; tamper link 0
               -> verify_chain = {:error, {:tampered, 0}} (exact attribution)
               -> martingale [0,0] (latch, monotone non-increasing)
```

## Falsifiers exercised

- Clean chain verifies with pinned length + head; head = `hash_receipt(r0, root)`.
- Content tamper at position 0 → `{:error, {:tampered, 0}}` exact attribution,
  martingale latches [0,0] (monotone non-increasing, Thm 4.1).
- Authority channel contrast: `art27_1f_fria_notification` stays
  `:PREPARED_NOT_TRANSMITTED` (typed OPEN; honest, never silently "sent")
  while internal channel records RECORDED.
- Typed refusals at channel boundary: `:REFUSED_UNKNOWN_CHANNEL`,
  `:REFUSED_NO_INCIDENT_EVIDENCE`.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW635 \
  mix test test/xaas/semantics/authority_channel_incident_witness_test.exs
  -> Result: 1 passed, 0 failed (exit 0)
```

Test-only change; strict compile unaffected. Two harness notes discovered
en route: `AuditChain` payload digests must be bare lowercase 64-hex
(`Base.encode16(..., case: :lower)`, regex `^[0-9a-f]{64}$`), and the
martingale per-link observable catches content tamper only through the
successor-link check (last-link content tamper needs `expected_head`) —
both are module-documented behavior, asserted as such in the test.

## Standing

ALIVE on exact subject (test file above, lane build root). Files touched:
- test/xaas/semantics/authority_channel_incident_witness_test.exs (new)
- docs/sjira/v26.10.6/plans/w635b-authority-witness.md (this receipt)
