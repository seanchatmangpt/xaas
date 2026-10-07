defmodule Xaas.Governance.W984cqPolicyOrderingCourtTest do
  @moduledoc """
  Lane W984cq adjudication court (v26.10.6): validation-vs-policy ordering on
  `Xaas.Governance.AuditExportToken`.

  Question: when a FOREIGN actor (org mismatch) invokes `:revoke` or `:use` on
  an already-revoked token, does the validation error ("already revoked"/
  "already used") surface before the policy `Ash.Error.Forbidden` — leaking
  revoked/used state existence to an unauthorized actor (W984ar finding), or
  does the policy refuse first?

  Ash 3.34.4 `Ash.Actions.Update.do_run/4` pipeline is:

      handle_multitenant -> changeset -> authorize ->
        add_atomic_validations -> commit

  `authorize/2` runs BEFORE `add_atomic_validations/3`, and non-atomic
  validations run in `before_action` hooks inside `commit/3`, i.e. both
  AFTER authorization. These courts measure the real behavior directly:
  a foreign actor must observe `Ash.Error.Forbidden` regardless of the
  token's revoked/used state (state-existence leak closed).
  """

  use ExUnit.Case, async: true

  alias Xaas.Governance.AuditExportToken

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
  defp actor(o), do: %{org_id: o}

  defp mint(o) do
    AuditExportToken
    |> Ash.Changeset.for_create(:issue, %{org_id: o, created_by: "w984cq-lane"})
    |> Ash.create!(authorize?: true, actor: actor(o))
  end

  # -+
  # (1) Foreign actor vs ACTIVE token -> Forbidden (baseline, W984ar)
  # ------------------------------------------------------------------

  test "(1) foreign actor on an active token is Forbidden" do
    o = org("w984cq-a")
    foreign = actor(org("w984cq-foreign-a"))

    token = mint(o)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(token |> Ash.Changeset.for_update(:revoke, %{}),
               authorize?: true,
               actor: foreign
             )

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(token |> Ash.Changeset.for_update(:use, %{}),
               authorize?: true,
               actor: foreign
             )
  end

  # ------------------------------------------------------------------
  # (2) THE ADJUDICATION: foreign actor vs ALREADY-REVOKED token.
  # Forbidden (policy first => leak closed / Ash-invariant holds) vs
  # Invalid("already revoked") (validation first => leak confirmed,
  # per-resource fix needed).
  # ------------------------------------------------------------------

  test "(2) foreign actor on an already-revoked token observes the same error class as on an active one" do
    o = org("w984cq-b")
    home = actor(o)
    foreign = actor(org("w984cq-foreign-b"))

    token = mint(o)

    # Home actor revokes: real policy path, revoked_at stamped.
    assert {:ok, %AuditExportToken{revoked_at: %DateTime{}}} =
             Ash.update(token |> Ash.Changeset.for_update(:revoke, %{}),
               authorize?: true,
               actor: home
             )

    fresh = mint(o)

    foreign_on_active =
      Ash.update(fresh |> Ash.Changeset.for_update(:revoke, %{}),
        authorize?: true,
        actor: foreign
      )

    foreign_on_revoked =
      Ash.update(token |> Ash.Changeset.for_update(:revoke, %{}),
        authorize?: true,
        actor: foreign
      )

    assert {:error, %Ash.Error.Forbidden{}} = foreign_on_active
    # THE assertion under adjudication: same class for the revoked state.
    assert {:error, %Ash.Error.Forbidden{}} = foreign_on_revoked
  end

  # ------------------------------------------------------------------
  # (3) Same adjudication for :use vs already-USED token.
  # ------------------------------------------------------------------

  test "(3) foreign actor on an already-used token observes the same error class as on an active one" do
    o = org("w984cq-c")
    home = actor(o)
    foreign = actor(org("w984cq-foreign-c"))

    token = mint(o)

    assert {:ok, %AuditExportToken{used_at: %DateTime{}, use_count: 1}} =
             Ash.update(token |> Ash.Changeset.for_update(:use, %{}),
               authorize?: true,
               actor: home
             )

    fresh = mint(o)

    foreign_on_active =
      Ash.update(fresh |> Ash.Changeset.for_update(:use, %{}),
        authorize?: true,
        actor: foreign
      )

    foreign_on_used =
      Ash.update(token |> Ash.Changeset.for_update(:use, %{}),
        authorize?: true,
        actor: foreign
      )

    assert {:error, %Ash.Error.Forbidden{}} = foreign_on_active
    assert {:error, %Ash.Error.Forbidden{}} = foreign_on_used
  end

  # ------------------------------------------------------------------
  # (4) Negative control proving the validations are actually live on
  # these same actions for an AUTHORIZED actor — so court (2)/(3)'s
  # Forbidden is ordering, not absent validations.
  # ------------------------------------------------------------------

  test "(4) authorized actor still trips the already-revoked/used validations" do
    o = org("w984cq-d")
    home = actor(o)

    token = mint(o)

    assert {:ok, _} =
             Ash.update(token |> Ash.Changeset.for_update(:revoke, %{}),
               authorize?: true,
               actor: home
             )

    # Refetch: the validation reads changeset DATA, so a stale in-memory
    # record would carry revoked_at == nil and defeat the guard. The real
    # consumer always loads the row first (:read is internal-api gated).
    fresh_revoked = Ash.get!(AuditExportToken, token.id, authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(fresh_revoked |> Ash.Changeset.for_update(:revoke, %{}),
               authorize?: true,
               actor: home
             )

    used = mint(o)

    assert {:ok, _} =
             Ash.update(used |> Ash.Changeset.for_update(:use, %{}),
               authorize?: true,
               actor: home
             )

    fresh_used = Ash.get!(AuditExportToken, used.id, authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.update(fresh_used |> Ash.Changeset.for_update(:use, %{}),
               authorize?: true,
               actor: home
             )
  end

  # ------------------------------------------------------------------
  # (5) Existence leak: foreign actor on a NONEXISTENT id gets the same
  # Forbidden as on a real foreign token (no row-existence oracle either).
  # ------------------------------------------------------------------

  test "(5) foreign actor on nonexistent id is Forbidden, same as on a real foreign row" do
    foreign = actor(org("w984cq-foreign-e"))

    token = mint(org("w984cq-e"))

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(token |> Ash.Changeset.for_update(:revoke, %{}),
               authorize?: true,
               actor: foreign
             )

    # Nonexistent id: :get surfaces NotFound (read bypass is open to any
    # internal-api actor — the disclosed DESIGN surface); a live foreign
    # row is likewise returned by :get, and its :revoke is Forbidden.
    missing_id = Ash.UUID.generate()

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.get(AuditExportToken, missing_id, authorize?: true, actor: foreign)

    assert {:ok, %AuditExportToken{}} =
             Ash.get(AuditExportToken, token.id, authorize?: true, actor: foreign)

    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.update(token |> Ash.Changeset.for_update(:revoke, %{}),
               authorize?: true,
               actor: foreign
             )
  end
end
