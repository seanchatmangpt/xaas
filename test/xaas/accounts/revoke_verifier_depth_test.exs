defmodule Xaas.Accounts.RevokeVerifierDepthTest do
  @moduledoc """
  W984cw5 depth court for `Xaas.Accounts.Token.RevokeVerifier` — the last
  genuinely-uncovered `lib/xaas/accounts/` module per the W984cj coverage map
  (zero direct test references at census time; the sibling `RevokeNonce` /
  `EnforceSingleRevoke` pair is exercised indirectly by
  `test/xaas/accounts/token_revocation_test.exs` through the real `:revoke_token`
  action path).

  Real Chicago-style: no mocks. The verifier is exercised directly as a real
  behaviour implementation over the real test-config HMAC key
  (`config/test.exs:65`), and its output is cross-checked against an independent
  `:crypto.mac` recomputation of the same contract.

  Mutation rationale per test:
    1. Happy path returns a real `AshOnetime.Verified` with the pinned verifier
       id — kills "returns {:ok, term}" / dropped-id mutations.
    2. Key is the exact HMAC-SHA256 of the raw token under the configured key —
       kills key-derivation mutations (raw token, unkeyed digest, wrong key).
    3. Determinism + injectivity: same token -> same key, distinct tokens ->
       distinct keys — kills randomized or colliding derivations.
    4. Guard clause: non-binary and empty-binary inputs are refused
       `{:error, :invalid_token}` — kills dropped-guard mutations.
    5. Behaviour metadata pins (`algorithm/0`, `trust_model/0`) and real
       `issued_at` freshness — kills metadata-drift mutations.
  """
  use ExUnit.Case, async: true

  alias AshOnetime.Verified
  alias Xaas.Accounts.Token.RevokeVerifier

  @key "test-only-onetime-revoke-key-do-not-use-in-prod"

  test "1. verify/1 on a binary returns {:ok, %Verified{}} with the pinned verifier id" do
    assert {:ok,
            %Verified{
              key: key,
              issued_at: %DateTime{},
              verifier_id: "xaas.accounts.token.revoke_verifier/1"
            }} = RevokeVerifier.verify("raw-token-material", %{})

    assert is_binary(key) and byte_size(key) == 32
  end

  @tag :regression
  test "2. key is the exact HMAC-SHA256 of the raw token under the configured key" do
    token = "mutation-court-token-#{System.unique_integer([:positive])}"

    {:ok, %Verified{key: key}} = RevokeVerifier.verify(token, %{})

    assert key == :crypto.mac(:hmac, :sha256, @key, token)
  end

  test "3. deterministic for the same token, injective across distinct tokens" do
    t1 = "injectivity-a-#{System.unique_integer([:positive])}"
    t2 = "injectivity-b-#{System.unique_integer([:positive])}"

    assert {:ok, %Verified{key: k1a}} = RevokeVerifier.verify(t1, %{})
    assert {:ok, %Verified{key: k1b}} = RevokeVerifier.verify(t1, %{})
    assert {:ok, %Verified{key: k2}} = RevokeVerifier.verify(t2, %{})

    assert k1a == k1b
    refute k1a == k2
  end

  test "4. non-binary and empty-binary inputs are refused {:error, :invalid_token}" do
    assert {:error, :invalid_token} = RevokeVerifier.verify(nil, %{})
    assert {:error, :invalid_token} = RevokeVerifier.verify(42, %{})
    assert {:error, :invalid_token} = RevokeVerifier.verify("", %{})
    assert {:error, :invalid_token} = RevokeVerifier.verify(:"atom", %{})
  end

  @tag :regression
  test "5. behaviour metadata pins hold and issued_at is fresh" do
    assert RevokeVerifier.algorithm() == :hmac_sha256
    assert RevokeVerifier.trust_model() == :same_service

    before = DateTime.utc_now()
    {:ok, %Verified{issued_at: issued_at}} = RevokeVerifier.verify("freshness", %{})
    after_ = DateTime.utc_now()

    assert DateTime.compare(issued_at, before) in [:gt, :eq]
    assert DateTime.compare(issued_at, after_) in [:lt, :eq]
  end
end
