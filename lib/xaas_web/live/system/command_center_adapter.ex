defmodule XaasWeb.System.CommandCenterAdapter do
  @moduledoc """
  Read-only adapter folding REAL XaaS runtime state and the L4 Chicago
  projection into one deterministic read model for
  `XaasWeb.System.CommandCenterLive` (`/system`, R6: dev_routes block).

  ## What it reads (all observed in-session against real sandboxed rows)

    * `Xaas.Ultracode.Run` / `Xaas.Ultracode.Epoch` — via each resource's
      own documented `:read_unscoped` action (`authorize?: false` behind the
      dev-route trust boundary, same precedent as
      `XaasWeb.AutofdeLab.StatusLive`; the tenant-`:enforce`d primary reads
      are NOT bypassed — this adapter is the internal/system caller class
      those actions exist for).
    * `Xaas.Sa2a.Execution` / `Xaas.Ocel.Event` — default reads with
      `authorize?: false` (read-policy bypasses already exist on both).
    * `Xaas.Ultracode.Receipt` — ONLY through its own narrow lawful read
      path `:for_epoch` (the resource's deliberate carve-out; the bare
      `:read` action stays forbidden, unchanged).
    * `Xaas.Chicago` (R4, L4-owned) — `subject/0`, `layers/0`, `cases/0`,
      guarded by `Code.ensure_loaded?/1` so this lane stays compile- and
      runtime-safe while the projection has not landed; unavailability is a
      typed transport-outcome row, never a fabricated layer.

  ## Standing law (R8)

  Every AshSurface standing minted here is a validated evidence claim
  (`AshSurface.Standing.validate!/1` refuses `:UNKNOWN`) — the center and
  its observation carry `:PARTIAL_ALIVE` (real rows observed, subject-level
  claim still candidate). Layer standing / status stays `UNKNOWN` in plain
  projection maps until a real receipt binds observed execution, and the
  Live renders those UNKNOWN rows as candidate/transport rows, never as
  AshSurface standings. This adapter performs ZERO mutations: no create,
  update, destroy, or bulk call exists in this module (grep-gated by
  `test/xaas/chicago/surface/command_center_adapter_test.exs`).

  ## Seam note

  The wave-2 dispatch names `Xaas.Ultracode.CourtReceipt` as a receipt
  source; live repository evidence shows that module is a plain receipt
  PRODUCER (`lib/xaas/ultracode/court_receipt.ex`, no `use Ash.Resource`),
  so the queryable receipt resource actually read here is
  `Xaas.Ultracode.Receipt` (the `Xaas.Ultracode` domain's receipt row).
  """

  alias AshSurface.{CommandCenter, Observation, Obligation, PlanningEpisode}
  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  @exact_subject "urn:chicago:agentic-payment:purchase-001"

  @row_limit 20
  @receipt_epoch_limit 5

  @planner_identity "Xaas.Ultracode.Reactor"

  @doc "The exact subject every projection in this lane binds to (R2/R4)."
  @spec exact_subject :: String.t()
  def exact_subject, do: @exact_subject

  @doc """
  One deterministic read-model map over the real current state.

  Two calls against identical database state produce an identical
  `command_center.state_digest` (facts are folded order-invariantly:
  counts, frequency maps, and sorted id arrays only). Any real state
  change flips the digest.
  """
  @spec snapshot() :: map()
  def snapshot do
    build(read_state(), chicago_projection())
  end

  @doc """
  Resolves the R4 projection values at runtime, compile-safe while
  `Xaas.Chicago` has not landed (L4 owns it). Returns
  `{:ok, %{subject:, layers:, cases:}}` or
  `{:refused, {code, reason}}` — never raises into the render path and
  never fabricates a layer.
  """
  def chicago_projection do
    if Code.ensure_loaded?(Xaas.Chicago) and function_exported?(Xaas.Chicago, :layers, 0) do
      with {:ok, subject} <- Xaas.Chicago.subject(),
           {:ok, layers} <- Xaas.Chicago.layers(),
           {:ok, cases} <- Xaas.Chicago.cases() do
        {:ok, %{subject: subject, layers: layers, cases: cases}}
      end
    else
      {:refused, {:chicago_projection_unavailable, :projection_not_rendered}}
    end
  end

  @doc """
  Pure fold from real state rows + a `chicago_projection/0` result to the
  snapshot map. Public so tests drive it with model-shaped inputs.
  """
  def build(state, projection) do
    layers = layers_from(projection)
    cases = cases_from(projection)
    transport = transport_rows(projection, state)
    obligations = obligations_from_layers(layers)
    episodes = Enum.map(state.runs, &planning_episode_for_run/1)
    capabilities = capabilities(layers, state.executions)
    receipt_rows = Enum.map(state.receipts, &receipt_row/1)
    refusal_rows = refusals(state)
    unknown_rows = unknowns(layers, transport)

    receipt_refs =
      state.receipts |> Enum.map(& &1.id) |> Enum.sort() |> Enum.uniq()

    facts = facts(state, layers)

    observation =
      Observation.create(@exact_subject, facts,
        standing: :PARTIAL_ALIVE,
        evidence_refs: receipt_refs,
        projection_purpose: "chicago_command_center_state_snapshot",
        # Deterministic observed-at: the newest REAL timestamp carried by the
        # observed rows (epoch fallback when the snapshot is empty), so two
        # reads of identical state mint byte-identical observations and the
        # state_digest is stable — wall-clock never leaks into the digest.
        observed_at: observed_at(state)
      )

    center =
      CommandCenter.create(@exact_subject,
        observations: [observation],
        obligations: obligations,
        planning_episodes: episodes,
        capabilities: capabilities,
        receipt_refs: receipt_refs,
        standing: :PARTIAL_ALIVE
      )

    %{
      exact_subject: @exact_subject,
      chicago: projection,
      transport: transport,
      command_center: center,
      layers: layers,
      cases: cases,
      runs: Enum.map(state.runs, &run_row/1),
      epochs: Enum.map(state.epochs, &epoch_row/1),
      executions: Enum.map(state.executions, &execution_row/1),
      receipts: receipt_rows,
      refusals: refusal_rows,
      unknowns: unknown_rows,
      ocel_events: Enum.map(state.ocel_events, &ocel_row/1),
      answers:
        answers(state, layers, obligations, episodes, capabilities, refusal_rows, unknown_rows)
    }
  end

  @doc """
  Maps normalized Chicago layers (R2 field names, atom- or string-keyed) to
  OBSERVE-only `AshSurface.Obligation` structs: one open evidence obligation
  per required layer. Obligation identity is stable across key casing
  (id = digest of subject + capability_id + cause_ref). Obligations stay
  `:open` — candidate predictions until a real receipt binds (R8).
  """
  def obligations_from_layers(layers) do
    layers
    |> Enum.filter(&required_layer?/1)
    |> Enum.map(fn layer ->
      cause_ref = "chicago:layer:" <> layer.id

      Obligation.create(@exact_subject, layer.capability_id, cause_ref,
        status: :open,
        evidence_refs: layer.evidence_refs,
        receipt_ref: first_ref(layer.receipt_refs)
      )
    end)
  end

  defp first_ref([first | _]), do: first
  defp first_ref([]), do: nil

  @doc """
  Maps a real `Xaas.Ultracode.Run` to an `AshSurface.PlanningEpisode` with
  `authority_ceiling: :SELECT` (planning is never DO).

  Honest mapping, documented: the planner identity is the real pipeline
  module that advances Run cycles; `policy_identity` is the Run's real
  `execution_policy` attribute; the policy standing is `:VALID_STRONG` only
  for a terminal `:completed` Run with `:admitted` standing, `:REFUSED` for
  a `:refused` Run, and `:VALID_STRONG_CYCLIC` otherwise — an in-flight Run
  IS an unrolled strong-cyclic epoch loop, and nothing here promotes a
  candidate (R8).
  """
  def planning_episode_for_run(run) do
    policy_standing =
      cond do
        run.standing == :refused -> :REFUSED
        run.standing == :admitted and run.state == :completed -> :VALID_STRONG
        true -> :VALID_STRONG_CYCLIC
      end

    policy_identity =
      if is_atom(run.execution_policy) and not is_nil(run.execution_policy) do
        "execution_policy:" <> to_string(run.execution_policy)
      else
        "execution_policy:unspecified"
      end

    world_state_ref =
      "xaas:run:" <> run.id <> ":frontier:" <> (run.frontier_digest || "none")

    PlanningEpisode.create(world_state_ref,
      planner_identity: @planner_identity,
      policy_identity: policy_identity,
      policy_standing: policy_standing,
      candidate_actions: [],
      authority_ceiling: :SELECT
    )
  end

  ## Real reads (dev-route trust boundary, no mutation)

  defp read_state do
    runs =
      Run
      |> Ash.Query.sort(inserted_at: :desc, id: :desc)
      |> Ash.Query.limit(@row_limit)
      |> Ash.read!(action: :read_unscoped, authorize?: false)

    epochs =
      Epoch
      |> Ash.Query.sort(inserted_at: :desc, id: :desc)
      |> Ash.Query.limit(@row_limit)
      |> Ash.read!(action: :read_unscoped, authorize?: false)

    executions =
      Xaas.Sa2a.Execution
      |> Ash.Query.sort(inserted_at: :desc, id: :desc)
      |> Ash.Query.limit(@row_limit)
      |> Ash.read!(authorize?: false)

    ocel_events =
      Xaas.Ocel.Event
      |> Ash.Query.sort(occurred_at: :desc, id: :desc)
      |> Ash.Query.limit(@row_limit)
      |> Ash.read!(authorize?: false)

    {receipts, transport} = receipts_for_recent_epochs(epochs)

    %{
      runs: runs,
      epochs: epochs,
      executions: executions,
      ocel_events: ocel_events,
      receipts: receipts,
      extra_transport: transport
    }
  end

  defp receipts_for_recent_epochs(epochs) do
    epochs
    |> Enum.take(@receipt_epoch_limit)
    |> Enum.reduce({[], []}, fn epoch, {receipts, transport} ->
      case Receipt.for_epoch(epoch.id) do
        {:ok, rows} ->
          {receipts ++ rows, transport}

        {:error, error} ->
          {receipts,
           transport ++
             [
               %{
                 component: "receipts:epoch:" <> epoch.id,
                 outcome: :refused,
                 reason: inspect(error)
               }
             ]}
      end
    end)
  end

  ## Projection normalization (R2 field names, atom- or string-keyed maps)

  defp layers_from({:ok, %{layers: layers}}) when is_list(layers),
    do: Enum.map(layers, &normalize_layer/1)

  defp layers_from(_), do: []

  defp cases_from({:ok, %{cases: cases}}) when is_list(cases),
    do: Enum.map(cases, &normalize_case/1)

  defp cases_from(_), do: []

  defp normalize_layer(layer) do
    id = to_string(f2(layer, :id, :id) || "unknown-layer")

    %{
      id: id,
      label: f2(layer, :label, :label) || id,
      capability_id: f2(layer, :capabilityId, :capability_id) || "chicago:layer:" <> id,
      status: to_string(f2(layer, :status, :status) || "UNKNOWN"),
      boundary_class: f2(layer, :boundaryClass, :boundary_class),
      authority_ceiling: f2(layer, :authorityCeiling, :authority_ceiling),
      evidence_refs: to_list(f2(layer, :evidenceRefs, :evidence_refs)),
      receipt_refs: to_list(f2(layer, :receiptRefs, :receipt_refs)),
      required: f2(layer, :required, :required)
    }
  end

  defp normalize_case(kase) do
    %{
      id: to_string(f2(kase, :id, :id)),
      label: f2(kase, :label, :label),
      candidate_only: f2(kase, :candidateOnly, :candidate_only),
      authority_claim: f2(kase, :authorityClaim, :authority_claim),
      observed_standing: to_string(f2(kase, :observedStanding, :observed_standing) || "UNKNOWN")
    }
  end

  defp required_layer?(layer) do
    layer.required not in [false, "false", nil]
  end

  # Reads a field under its R2 camelCase or snake_case key.
  defp f2(map, camel, snake) when is_map(map) do
    case Map.fetch(map, camel) do
      {:ok, value} ->
        value

      :error ->
        Map.get(
          map,
          snake,
          Map.get(map, Atom.to_string(camel), Map.get(map, Atom.to_string(snake)))
        )
    end
  end

  defp to_list(nil), do: []
  defp to_list(list) when is_list(list), do: list
  defp to_list(other), do: [other]

  ## Transport-outcome rows (where UNKNOWN renders — never an AshSurface standing)

  defp transport_rows(projection, state) do
    projection_transport =
      case projection do
        {:ok, _} ->
          []

        {:refused, {code, reason}} ->
          [
            %{
              component: "chicago_projection",
              outcome: :unavailable,
              reason: inspect({code, reason})
            }
          ]

        other ->
          [
            %{component: "chicago_projection", outcome: :refused, reason: inspect(other)}
          ]
      end

    projection_transport ++ state.extra_transport
  end

  ## Row mappers

  defp run_row(run) do
    %{
      id: run.id,
      goal: run.goal,
      state: to_string(run.state),
      standing: to_string(run.standing),
      provider: run.provider,
      cycle: run.cycle,
      max_cycles: run.max_cycles,
      capability_id: run.capability_id,
      execution_policy: run.execution_policy && to_string(run.execution_policy),
      inserted_at: run.inserted_at
    }
  end

  defp epoch_row(epoch) do
    %{
      id: epoch.id,
      run_id: epoch.run_id,
      cycle: epoch.cycle,
      exact_subject: epoch.exact_subject,
      state: to_string(epoch.state),
      leased_to: epoch.leased_to,
      final_head: epoch.final_head,
      inserted_at: epoch.inserted_at
    }
  end

  defp execution_row(execution) do
    %{
      id: execution.id,
      work_order_id: execution.work_order_id,
      class_id: execution.class_id,
      capability: execution.capability,
      result: execution.result,
      replay_verified: execution.replay_verified,
      manifest_hash: execution.manifest_hash,
      llm_avoidance_ratio: execution.llm_avoidance_ratio,
      inserted_at: execution.inserted_at
    }
  end

  defp receipt_row(receipt) do
    %{
      id: receipt.id,
      epoch_id: receipt.epoch_id,
      subject: receipt.subject,
      outcome: to_string(receipt.outcome),
      reason: Map.get(receipt.evidence || %{}, "reason"),
      sealed_at: receipt.sealed_at
    }
  end

  defp ocel_row(event) do
    %{
      id: event.id,
      event_type: event.event_type,
      ocel_id: event.ocel_id,
      occurred_at: event.occurred_at
    }
  end

  ## Question folds

  defp refusals(state) do
    receipt_refusals =
      state.receipts
      |> Enum.filter(&(&1.outcome == :refused))
      |> Enum.map(fn receipt ->
        %{
          source: "receipt",
          id: receipt.id,
          subject: receipt.subject,
          reason:
            case Map.get(receipt.evidence || %{}, "reason") do
              reason when is_binary(reason) -> reason
              _ -> "receipt outcome :refused"
            end,
          at: receipt.sealed_at
        }
      end)

    run_refusals =
      state.runs
      |> Enum.filter(&(&1.standing == :refused))
      |> Enum.map(fn run ->
        %{
          source: "run",
          id: run.id,
          subject: run.goal,
          reason: "run standing :refused",
          at: nil
        }
      end)

    receipt_refusals ++ run_refusals
  end

  defp unknowns(layers, transport) do
    layer_unknowns =
      layers
      |> Enum.filter(&(&1.status == "UNKNOWN"))
      |> Enum.map(fn layer ->
        %{
          kind: "layer",
          id: layer.id,
          reason: "no real receipt binds observed execution (R8: standing stays UNKNOWN)"
        }
      end)

    transport_unknowns =
      Enum.map(transport, fn row ->
        %{kind: "transport", id: row.component, reason: row.reason}
      end)

    layer_unknowns ++ transport_unknowns
  end

  defp capabilities(layers, executions) do
    layer_capabilities =
      Enum.map(layers, fn layer ->
        %{
          id: layer.capability_id,
          layer_id: layer.id,
          origin: "chicago_projection",
          admitted?: false,
          executions: 0
        }
      end)

    observed_capabilities =
      executions
      |> Enum.frequencies_by(& &1.capability)
      |> Enum.map(fn {capability, count} ->
        %{
          id: capability,
          layer_id: nil,
          origin: "sa2a_execution_observed",
          admitted?: false,
          executions: count
        }
      end)

    layer_capabilities ++ observed_capabilities
  end

  # "Admitted" is receipt-backed: a capability counts as admitted only when
  # a real sealed receipt for the exact subject with outcome :alive exists.
  # Until then the count is honestly 0 (R8).
  defp answers(state, layers, obligations, episodes, capabilities, refusal_rows, unknown_rows) do
    alive_subject_receipt? =
      Enum.any?(state.receipts, &(&1.outcome == :alive and &1.subject == @exact_subject))

    %{
      "what_exists" => length(layers),
      "what_running" =>
        Enum.count(state.runs, &(&1.state == :running)) +
          Enum.count(state.epochs, &(&1.state == :running)),
      "obligations" => length(obligations),
      "capabilities_admitted" =>
        if(alive_subject_receipt? and capabilities != [], do: length(capabilities), else: 0),
      "plans" => length(episodes),
      "executed" =>
        length(state.executions) + Enum.count(state.epochs, &(&1.state == :completed)),
      "refused" => length(refusal_rows),
      "unknown" => length(unknown_rows),
      "receipts" => length(state.receipts),
      "ocel_evidence" => length(state.ocel_events),
      "standing_per_claim" => length(layers),
      "replayable" => Enum.count(state.executions, & &1.replay_verified)
    }
  end

  # The observation facts: real state folded ORDER-INVARIANTLY (counts,
  # frequency maps, sorted id arrays) so identical state yields an identical
  # observation digest, and any state change flips it.
  defp facts(state, layers) do
    %{
      "run_ids" => state.runs |> Enum.map(& &1.id) |> Enum.sort(),
      "runs_by_state" => frequencies(state.runs, & &1.state),
      "epoch_ids" => state.epochs |> Enum.map(& &1.id) |> Enum.sort(),
      "epochs_by_state" => frequencies(state.epochs, & &1.state),
      "execution_ids" => state.executions |> Enum.map(& &1.id) |> Enum.sort(),
      "executions_by_replay" => frequencies(state.executions, & &1.replay_verified),
      "receipt_ids" => state.receipts |> Enum.map(& &1.id) |> Enum.sort(),
      "receipts_by_outcome" => frequencies(state.receipts, & &1.outcome),
      "ocel_event_ids" => state.ocel_events |> Enum.map(& &1.id) |> Enum.sort(),
      "layer_ids" => layers |> Enum.map(& &1.id) |> Enum.sort()
    }
  end

  defp frequencies(rows, key_fn) do
    rows
    |> Enum.frequencies_by(&(key_fn.(&1) |> to_string()))
  end

  # Newest real timestamp across the observed rows; ~U[1970-01-01...] when
  # the snapshot observed nothing. Never wall-clock (see build/2).
  defp observed_at(state) do
    [
      Enum.map(state.runs, & &1.inserted_at),
      Enum.map(state.epochs, & &1.inserted_at),
      Enum.map(state.receipts, & &1.sealed_at),
      Enum.map(state.ocel_events, & &1.occurred_at)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> ~U[1970-01-01 00:00:00.000000Z]
      times -> Enum.max(times)
    end
  end
end
