# W696 — Art 99/100 Enforcement Deepening Receipt

- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface
- **Lane**: W696 (v26.10.6 campaign)
- **New file**: `test/eu_ai_act/art99_enforcement_deepening_test.exs` (7 tests, `@moduletag :eu_ai_act`)
- **Receipt**: this file

## Scope

Art 99 (penalties) / Art 100 (corrective actions) lines lean on the
AuthorityChannel escalation chain without a dedicated enforcement-court
file. This lane adds one, Chicago-style (real collaborators, no mocks —
real `Xaas.Semantics.IncidentReport`, `Xaas.Semantics.AuthorityChannel`,
`Xaas.Witness.AuditChain` calls; zero mocks/stubs/patches).

## Coverage

1. **Escalation chain composition** (real calls end-to-end): refused
   receipts → `IncidentReport.build/1` (dual-class envelope:
   `[:INFRINGES_UNION_LAW, :MALFUNCTION]` from an EUAIA atom + a non-EUAIA
   refused receipt) → `AuthorityChannel.transmit/2` authority channel
   (`:PREPARED_NOT_TRANSMITTED`, endpoint `:OPEN`, typed reason) → internal
   escalation channel (`:RECORDED` against cited receipt-corpus paths) →
   `AuditChain.append/2` anchoring of the escalation record →
   `verify_chain/2` `:ok` under `expected_head` + `expected_length`, plus
   refusal of a wrong `expected_head` (`{:error, {:tampered, :head}}`).
2. **Art 100 corrective-action substrate pin**: quiescent-stop, audit
   chain, authority channel, incident report sources present and named.
3. **Determinism x3**: three full-chain runs produce byte-identical maps
   (incident id, classification, statuses, head hash, payload digest);
   registry enumeration deterministic + sorted, x3.
4. **Typed refusals on malformed authority context**: unknown channel
   (`:REFUSED_UNKNOWN_CHANNEL`), non-map report (`:REFUSED_NO_INCIDENT_EVIDENCE`),
   empty/nonexistent `originating_receipt_digests` (same atom), unknown
   `with_endpoint/2` id, missing append attrs (`:invalid_receipt_attrs`);
   non-hex payload digest accepted by `append/2` but refused at verify
   (`{:error, {:tampered, 0}}`).
5. **Tamper evidence**: non-hex payload-digest tamper of the anchored
   escalation record → `{:error, {:tampered, 0}}` (exact attribution);
   truncation → `{:error, {:truncated, 1}}` under the anchored length.
6. **Honest 99.4.e classification** (no fake closure): asserts the COMPUTED
   Titles VI-XIII classification of 99.4.e when the substrate module is
   loaded (whole-suite run: evidenced via W537/W503/W507 flip with its
   {lane, desc, paths} shape), else pins the classification substrate on
   disk (single-file run). Either way the residual OPEN component is
   asserted live: every authority channel is `endpoint: :OPEN`,
   `status: :OPEN` and returns `:PREPARED_NOT_TRANSMITTED` — the
   authority-transmission gap for Art 99/100 enforcement contact stays
   typed OPEN, never faked as sent.

## Real behavior findings during the lane (test follows actual behavior)

- `AuditChain.append/2` accepts a non-hex `payload_digest`; the 64-hex gate
  lives in `verify_chain/2` (`valid_payload_digest?/1`), not in `append/2`.
- Index-0 payload tamper with a VALID-hex replacement digest yields
  `{:error, {:tampered, :head}}` (head mismatch, since the new content
  hashes to a different head), not `{:tampered, 0}` — exact index
  attribution requires a NON-hex digest (fails the gate at that index).
- Single EUAIA refusal atom classifies only `[:INFRINGES_UNION_LAW]`;
  `:MALFUNCTION` requires a non-EUAIA refused receipt (or refusal string
  outside `@euaia_refusal_strings`).

## Commands (real tails)

Single-file gate:

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW696 \
  mix test test/eu_ai_act/art99_enforcement_deepening_test.exs --include eu_ai_act
Including tags: [:eu_ai_act]
Finished in 0.6 seconds (0.6s async, 0.00s sync)
Result: 7 passed
```

Joint run with the Titles VI-XIII substrate (Lines branch exercised for real):

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW696 \
  mix test test/eu_ai_act/art99_enforcement_deepening_test.exs test/eu_ai_act/title_vi_xiii_test.exs --include eu_ai_act
Including tags: [:eu_ai_act]
Finished in 0.7 seconds (0.7s async, 0.00s sync)
Result: 483 passed
```

Both under pinned asdf toolchain, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW696`.

## Standing

- **Standing**: PARTIAL_ALIVE — the escalation chain composition, determinism,
  typed-refusal, and tamper-evidence courts pass on the exact subject
  a0723bf6; the authority-transmission endpoint remains typed OPEN
  (asserted, not faked), so Art 99/100 enforcement contact is
  evidenced-with-caveat.
- **Residual gap (honest)**: real wire transmission to a market-surveillance
  authority endpoint does not exist (corpus 73.4-73.5 caveat carried in the
  assertions); 99.4.e is computed :evidenced by the W537 flip but its
  authority-side residual is carried as typed OPEN by this suite.
- **Falsifiers passed**: wrong expected_head refused; tampered/truncated
  chain refused; malformed authority context refused with typed atoms;
  determinism held across 3 runs.

## Hygiene

- No mocks (grep gate trivially clean: file calls real modules only).
- No commit performed (per lane contract). Working tree gains only this
  test file + this receipt.
- `MIX_BUILD_ROOT=_build-laneW696` left in place for the coordinator — the
  lane's `rm -rf` of the build root was DENIED by the session permission
  system (observed twice, 2026-10-07); per the lane contract ("else leave
  for coordinator") cleanup passes to the coordinator.
