defmodule Xaas.Operations.CastleVerbCourtW984fjTest do
  @moduledoc """
  Lane W984fj (v26.10.6): burn-down of the Castle/Route-verb operations
  batch left uncovered by W984fh's sixth re-census (/tmp/w984fh_map.txt):

    - 6 `*Approve` change modules:
      `Xaas.Operations.Changes.RouteCastle{Deploy,Run,Schedule,Sunset}Approve`,
      `Xaas.Operations.Changes.CastleVerbInventory{Components,Goals}Approve`
    - 6 matching `*RequiresApprover` validation modules:
      `Xaas.Operations.Validations.RouteCastle{Deploy,Run,Schedule,Sunset}RequiresApprover`,
      `Xaas.Operations.Validations.CastleVerbInventory{Components,Goals}RequiresApprover`

  Disposition (re-read from disk 2026-10-07): each of the 12 modules is a
  thin identity surface — `init/1` passthrough plus `change/3` /
  `validate/3` returning the changeset unchanged. A CamelCase grep over
  `lib/` (command grep, multiline-safe) shows each module name occurs
  ONLY in its own file: none is wired into any resource action, unlike
  the W984dr2b `*RequiresApprover` family which every `:approve` action
  on its consumer resource wires. The consumer resources
  (`RouteCastleDeploy`, `RouteCastleRun`, `RouteCastleSchedule`,
  `RouteCastleSunset`, `CastleVerbInventoryComponents`,
  `CastleVerbInventoryGoals`) are read-only (plus the private
  `:execute` on `RouteCastleRun`, courted by W858's
  route_castle_run_surface_test); their resource surfaces are already
  covered by W984dk (castle_approval_route_surface_test) and the
  policy-floor courts. The genuinely unexercised branches are therefore
  the 12 thin modules' own functions, exercised here directly, plus the
  wiring-status invariant that keeps them from becoming a vacuous gate.

  Mutation rationale:
    - identity mutation: if any module stops being an identity (starts
      mutating the changeset / returning an error), the identity court
      fails — a gate that silently alters behavior without wiring would
      otherwise go unwitnessed.
    - init mutation: a module whose `init/1` stops accepting its opts
      fails the init court.
    - wiring mutation: if someone later wires one of these identity
      no-op `*RequiresApprover` validations onto a real `:approve`
      action, that approval gate becomes vacuous (always :ok). The
      wiring court asserts the read-only action surface of every
      consumer resource, so adding an `:approve` action or wiring a
      validation flips the assertion and fails the court.

  Chicago discipline: real Ash changesets against real resources,
  real sandboxed Postgres rows for the read-surface probe, zero mocks.
  """

  use ExUnit.Case, async: true

  @approve_changes [
    Xaas.Operations.Changes.RouteCastleDeployApprove,
    Xaas.Operations.Changes.RouteCastleRunApprove,
    Xaas.Operations.Changes.RouteCastleScheduleApprove,
    Xaas.Operations.Changes.RouteCastleSunsetApprove,
    Xaas.Operations.Changes.CastleVerbInventoryComponentsApprove,
    Xaas.Operations.Changes.CastleVerbInventoryGoalsApprove
  ]

  @requires_approver_validations [
    Xaas.Operations.Validations.RouteCastleDeployRequiresApprover,
    Xaas.Operations.Validations.RouteCastleRunRequiresApprover,
    Xaas.Operations.Validations.RouteCastleScheduleRequiresApprover,
    Xaas.Operations.Validations.RouteCastleSunsetRequiresApprover,
    Xaas.Operations.Validations.CastleVerbInventoryComponentsRequiresApprover,
    Xaas.Operations.Validations.CastleVerbInventoryGoalsRequiresApprover
  ]

  # Consumer resources: read-only (RouteCastleRun additionally has the
  # private, non-routed :execute). Asserted exactly, so any added write
  # or approve surface fails the wiring court.
  @consumer_resources [
    Xaas.Operations.RouteCastleDeploy,
    Xaas.Operations.RouteCastleRun,
    Xaas.Operations.RouteCastleSchedule,
    Xaas.Operations.RouteCastleSunset,
    Xaas.Operations.CastleVerbInventoryComponents,
    Xaas.Operations.CastleVerbInventoryGoals
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "census self-check: the 12-module family is fully enumerated on disk" do
    assert length(@approve_changes) == 6
    assert length(@requires_approver_validations) == 6

    for module <- @approve_changes ++ @requires_approver_validations do
      assert Code.ensure_loaded?(module), "missing module: #{inspect(module)}"
    end
  end

  test "(1) every *Approve change module is an identity: init passthrough + unchanged changeset" do
    for module <- @approve_changes do
      assert {:ok, []} = module.init([])

      opts = %{lane: "w984fj"}
      assert {:ok, ^opts} = module.init(opts)

      changeset =
        Xaas.Operations.ApprovalCastleVerbSchedule
        |> Ash.Changeset.for_create(:create, %{requested_by: "w984fj-approve-probe"},
          authorize?: false
        )

      assert ^changeset = module.change(changeset, [], %{})
      assert ^changeset = module.change(changeset, opts, %{context: :w984fj})
    end
  end

  test "(2) every *RequiresApprover validation module is an identity: init passthrough + :ok on real changesets" do
    for module <- @requires_approver_validations do
      assert {:ok, []} = module.init([])

      opts = %{lane: "w984fj"}
      assert {:ok, ^opts} = module.init(opts)

      # :ok on an approver-less changeset AND on a populated one — the
      # module's entire branch surface is a single :ok.
      for approved_by <- [nil, "w984fj-checker"] do
        changeset =
          Xaas.Operations.ApprovalCastleVerbSchedule
          |> Ash.Changeset.new()
          |> Ash.Changeset.change_attribute(:approved_by, approved_by)
          |> Ash.Changeset.for_create(:create, %{requested_by: "w984fj-validation-probe"},
            authorize?: false
          )

        assert :ok = module.validate(changeset, [], %{})
        assert :ok = module.validate(changeset, opts, %{context: :w984fj})
      end
    end
  end

  test "(3) wiring court: no consumer resource exposes an :approve (or any write) action these thin modules could vacuously gate" do
    for resource <- @consumer_resources do
      action_names =
        resource
        |> Ash.Resource.Info.actions()
        |> Enum.map(& &1.name)

      expected =
        if resource == Xaas.Operations.RouteCastleRun,
          do: [:read, :execute],
          else: [:read]

      assert Enum.sort(action_names) == Enum.sort(expected),
             "unexpected action surface on #{inspect(resource)}: #{inspect(action_names)}"
    end
  end

  test "(4) wiring court: none of the 12 thin module names appears in any lib/ wiring site outside its own file" do
    # Multiline-safe CamelCase grep over lib/, excluding the module's
    # own definition file. W984er proved wiring can hide behind line
    # breaks, so this greps the bare CamelCase symbol, not a pattern.
    lib_root = Path.expand("lib", File.cwd!())

    for module <- @approve_changes ++ @requires_approver_validations do
      symbol = module |> Module.split() |> List.last()
      own_file = module.module_info(:compile)[:source] |> to_string()

      hits =
        Path.wildcard(Path.join(lib_root, "**/*.ex"))
        |> Enum.reject(&(Path.expand(&1) == Path.expand(own_file)))
        |> Enum.flat_map(fn path ->
          File.read!(path)
          |> String.contains?(symbol)
          |> case do
            true -> [path]
            false -> []
          end
        end)

      assert hits == [],
             "thin module #{inspect(module)} gained a wiring site outside its own file: #{inspect(hits)}"
    end
  end

  test "(5) boundary probe: repo-minted rows on all six consumer tables stay readable, write-refused, and unchanged" do
    tables = %{
      Xaas.Operations.RouteCastleDeploy => "route_castle_deploys",
      Xaas.Operations.RouteCastleRun => "route_castle_runs",
      Xaas.Operations.RouteCastleSchedule => "route_castle_schedules",
      Xaas.Operations.RouteCastleSunset => "route_castle_sunsets",
      Xaas.Operations.CastleVerbInventoryComponents => "castle_verb_inventory_components",
      Xaas.Operations.CastleVerbInventoryGoals => "castle_verb_inventory_goals"
    }

    for {resource, table} <- tables do
      {1, [%{id: raw_id}]} =
        Xaas.Repo.insert_all(
          table,
          [%{requested_by: "w984fj-floor", approved_by: nil}],
          returning: [:id]
        )

      id = Ecto.UUID.cast!(raw_id)

      row = Ash.get!(resource, id, authorize?: false)
      assert row.requested_by == "w984fj-floor"
      assert is_nil(row.approved_by)

      # No update action exists to flip approved_by: the write surface
      # is absent, so the row is untouched and survives byte-identical.
      record = Ash.get!(resource, id, authorize?: false)

      assert_raise ArgumentError, ~r/No such update action/, fn ->
        record
        |> Ash.Changeset.for_update(:update, %{approved_by: "w984fj-floor"})
        |> Ash.update()
      end

      reloaded = Ash.get!(resource, id, authorize?: false)
      assert is_nil(reloaded.approved_by)
      assert reloaded.requested_by == "w984fj-floor"
    end
  end
end
