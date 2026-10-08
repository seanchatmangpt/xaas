defmodule Xaas.Operations.FortuneBatchCourtW984ivTest do
  @moduledoc """
  Lane W984iv (v26.10.6): burn-down of the W984it seventh re-census top
  uncovered batch (/tmp/w984it_map.txt):

    - `Xaas.Operations.Changes.CastleVerbFortune5RequirementsApprove`
    - `Xaas.Operations.Validations.CastleVerbFortune5RequirementsRequiresApprover`
    - `Xaas.Operations.Changes.ApprovalCastleVerbScheduleApprove`
    - `Xaas.Operations.Changes.ApprovalK8sFaultRemediateSuggestApprove`
    - `Xaas.Operations.Validations.ApprovalK8sFaultRemediateSuggestRequiresApprover`
    - `Xaas.Platform.Changes.RouteSecretsApprove`
    - `Xaas.Platform.Validations.RouteSecretsRequiresApprover`

  Dispositions (re-read from disk 2026-10-07):

    - `CastleVerbFortune5RequirementsApprove` (change) and
      `CastleVerbFortune5RequirementsRequiresApprover` (validation) are
      thin identity no-ops with NO wiring anywhere: the consumer resource
      `Xaas.Operations.CastleVerbFortune5Requirements` is read-only
      (only `:read`, no `:approve` action exists), and a CamelCase grep
      over `lib/` shows each name occurs only in its own file — the same
      finding W984fj had for the RouteCastle*/Inventory* batch. Exercised
      directly (init passthrough + unchanged changeset / :ok) plus a
      wiring-status court that fails if either gains a wiring site or the
      resource gains an :approve action without a real gate.
    - `ApprovalCastleVerbScheduleApprove` (change) is an identity no-op
      that is NOT wired: the resource's `:approve` action wires the
      (separate, real) `ApprovalCastleVerbScheduleRequiresApprover`
      validation, not this change. Direct identity exercise + unwired
      invariant.
    - `ApprovalK8sFaultRemediateSuggestApprove` (change) is an identity
      no-op, NOT wired (the resource's `:approve` wires only the
      validation). Direct identity exercise + unwired invariant.
    - `ApprovalK8sFaultRemediateSuggestRequiresApprover` is a REAL
      maker-checker rule wired on
      `Xaas.Operations.ApprovalK8sFaultRemediateSuggest`'s `:approve`:
      exercised through live Ash actions (missing / empty-string /
      self-approval refusals, distinct-approver persistence).
    - `RouteSecretsApprove` (change) is an identity action-seam, WIRED on
      `Xaas.Platform.RouteSecrets`' `:approve`; its paired
      `RouteSecretsRequiresApprover` is real and wired. Both exercised
      through live Ash actions plus an identity pin on the change.

  Mutation rationale (per family):
    - identity mutations: if any thin module stops being an identity
      (starts mutating the changeset or returning errors), the identity
      courts fail — an unwired gate that silently alters behavior would
      otherwise go unwitnessed.
    - init mutations: a module whose `init/1` stops accepting opts fails.
    - wiring mutations: if an unwired identity `*RequiresApprover`
      validation gets wired onto a real `:approve` action it becomes a
      vacuous gate (always :ok); the wiring courts assert both the
      presence of real validations on the real approve paths AND the
      absence of any wiring site for the identity shims, so either
      direction of drift flips an assertion.
    - behavior mutations: deleting a refusal branch or its message in the
      real validations fails the live-action refusal courts; breaking
      persistence of `approved_by` fails the happy-path court.

  Chicago discipline: real sandboxed Postgres via `Xaas.Repo` +
  `Ecto.Adapters.SQL.Sandbox`, real Ash actions, real changesets, zero
  mocks. Fully-covered modules get a typed COVERED disposition above, no
  filler tests.
  """

  use ExUnit.Case, async: false

  @identity_changes [
    Xaas.Operations.Changes.CastleVerbFortune5RequirementsApprove,
    Xaas.Operations.Changes.ApprovalCastleVerbScheduleApprove,
    Xaas.Operations.Changes.ApprovalK8sFaultRemediateSuggestApprove,
    Xaas.Platform.Changes.RouteSecretsApprove
  ]

  @identity_validations [
    Xaas.Operations.Validations.CastleVerbFortune5RequirementsRequiresApprover
  ]

  @real_validations [
    Xaas.Operations.Validations.ApprovalK8sFaultRemediateSuggestRequiresApprover,
    Xaas.Platform.Validations.RouteSecretsRequiresApprover
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp lib_source(resource_or_filename) do
    "lib/xaas/"
    |> Path.expand()
    |> Path.join(resource_or_filename)
    |> File.read!()
  end

  defp camel_hits_outside_own_file(module) do
    symbol = module |> Module.split() |> List.last()
    own_file = module.module_info(:compile)[:source] |> to_string()

    Path.wildcard(Path.join(Path.expand("lib", File.cwd!()), "**/*.ex"))
    |> Enum.reject(&(Path.expand(&1) == Path.expand(own_file)))
    |> Enum.flat_map(fn path ->
      case String.contains?(File.read!(path), symbol) do
        true -> [path]
        false -> []
      end
    end)
  end

  defp k8s_request!(requested_by) do
    Xaas.Operations.ApprovalK8sFaultRemediateSuggest
    |> Ash.Changeset.for_create(:create, %{requested_by: requested_by}, authorize?: false)
    |> Ash.create!()
  end

  defp secret!(requested_by) do
    Xaas.Platform.RouteSecrets
    |> Ash.Changeset.for_create(:create, %{
      namespace: "w984iv-ns",
      name: "w984iv-secret-#{System.unique_integer([:positive])}",
      requested_by: requested_by
    })
    |> Ash.create!(authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # (1) Identity courts: all four *Approve changes are exact identities
  # ---------------------------------------------------------------------------

  test "(1) every *Approve change module is an identity: init passthrough + unchanged changeset" do
    for module <- @identity_changes do
      assert {:ok, []} = module.init([])

      opts = %{lane: "w984iv"}
      assert {:ok, ^opts} = module.init(opts)

      changeset =
        Xaas.Operations.ApprovalCastleVerbSchedule
        |> Ash.Changeset.for_create(:create, %{requested_by: "w984iv-approve-probe"},
          authorize?: false
        )

      assert ^changeset = module.change(changeset, [], %{})
      assert ^changeset = module.change(changeset, opts, %{context: :w984iv})
    end
  end

  # ---------------------------------------------------------------------------
  # (2) Identity court: the no-op validation always returns :ok
  # ---------------------------------------------------------------------------

  test "(2) identity validation module is an identity: init passthrough + :ok on real changesets" do
    for module <- @identity_validations do
      assert {:ok, []} = module.init([])

      opts = %{lane: "w984iv"}
      assert {:ok, ^opts} = module.init(opts)

      # :ok on an approver-less changeset AND on a populated one -- the
      # module's entire branch surface is a single :ok.
      for approved_by <- [nil, "w984iv-checker"] do
        changeset =
          Xaas.Operations.ApprovalCastleVerbSchedule
          |> Ash.Changeset.new()
          |> Ash.Changeset.change_attribute(:approved_by, approved_by)
          |> Ash.Changeset.for_create(:create, %{requested_by: "w984iv-validation-probe"},
            authorize?: false
          )

        assert :ok = module.validate(changeset, [], %{})
        assert :ok = module.validate(changeset, opts, %{context: :w984iv})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # (3) Real validation through live actions: k8s fault remediate suggest
  # ---------------------------------------------------------------------------

  test "(3a) k8s :approve with no approved_by is refused with the real message" do
    # Mutation rationale: kills deletion of the is_nil(approved_by)
    # refusal branch in ApprovalK8sFaultRemediateSuggestRequiresApprover.
    request = k8s_request!("w984iv-requester-a")

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             request
             |> Ash.Changeset.for_update(:approve, %{}, authorize?: false)
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "is required to approve a k8s fault remediation suggestion"
           end),
           "expected the missing-approver refusal, got: #{inspect(errors)}"
  end

  test "(3b) k8s :approve with an empty-string approved_by is refused" do
    # Mutation rationale: kills corruption of `approved_by == ""` into a
    # passing value (blank-string approver would satisfy presence
    # cosmetically while naming nobody).
    request = k8s_request!("w984iv-requester-b")

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: ""},
               authorize?: false
             )
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "is required to approve a k8s fault remediation suggestion"
           end),
           "expected the blank-approver refusal, got: #{inspect(errors)}"
  end

  test "(3c) k8s self-approval is refused with the maker-checker message" do
    # Mutation rationale: kills the maker-checker branch itself —
    # reverting to allow approved_by == requested_by would let a
    # requester sign their own remediation request.
    requester = "w984iv-self-#{System.unique_integer([:positive])}"
    request = k8s_request!(requester)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: requester},
               authorize?: false
             )
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "cannot approve their own k8s fault remediation suggestion"
           end),
           "expected the self-approval refusal, got: #{inspect(errors)}"
  end

  test "(3d) k8s distinct-approver happy path persists approved_by" do
    # Mutation rationale: kills corruption of the success branch (e.g.
    # validation refusing everything, or :approve dropping the accepted
    # attribute so approved_by never persists).
    request = k8s_request!("w984iv-requester-c")

    approved =
      request
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984iv-checker-c"},
        authorize?: false
      )
      |> Ash.update!()

    assert %{approved_by: "w984iv-checker-c"} = approved
    assert %{approved_by: "w984iv-checker-c"} = Ash.get!(Xaas.Operations.ApprovalK8sFaultRemediateSuggest, approved.id, authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # (4) Real validation through live actions: route secrets
  # ---------------------------------------------------------------------------

  test "(4a) route_secrets :approve with no approved_by is refused with the real message" do
    # Mutation rationale: kills deletion of the missing-approver refusal
    # branch in RouteSecretsRequiresApprover.
    secret = secret!("w984iv-requester-d")

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             secret
             |> Ash.Changeset.for_update(:approve, %{}, authorize?: false)
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "is required to approve a secret"
           end),
           "expected the missing-approver refusal, got: #{inspect(errors)}"
  end

  test "(4b) route_secrets self-approval is refused" do
    # Mutation rationale: kills the maker-checker distinct-actor branch.
    requester = "w984iv-self-d-#{System.unique_integer([:positive])}"
    secret = secret!(requester)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             secret
             |> Ash.Changeset.for_update(:approve, %{approved_by: requester},
               authorize?: false
             )
             |> Ash.update()

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "must be a second, distinct actor"
           end),
           "expected the self-approval refusal, got: #{inspect(errors)}"
  end

  test "(4c) route_secrets distinct-approver happy path persists approved_by" do
    # Mutation rationale: kills the success branch and proves the wired
    # RouteSecretsApprove change seam lets the action complete and the
    # accepted attribute persist (real end-to-end through the live
    # action, not a direct validate call).
    secret = secret!("w984iv-requester-e")

    approved =
      secret
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w984iv-checker-e"},
        authorize?: false
      )
      |> Ash.update!()

    assert %{approved_by: "w984iv-checker-e"} = approved
    assert %{approved_by: "w984iv-checker-e"} = Ash.get!(Xaas.Platform.RouteSecrets, approved.id, authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # (5) Wiring non-vacuity courts
  # ---------------------------------------------------------------------------

  test "(5a) wiring court: the real validations are wired on their live :approve actions" do
    # Mutation rationale: deleting the validate(...) line (or swapping it
    # to the identity shim) makes every refusal court above vacuous.
    assert lib_source("operations/approval_k8s_fault_remediate_suggest.ex") =~
             "validate(Xaas.Operations.Validations.ApprovalK8sFaultRemediateSuggestRequiresApprover)"

    assert lib_source("platform/route_secrets.ex") =~
             "validate(Xaas.Platform.Validations.RouteSecretsRequiresApprover)"

    assert lib_source("platform/route_secrets.ex") =~
             "change(Xaas.Platform.Changes.RouteSecretsApprove)"
  end

  test "(5b) unwired-invariant court: identity shims have no wiring site outside their own file" do
    # Multiline-safe CamelCase grep over lib/, excluding each module's
    # own file (W984er's multiline-wiring lesson: grep the bare CamelCase
    # symbol, not a line-anchored pattern). If one of these identity
    # no-ops is ever wired onto a real action, the no-op validation
    # would become a vacuous gate and the no-op change would silently
    # stand in for real behavior — this court flips and fails.
    for module <- [
          Xaas.Operations.Changes.CastleVerbFortune5RequirementsApprove,
          Xaas.Operations.Validations.CastleVerbFortune5RequirementsRequiresApprover,
          Xaas.Operations.Changes.ApprovalCastleVerbScheduleApprove,
          Xaas.Operations.Changes.ApprovalK8sFaultRemediateSuggestApprove
        ] do
      assert camel_hits_outside_own_file(module) == [],
             "identity shim #{inspect(module)} gained a wiring site outside its own file"
    end
  end

  test "(5c) unwired-invariant court: castle_verb_fortune5_requirements stays read-only" do
    # Mutation rationale: adding an :approve action without a real gate
    # would turn the unwired identity validation into a vacuous approval
    # gate on a new mutation surface.
    action_names =
      Xaas.Operations.CastleVerbFortune5Requirements
      |> Ash.Resource.Info.actions()
      |> Enum.map(& &1.name)

    assert Enum.sort(action_names) == [:read],
           "unexpected action surface: #{inspect(action_names)}"
  end

  # ---------------------------------------------------------------------------
  # (6) Boundary / typed-refusal courts through live actions + policies
  # ---------------------------------------------------------------------------

  test "(6a) k8s :create and :approve refuse a non-system actor (deny-by-default floor)" do
    # Mutation rationale: kills replacement of the SystemActor predicate
    # with bare always(), or deletion of the trailing forbid-all policy.
    request = k8s_request!("w984iv-requester-f")

    assert {:error, %Ash.Error.Forbidden{}} =
             Xaas.Operations.ApprovalK8sFaultRemediateSuggest
             |> Ash.Changeset.for_create(:create, %{requested_by: "w984iv-outsider"},
               actor: nil
             )
             |> Ash.create()

    assert {:error, %Ash.Error.Forbidden{}} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w984iv-checker-f"},
               actor: nil
             )
             |> Ash.update()
  end

  test "(6b) route_secrets :create and :approve refuse a non-system actor" do
    # Mutation rationale: same floor on the platform half of the batch.
    secret = secret!("w984iv-requester-g")

    assert {:error, %Ash.Error.Forbidden{}} =
             Xaas.Platform.RouteSecrets
             |> Ash.Changeset.for_create(:create, %{
               namespace: "w984iv-ns",
               name: "w984iv-forbidden",
               requested_by: "w984iv-outsider"
             })
             |> Ash.create()

    assert {:error, %Ash.Error.Forbidden{}} =
             secret
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w984iv-checker-g"})
             |> Ash.update()
  end

  test "(6c) castle_verb_fortune5_requirements read stays open to any actor (read bypass)" do
    # Mutation rationale: kills narrowing of the read bypass (which the
    # json_api GET/index routes depend on) without an explicit rule.
    {1, [%{id: raw_id}]} =
      Xaas.Repo.insert_all(
        "castle_verb_fortune5_requirements",
        [%{requested_by: "w984iv-floor"}],
        returning: [:id]
      )

    id = Ecto.UUID.cast!(raw_id)

    assert %{requested_by: "w984iv-floor"} =
             Ash.get!(Xaas.Operations.CastleVerbFortune5Requirements, id)
  end

  # ---------------------------------------------------------------------------
  # (7) Real-validation direct module pin (init surface)
  # ---------------------------------------------------------------------------

  test "(7) real validation modules accept arbitrary opts in init/1" do
    for module <- @real_validations do
      assert {:ok, []} = module.init([])
      assert {:ok, [lane: "w984iv"]} = module.init(lane: "w984iv")
    end
  end
end
