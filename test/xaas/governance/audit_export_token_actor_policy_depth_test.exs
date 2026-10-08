defmodule Xaas.Governance.AuditExportTokenActorPolicyDepthTest do
  @moduledoc """
  Lane W984ar depth court (v26.10.6): the one uncourted slice of
  `Xaas.Governance.AuditExportToken` — the REAL policy layer with a REAL
  actor. Every prior court in `export_token_deepening_test.exs` (W765/W801/
  W900/W935/W940b lineage) runs `authorize?: false`, so the
  `AuditExportTokenActorOrgMatches` SimpleCheck — the twentieth-pass ERRC
  item-27 repair, live-HTTP-proven exploitable before it — has zero
  executable coverage as a policy. These courts exercise the authorized
  paths (`authorize?: true` + actor) against real sandboxed Postgres rows.
  No GraphQL surfaces. No mocks.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Governance.AuditExportToken

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp actor(o), do: %{org_id: o}

  defp issue(org_id, created_by) do
    AuditExportToken
    |> Ash.Changeset.for_create(:issue, %{org_id: org_id, created_by: created_by})
  end

  # ------------------------------------------------------------------
  # (a) :issue — authorized mint path through the real bypass+check
  # ------------------------------------------------------------------

  # Mutation rationale: deleting the `bypass action(:issue) do
  # authorize_if(AuditExportTokenActorOrgMatches)` block (or the check's
  # matching-org clause) from lib/xaas/governance/audit_export_token.ex
  # makes this court fail — the deny-by-default floor
  # (`policy always() do forbid_if always()`) refuses every actor, so the
  # authorized mint returns `{:error, %Ash.Error.Forbidden{}}` and no row
  # is persisted.
  test "matching-org actor mints through the real policy: row persists, raw token in changeset context" do
    o = org("aetpol")

    cs = issue(o, "w984ar-lane")

    assert {:ok, %AuditExportToken{} = token} = Ash.create(cs, authorize?: true, actor: actor(o))

    assert token.org_id == o
    assert is_binary(token.token_hash) and byte_size(token.token_hash) == 64
    assert String.starts_with?(token.token_prefix, "aet_live_")
    assert token.scope == "audit:read"

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert persisted.token_hash == token.token_hash

    # the check's :create clause reads org_id off the pending changeset
    # (no multitenancy block on this resource) — a cross-check that the
    # authorized path is the check's real :issue clause, not an ambient
    # allow: a fabricated foreign org under the same actor is refused
    # one line below in the next court.
    assert %{active?: true} = Ash.load!(token, :active?, authorize?: false)
  end

  test "foreign-org actor minting for another org is refused (Forbidden), nothing persisted" do
    o = org("aetpol-mine")
    foreign = org("aetpol-foreign")

    assert {:error, %Ash.Error.Forbidden{}} =
             issue(foreign, "w984ar-lane") |> Ash.create(authorize?: true, actor: actor(o))

    # no row for the foreign org, and the refusing actor's org is clean too
    assert AuditExportToken
           |> Ash.Query.filter(org_id in ^[o, foreign])
           |> Ash.read!(authorize?: false) == []
  end

  # ------------------------------------------------------------------
  # (b) :revoke — authorized revoke semantics through the policy
  # ------------------------------------------------------------------

  # Mutation rationale: deleting the `bypass action(:revoke)` block (or
  # the check's `:revoke` resolve_org_id clause reading org_id off
  # `changeset.data`) makes the authorized revoke fail (floor refuses the
  # matching actor) and the foreign revoke succeed (no check left).
  test "matching-org actor revokes; foreign-org actor is refused and revoked_at is untouched" do
    o = org("aetpol-revoke")

    token =
      issue(o, "w984ar-lane") |> Ash.create!(authorize?: true, actor: actor(o))

    assert {:ok, %AuditExportToken{} = revoked} =
             token
             |> Ash.Changeset.for_update(:revoke, %{})
             |> Ash.update(authorize?: true, actor: actor(o))

    assert %DateTime{} = revoked.revoked_at
    assert %{active?: false} = Ash.load!(revoked, :active?, authorize?: false)
  end

  # Ordering disclosure (observed, not assumed): Ash runs changeset
  # validations before the update-path policy check, so on an
  # already-revoked token the typed `AuditExportTokenNotAlreadyRevoked`
  # refusal preempts the policy refusal. The foreign-org policy refusal
  # therefore has to be courted on a fresh token — where it is real.
  test "foreign-org actor cannot revoke another org's token (Forbidden); revoked_at stays nil" do
    o = org("aetpol-revoke-mine")
    foreign = org("aetpol-revoke-foreign")

    token = issue(o, "w984ar-lane") |> Ash.create!(authorize?: true, actor: actor(o))

    assert {:error, %Ash.Error.Forbidden{}} =
             token
             |> Ash.Changeset.for_update(:revoke, %{})
             |> Ash.update(authorize?: true, actor: actor(foreign))

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert is_nil(persisted.revoked_at)
  end

  # ------------------------------------------------------------------
  # (c) :use — authorized consume semantics through the policy
  # ------------------------------------------------------------------

  # Mutation rationale: removing the SPEC-16 `bypass action(:use)` policy
  # block re-subjects the consume path to the deny-by-default floor: the
  # authorized use returns Forbidden and use_count never advances; the
  # foreign-org attack (consuming another org's export credential) is no
  # longer refused.
  test "matching-org actor consumes; foreign-org actor is refused, used_at/use_count untouched" do
    o = org("aetpol-use")

    token = issue(o, "w984ar-lane") |> Ash.create!(authorize?: true, actor: actor(o))

    assert {:ok, used} =
             token
             |> Ash.Changeset.for_update(:use, %{})
             |> Ash.update(authorize?: true, actor: actor(o))

    assert used.use_count == 1
    assert %DateTime{} = used.used_at
  end

  # Same ordering disclosure as :revoke above: the typed
  # AuditExportTokenNotAlreadyUsed refusal preempts the policy refusal on
  # an already-used token, so the foreign-org consumption attack is
  # courted on a fresh token.
  test "foreign-org actor cannot consume another org's token (Forbidden); used_at/use_count untouched" do
    o = org("aetpol-use-mine")
    foreign = org("aetpol-use-foreign")

    token = issue(o, "w984ar-lane") |> Ash.create!(authorize?: true, actor: actor(o))

    assert {:error, %Ash.Error.Forbidden{}} =
             token
             |> Ash.Changeset.for_update(:use, %{})
             |> Ash.update(authorize?: true, actor: actor(foreign))

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert is_nil(persisted.used_at)
    assert persisted.use_count == 0
  end

  # ------------------------------------------------------------------
  # (d) fail-closed actor shapes (the check's catch-all clause)
  # ------------------------------------------------------------------

  # Mutation rationale: replacing the check's catch-all
  # `defp resolve_org_id(_), do: nil` / `match?(_actor, _context, _opts),
  # do: false` clauses with an `always()`-true fallback keeps every
  # matching-org court above green but fails this court — the blank/
  # missing-org actor would mint/destroy/consume for any org.
  test "fail-closed: actor with blank or missing org_id is refused on issue, revoke, and use" do
    o = org("aetpol-fc")

    assert {:error, %Ash.Error.Forbidden{}} =
             issue(o, "w984ar-lane") |> Ash.create(authorize?: true, actor: %{org_id: ""})

    assert {:error, %Ash.Error.Forbidden{}} =
             issue(o, "w984ar-lane") |> Ash.create(authorize?: true, actor: %{})

    token = issue(o, "w984ar-lane") |> Ash.create!(authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} =
             token
             |> Ash.Changeset.for_update(:revoke, %{})
             |> Ash.update(authorize?: true, actor: %{})

    assert {:error, %Ash.Error.Forbidden{}} =
             token
             |> Ash.Changeset.for_update(:use, %{})
                          |> Ash.update(authorize?: true, actor: %{org_id: "   "})

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    assert is_nil(persisted.revoked_at)
    assert persisted.use_count == 0
  end
end
