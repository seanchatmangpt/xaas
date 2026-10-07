# W605 — ash_a2a AIRo description (AIRo wiring wave)

Lane: W605 · Repo: /Users/sac/ash_a2a (canonical checkout, no commit) · Build root: `_build-laneW605` · Toolchain: asdf elixir 1.20.4-otp-29 / erlang 29.1.1

## Task

Describe the ash_a2a A2A protocol surface in the AIRo vocabulary
(https://w3id.org/airo, v1.0): system as `airo:AISystem`, the `:legacy_compat`
security-profile warning classes (`AshA2A.SecurityProfile.Boot` strict
violation codes) as `airo:RiskSource` individuals, the enforcing modules as
`airo:RiskControl` individuals with `airo:detectsRiskConcept` edges, and the
receipt-durability requirement as `airo:hasConsequence` chains. Guard with an
ExUnit structural test.

## Diff (2 files, ash_a2a tree, uncommitted)

- `priv/ontology/ash_a2a_airo.ttl` — NEW. AIRo description:
  - `a2a:A2AProtocolSurface a airo:AISystem` with `airo:hasRisk` (5 risks) and
    `airo:hasRiskControl` (5 controls).
  - 11 `airo:RiskSource` individuals, one per legacy_compat/strict violation
    code: `authority_broker_missing`, `kill_switch_class_missing`,
    `claim_store_missing`, `claim_store_not_durable`, `claim_store_dir_not_durable`,
    `receipt_store_in_memory`, `outbox_dir_not_durable`, `outbox_key_missing`,
    `receipt_store_boot_check_failed`, `capability_release_mode_legacy`,
    `transport_verified_policy_forbidden`.
  - 5 `airo:RiskControl` individuals mapped to enforcing modules:
    `AshA2A.SecurityProfile.Boot` (detects all 11),
    `AshA2A.Authority.Broker.Ekv`, `AshA2A.KillSwitch`,
    `AshA2A.ConsequenceKernel.EffectClaimStore.DurableFile`,
    `AshA2A.ReceiptStore`.
  - 5 `airo:Risk` individuals with `airo:hasConsequence` chains to 5
    `airo:Consequence` individuals (incl. `Consequence-SilentClaimLoss`,
    `Consequence-UnreceiptedMutation` — the receipt-durability requirement).
- `test/ash_a2a_airo_description_test.exs` — NEW. ExUnit court asserting the
  TTL exists, prefixes declared, delimiter/statement balance, every subject
  typed, all 11 warning classes present as RiskSources, all 5 cited module
  paths exist on disk, detectsRiskConcept edges reference locally defined
  subjects, codes match the real `Boot.__sa2a_refusal_codes__/0` (Chicago: the
  module is a real collaborator, no mocks), and hasConsequence chains exist.

## AIRo vocabulary grounding

Fetched `airo.ttl` @ main (DelaramGlp/airo). Terms used per their real
domains/ranges: `hasRisk` (→Risk), `hasRiskControl` (→RiskControl),
`isRiskSourceFor` (RiskSource→Risk), `detectsRiskConcept` (RiskControl→
RiskConcept), `hasConsequence` (Risk→Consequence).

## Verification (actual output)

    $ MIX_BUILD_ROOT=_build-laneW605 MIX_ENV=test mix test test/ash_a2a_airo_description_test.exs
    Excluding tags: [:serial, :sibling_repos, :external_api, :benchmark]

    .........
    Finished in 0.09 seconds (0.09s async, 0.00s sync)

    Result: 9 passed

Two intermediate failures were real and were fixed at the artifact (TTL was
missing `rdf:type` on `RiskSource-ClaimStoreNotDurable`), not by loosening
assertions. No `Map.update` introduced. Toolchain: elixir 1.20.4-otp-29 /
erlang 29.1.1 (asdf), lane build root `_build-laneW605`. Nothing committed.

## Falsifier

Delete any RiskSource block or rename a cited module; the court fails on
the missing warning class / missing module path respectively.
