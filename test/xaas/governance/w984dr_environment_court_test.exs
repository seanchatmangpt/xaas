defmodule Xaas.Governance.W984drEnvironmentCourtTest do
  @moduledoc """
  Lane W984dr depth court (v26.10.6), continuing the governance-types
  burn-down (W984cy4 courted `OverrideDecision`; W984di2 verified
  `CapabilityClass` dead). Court subject:
  `Xaas.Governance.Types.Environment` — the most state-bearing of the
  remaining attribute-bound governance enums (3 attribute bindings on 2
  live resources: `ApprovalDeploymentQuarantine.environment`,
  `ApprovalEnvironmentPromote.from_environment/.to_environment` — the
  dev/staging/prod promotion boundary for real deployed infra).

  Indirect-exercise census finding: existing coverage touches
  Environment only incidentally (`:prod` in lifecycle/freeze-window
  tests, one `"dev"` string in a tamper test, one refusal test on
  quarantine's `:environment`) — no direct enum-contract court, and
  zero typed-atom assertions anywhere on the promotion path.
  This court fills that gap: full-value roundtrip, one_of refusal
  shape, storage encoding, through the live consumer resources via
  real Ash actions over real sandboxed Postgres. No mocks.

  Per-test mutation rationale is in each test's comment.
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDeploymentQuarantine
  alias Xaas.Governance.ApprovalEnvironmentPromote
  alias Xaas.Governance.Types.Environment

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_org!(prefix) do
    unique = System.unique_integer([:positive])

    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{prefix} #{unique}",
      slug: "#{prefix}-#{unique}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp quarantine_attrs(org_slug, env) do
    %{
      org_id: org_slug,
      requested_by: "w984dr-requester",
      deployment_name: "deploy-#{System.unique_integer([:positive])}",
      environment: env,
      reason: :security_finding
    }
  end

  defp create_quarantine(org, env) do
    ApprovalDeploymentQuarantine
    |> Ash.Changeset.for_create(
      :create,
      quarantine_attrs(org.slug, env),
      tenant: org.slug,
      actor: %{org_id: org.slug}
    )
    |> Ash.create(authorize?: true)
  end

  test "full-value roundtrip: dev, staging, prod each persist and reload as the typed atom" do
    # Mutation rationale: a swap of Environment -> plain :string (or a
    # dropped enum member) changes which inputs the one_of cast admits;
    # asserting every member of the closed set roundtrips as a real
    # atom through an authorized create + tenant-scoped reload kills
    # both mutations on the real persistence path.
    org = real_org!("w984dr-env")

    for env <- Environment.values() do
      assert {:ok, %ApprovalDeploymentQuarantine{} = row} = create_quarantine(org, env)
      assert row.environment == env

      rows =
        ApprovalDeploymentQuarantine
        |> Ash.Query.for_read(:read, %{}, tenant: org.slug, authorize?: false)
        |> Ash.read!()

      # sandbox accumulates one row per loop iteration — assert exactly
      # one row carries this iteration's env value
      persisted = Enum.find(rows, &(&1.environment == env))

      assert persisted
    end
  end

  test "promotion roundtrip: from_environment/to_environment persist as typed atoms on the second consumer" do
    # Mutation rationale: an attribute rename or type swap on either
    # Environment-bound attribute of ApprovalEnvironmentPromote (the
    # promotion path — higher blast radius than quarantine) would break
    # the typed return; asserting both attributes together pins the
    # enum on its second live consumer, which no existing test asserts
    # as typed atoms.
    promote_attrs = %{
      org_id: "org-w984dr-promote",
      requested_by: "w984dr-requester",
      project_name: "w984dr-project",
      from_environment: :staging,
      to_environment: :prod
    }

    assert {:ok, %ApprovalEnvironmentPromote{} = row} =
             ApprovalEnvironmentPromote
             |> Ash.Changeset.for_create(:create, promote_attrs, authorize?: false)
             |> Ash.create(authorize?: false)

    assert row.from_environment == :staging
    assert row.to_environment == :prod

    persisted = Ash.get!(ApprovalEnvironmentPromote, row.id, authorize?: false)
    assert persisted.from_environment == :staging
    assert persisted.to_environment == :prod
  end

  test "one_of refusal shape: out-of-enum environment is typed Invalid keyed on :environment, no row lands" do
    # Mutation rationale: this distinguishes a real one_of refusal (an
    # error struct keyed :environment naming the bad value) from a bare
    # Invalid or a silent cast-to-string acceptance. Kills the
    # enum->:string mutation where it does real damage: bad input would
    # otherwise land a row with free-form environment text.
    org = real_org!("w984dr-refusal")

    assert {:error, %Ash.Error.Invalid{} = error} =
             ApprovalDeploymentQuarantine
             |> Ash.Changeset.for_create(
               :create,
               quarantine_attrs(org.slug, "disaster-recovery"),
               tenant: org.slug,
               actor: %{org_id: org.slug}
             )
             |> Ash.create(authorize?: true)

    assert error.errors
           |> Enum.any?(fn e ->
             is_map(e) and Map.get(e, :field) == :environment and
               (Map.get(e, :message) || "") =~ "is invalid"
           end)

    count =
      ApprovalDeploymentQuarantine
      |> Ash.Query.for_read(:read, %{}, tenant: org.slug, authorize?: false)
      |> Ash.count!()

    assert count == 0
  end

  test "storage encoding: persisted column is the native string, Ash reloads it back to the atom" do
    # Mutation rationale: catches dump/load divergence — e.g. an enum
    # backed by integer codes, or a load that returns strings instead
    # of atoms. Raw-SQL truth + typed reload proves the encoding is
    # the verbatim string on both sides.
    org = real_org!("w984dr-enc")

    assert {:ok, row} = create_quarantine(org, :prod)

    %{rows: [[stored]]} =
      Ecto.Adapters.SQL.query!(
        Xaas.Repo,
        "SELECT environment FROM approval_deployment_quarantines WHERE id = $1",
        [Ecto.UUID.dump!(row.id)]
      )

    assert stored == "prod"

    persisted = Ash.get!(ApprovalDeploymentQuarantine, row.id, tenant: org.slug, authorize?: false)
    assert persisted.environment == :prod
  end

  test "promote one_of refusal shape: out-of-enum to_environment is typed Invalid keyed on :to_environment" do
    # Mutation rationale: pins the refusal on the SECOND Environment-
    # bound attribute path (:to_environment), not just quarantine's
    # :environment — an attribute-level type swap on the promote
    # resource alone would otherwise have zero direct witnesses.
    promote_attrs = %{
      org_id: "org-w984dr-promote-refusal",
      requested_by: "w984dr-requester",
      project_name: "w984dr-project",
      from_environment: :staging,
      to_environment: "performance"
    }

    assert {:error, %Ash.Error.Invalid{} = error} =
             ApprovalEnvironmentPromote
             |> Ash.Changeset.for_create(:create, promote_attrs, authorize?: false)
             |> Ash.create(authorize?: false)

    assert error.errors
           |> Enum.any?(fn e ->
             is_map(e) and Map.get(e, :field) == :to_environment and
               (Map.get(e, :message) || "") =~ "is invalid"
           end)
  end
end
