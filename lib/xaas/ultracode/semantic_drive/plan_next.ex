defmodule Xaas.Ultracode.SemanticDrive.PlanNext do
  @moduledoc """
  plan-next (lane X3): after a promoted standing transition, ONE real
  `AshA2A.Replan.Loop` run whose FOND PolicyCandidate is journaled --
  emitted, never auto-admitted (authority `:none`, standing `:candidate`).

  The domain is the graph side's own standing progression
  (`GgenIgniter.SemanticJira`'s one-step law UNKNOWN -> PARTIAL_ALIVE ->
  ALIVE), restricted to the tail starting at the event's `to` standing.
  States are STANDINGS, not work orders. The single action `:promote` may
  stick -- courts and evidence may refuse a promote -- so a domain with a
  promote transition validates only under `:strong_cyclic` semantics; a
  transition whose `to` already sits on the goal admits the (empty) policy
  under `:strong`.

  Everything here is PURE: no `File`, no `Process`, no socket, in
  `domain/1` or anywhere on `plan/2`'s path. Journaling happens only
  through the caller's artifact channel (the drive writes
  `plan_next.json`); the OCEL event is the drive's, on success only.
  """

  @schema "xaas/semantic-drive-plan-next/v1"
  @domain_source "standing_progression_projection/1"
  @action :promote
  @goals [:ALIVE]
  @ports [{"ash_pplan", AshA2A.Replan.Port.AshPPlan}]

  # The graph side's standings (`GgenIgniter.SemanticJira.standings/0`)
  # and its one-step progression chain; the atom lookup is FIXED at
  # compile time, never `String.to_atom/1`.
  @chain [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE]
  @atoms %{
    "UNKNOWN" => :UNKNOWN,
    "PARTIAL_ALIVE" => :PARTIAL_ALIVE,
    "ALIVE" => :ALIVE,
    "BLOCKED" => :BLOCKED,
    "BUILD_BROKEN" => :BUILD_BROKEN,
    "UNSUPPORTED" => :UNSUPPORTED
  }

  # The source-event fields every journal doc carries for provenance.
  # `plan/2` uses only `identity` / `from` / `to`; the rest ride along.
  @source_fields ~w(identity definition_digest snapshot_digest from to receipt_digest
                    transition_digest authority event_digest)

  @type standing :: String.t()

  @doc "The journal document schema (`xaas/semantic-drive-plan-next/v1`)."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "The domain provenance marker recorded on every journal doc."
  @spec domain_source() :: String.t()
  def domain_source, do: @domain_source

  @doc """
  The standing-progression FOND domain of a promoted standing transition.

    * `from = "UNKNOWN", to = "PARTIAL_ALIVE"` -- states `{PARTIAL_ALIVE,
      ALIVE}`, every non-goal state promotes (the promote may stick), the
      initial state is `PARTIAL_ALIVE`;
    * `from = "PARTIAL_ALIVE", to = "ALIVE"` -- the initial state is the
      goal;
    * `to` in `BLOCKED` / `BUILD_BROKEN` / `UNSUPPORTED`, or a standing
      string that is not a standing at all -- `{:refused,
      :standing_not_progressable}`, never a crash.
  """
  @spec domain(map()) :: {:ok, AshPPlan.FOND.t()} | {:refused, :standing_not_progressable}
  def domain(event) when is_map(event) do
    case progression(event) do
      {:ok, {domain, _mode}} -> {:ok, domain}
      {:refused, reason} -> {:refused, reason}
    end
  end

  @doc """
  Runs the one replan loop over the standing-progression domain of
  `event` (a standing-transition event: `identity`, `from`, `to`, plus the
  source provenance fields) and returns the journal document as
  `{:ok, doc}` in BOTH outcomes -- a planning failure is an observation,
  never a refusal of the caller:

    * success -- `doc` carries the source event fields, the rendered
      domain (`domain_source` = `standing_progression_projection/1`), the
      full loop result (provider, candidate, attempt, excluded,
      replay_key) and the `policy_binding_digest`; `"emitted"` is true
      (the drive's cue to journal the OCEL event);
    * refusal -- `doc` records `REFUSED(standing_not_progressable)` with
      `"emitted"` false and no loop/candidate claim.

  Pure: the returned document is data; writing it is the caller's act.
  """
  @spec plan(map(), keyword()) :: {:ok, map()}
  def plan(event, _opts \\ []) when is_map(event) do
    case progression(event) do
      {:refused, reason} ->
        {:ok,
         event
         |> Map.take(@source_fields)
         |> Map.merge(%{
           "schema" => @schema,
           "domain_source" => @domain_source,
           "standing" => "REFUSED(standing_not_progressable)",
           "reason" => Atom.to_string(reason),
           "broken_term" => "mu_on_O",
           "emitted" => false
         })}

      {:ok, {domain, _mode}} ->
        initial = Map.fetch!(@atoms, event["to"])
        subject = event["identity"]
        ensure_ports()

        case AshA2A.Replan.Loop.run(
               subject,
               %{formalism: :fond, domain: domain, initial: initial},
               @ports,
               max_attempts: 3
             ) do
          {:ok, result} ->
            {:ok, success_doc(event, domain, initial, result)}

          {:error, failure} ->
            {:ok,
             event
             |> Map.take(@source_fields)
             |> Map.merge(%{
               "schema" => @schema,
               "domain_source" => @domain_source,
               "standing" => "REFUSED(plan_next_loop_failed)",
               "reason" => "plan_next_loop_failed",
               "broken_term" => "mu_on_O",
               "failure" => jsonable(failure),
               "emitted" => false
             })}
        end
    end
  end

  # -- the standing-progression projection --------------------------------------

  # `AshA2A.Replan.ProviderSet.select/3` admits a provider only when its
  # module is LOADED (`function_exported?/3`), so the ports are loaded
  # before the loop runs -- loading code is not an actuation.
  defp ensure_ports do
    Enum.each(@ports, fn {_id, mod} -> Code.ensure_loaded?(mod) end)
  end

  # {:ok, {%AshPPlan.FOND{}, mode}} | {:refused, :standing_not_progressable}.
  # Mode: the promote may stick (its outcomes include the state itself), so
  # any domain with a promote transition is :strong_cyclic; a `to` already
  # on the goal has no transitions and admits the empty policy :strong.
  defp progression(event) do
    with {:ok, to} <- standing(event["to"]),
         {:ok, _from} <- standing(event["from"]),
         :ok <- progressable(to) do
      tail = Enum.drop_while(@chain, &(&1 != to))

      transitions =
        tail
        |> Enum.reject(&(&1 in @goals))
        |> Map.new(&{&1, %{@action => [next(&1), &1]}})

      mode = if transitions == %{}, do: :strong, else: :strong_cyclic

      case AshPPlan.FOND.new(transitions, @goals) do
        {:ok, domain} -> {:ok, {domain, mode}}
        {:error, _} -> {:refused, :standing_not_progressable}
      end
    end
  end

  defp next(state), do: @chain |> Enum.drop_while(&(&1 != state)) |> Enum.at(1)

  defp standing(value) when is_binary(value) do
    case Map.fetch(@atoms, value) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:refused, :standing_not_progressable}
    end
  end

  defp standing(_other), do: {:refused, :standing_not_progressable}

  defp progressable(state) when state in @chain, do: :ok
  defp progressable(_other), do: {:refused, :standing_not_progressable}

  # -- the journal docs -----------------------------------------------------------

  defp success_doc(event, domain, initial, result) do
    transitions = domain.transitions
    goals = domain.goals |> MapSet.to_list() |> Enum.sort()
    candidate = result.candidate

    event
    |> Map.take(@source_fields)
    |> Map.merge(%{
      "schema" => @schema,
      "domain_source" => @domain_source,
      "standing" => "CANDIDATE",
      "emitted" => true,
      "domain" => %{
        "transitions" => jsonable(transitions),
        "initial" => Atom.to_string(initial),
        "goals" => Enum.map(goals, &Atom.to_string/1)
      },
      "loop" => %{
        "provider" => result.provider,
        "candidate" => jsonable(candidate),
        "attempt" => result.attempt,
        "excluded" => result.excluded,
        "replay_key" => result.replay_key
      },
      "policy_binding_digest" =>
        policy_binding_digest({event, transitions, initial, goals, candidate})
    })
  end

  # sha256 over the deterministic external term format of the FULL binding
  # (event, domain transitions, initial, goals, candidate) -- the no-drift
  # fingerprint of what was journaled.
  defp policy_binding_digest(binding) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(binding, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  # The JSON-able rendering: atoms -> strings, MapSets -> sorted lists,
  # tuples -> lists, structs -> maps, keys stringified. The candidate map
  # itself is carried FULL -- only its shape is rendered.
  defp jsonable(%MapSet{} = set), do: set |> MapSet.to_list() |> Enum.sort() |> jsonable()
  defp jsonable(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp jsonable(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> jsonable()

  defp jsonable(%_struct{} = value) do
    value |> Map.from_struct() |> jsonable()
  end

  defp jsonable(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key_string(key), jsonable(value)} end)
  end

  defp jsonable(list) when is_list(list), do: Enum.map(list, &jsonable/1)
  defp jsonable(value), do: value

  defp key_string(key) when is_binary(key), do: key
  defp key_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_string(key), do: to_string(key)
end
