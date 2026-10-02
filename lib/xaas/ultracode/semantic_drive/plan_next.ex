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
  `domain/1`, anywhere on `plan/2`'s path, or in `to_work_order/2`.
  `admit/2` adds only the bridge's in-process kernel admission
  (`SemanticJira.admit_work_order/1` + optional SHACL), itself pure: the
  beam-level purity falsifier in the test suite holds for the whole module.
  Journaling happens only through the caller's artifact channel (the drive
  writes `plan_next.json`); the OCEL event is the drive's, on success only.

  ## The bounded consumption seam (default-OFF)

  `admit/2` is the opt-in consumption seam; **the drive does not call
  it** -- the drive's `:plan_next` step stays journal-only (a CANDIDATE is
  emitted, never auto-admitted). A caller opts in per document:
  `to_work_order/2` derives the kernel-shaped `sj:WorkOrder` from the
  journaled candidate and its source event, refusing
  `{:refused, :candidate_underdetermined, missing}` whenever a required
  field has no honest source; `admit/2` feeds the result to
  `Xaas.Ultracode.SemanticJiraBridge.admit_candidate/2`. The refusal list
  is the anti-auto-admission fence: nothing is defaulted in, so an
  underdetermined candidate can only ever be observed, never admitted.
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
  # `base_sha` and `repository` ride along for the bounded consumption seam
  # (`to_work_order/2`): the drive's `plan_next_event/1` now passes
  # `ctx.order["base_sha"]` / `ctx.order["repository"]` so the candidate's
  # source snapshot context is journaled with the candidate.
  @source_fields ~w(identity definition_digest snapshot_digest from to receipt_digest
                    transition_digest authority event_digest base_sha repository)

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

  # -- the bounded consumption seam (default-OFF) --------------------------------

  @seam_ceiling "repository-local"

  @doc """
  Derives an admittable `sj:WorkOrder` map from a CANDIDATE journal doc
  (the document `plan/2` emits with `"standing" => "CANDIDATE"`), in the
  duck-typed shape `Xaas.Ultracode.SemanticJiraBridge.admit_candidate/2`
  consumes (the kernel's `admit_work_order/1` contract).

  Derivation table (journal-doc field -> work-order field):

    * `identity` -> `identity` -- the event's identity (`ctx.order_id`):
      the work order the event already names. `planner_subject.id` is the
      POLICY COURT's content identity (domain x policy x initial x mode);
      binding it as the order identity would conflate court identity with
      work identity and move on every replan, so it is carried as
      `subject` instead.
    * `loop.candidate.planner_subject.id` -> `subject` -- the exact
      subject binding of the policy court.
    * `repository` / `base_sha` (source event's snapshot context, now
      journaled) -> verbatim; the kernel validates the `owner/name` and
      40-hex formats.
    * standing -> `"UNKNOWN"` -- fixed. A freshly derived order starts at
      the graph's own one-step progression origin.
    * `evidence_ceiling` -> `"repository-local"` -- fixed, the fabric
      evidence ceiling (the bridge's documented ceiling: fabric-only
      evidence tops out there).
    * `domain.initial` + `domain.goals` -> `promotion_rule` -- the
      standing-progression one-step law the domain projects.
    * `loop.replay_key` -> `replay_identity` -- the Loop's replay key.
    * `loop.candidate.validation` (a real FOND validation report) ->
      `required_courts` = `["fond_policy_validation"]`.
    * `policy_binding_digest` + `loop.replay_key` -> `required_evidence`.
    * `loop.candidate.planner_subject.id` -> `acceptance` -- the planner
      subject re-binds to the same exact identity.
    * `domain.initial` / `domain.goals` / `mode` / `loop.candidate.attempts`
      -> `falsifiers` -- the core court falsifier plus every failed planner
      attempt the PolicySwitch already falsified on the way to the
      admitted mode.
    * `loop.candidate.formalism` -> `projections` = `["fond"]` (`:fond`
      candidates only).
    * `opts[:origin_authority]` -> `origin_authority` -- BIND AT THE SEAM,
      never derived. The journal doc carries `authority` `"NONE"`, which is
      not an origin (SJ-002: work orders originate only from an admitted
      `sj:CodeWorkAuthority`), so the caller must name the admitted
      authority explicitly; absent, the order is underdetermined.

  Returns `{:ok, work_order}` or
  `{:refused, :candidate_underdetermined, missing}` where `missing` names
  every field with no honest source (dotted paths). Pure: no `File`, no
  socket, no authority.
  """
  @spec to_work_order(map(), keyword()) ::
          {:ok, map()} | {:refused, :candidate_underdetermined, [String.t()]}
  def to_work_order(journal_doc, opts \\ []) when is_map(journal_doc) do
    loop = map_part(journal_doc["loop"])
    candidate = map_part(loop && loop["candidate"])
    domain = map_part(journal_doc["domain"])
    validation = candidate && map_part(candidate["validation"])
    planner = candidate && map_part(candidate["planner_subject"])

    mode = text(candidate && candidate["mode"])
    formalism = text(candidate && candidate["formalism"])
    attempts = candidate && candidate["attempts"]

    replay_key = loop && loop["replay_key"]
    binding_digest = journal_doc["policy_binding_digest"]

    initial = text(domain && domain["initial"])
    goals = text_list(domain && domain["goals"])
    planner_id = text(planner && planner["id"])

    origin_authority = Keyword.get(opts, :origin_authority)

    missing =
      for {path, value} <- [
            {"identity", text(journal_doc["identity"])},
            {"standing=CANDIDATE", if(journal_doc["standing"] == "CANDIDATE", do: "CANDIDATE")},
            {"loop.candidate", candidate},
            {"loop.candidate.subject", text(candidate && candidate["subject"])},
            {"loop.candidate.mode", mode},
            {"loop.candidate.formalism=fond", if(formalism == "fond", do: formalism)},
            {"loop.candidate.validation", valid_report?(validation)},
            {"loop.candidate.planner_subject.id", planner_id},
            {"loop.candidate.attempts", if(is_list(attempts), do: :ok)},
            {"domain.initial", initial},
            {"domain.goals", nonempty(goals) && goals},
            {"repository", text(journal_doc["repository"])},
            {"base_sha", text(journal_doc["base_sha"])},
            {"loop.replay_key", text(replay_key)},
            {"policy_binding_digest", text(binding_digest)},
            {"origin_authority", text(origin_authority)}
          ],
          blank?(value),
          do: path

    missing = Enum.sort(missing)

    if missing != [] do
      {:refused, :candidate_underdetermined, missing}
    else
      attempts_text =
        attempts
        |> Enum.map(fn attempt -> "falsified planner attempt: " <> inspect(attempt) end)

      falsifiers =
        [
          "AshPPlan.FOND.validate_policy/4 refuses the candidate policy from " <>
            "initial=#{initial} under mode=#{mode} (goals=#{Enum.join(goals, ", ")})"
        ]
        ++ attempts_text

      {:ok,
       %{
         "identity" => journal_doc["identity"],
         "title" => "plan-next FOND policy candidate (#{mode})",
         "description" =>
           "journaled PolicyCandidate from the plan-next standing-progression loop " <>
             "(replay_key=#{replay_key}, policy_binding_digest=#{binding_digest})",
         "subject" => planner_id,
         "repository" => journal_doc["repository"],
         "base_sha" => journal_doc["base_sha"],
         "standing" => "UNKNOWN",
         "evidence_ceiling" => @seam_ceiling,
         "promotion_rule" =>
           "promote from #{initial} toward #{Enum.join(goals, ", ")} per the " <>
             "standing-progression one-step law (UNKNOWN -> PARTIAL_ALIVE -> ALIVE)",
         "replay_identity" => replay_key,
         "required_courts" => ["fond_policy_validation"],
         "required_evidence" => [
           "policy_binding_digest:#{binding_digest}",
           "replay_key:#{replay_key}"
         ],
         "acceptance" => ["planner subject re-binds to the exact identity #{planner_id}"],
         "falsifiers" => falsifiers,
         "projections" => ["fond"],
         "origin_authority" => origin_authority
       }}
    end
  end

  @doc """
  The opt-in consumption seam: derives the work order (`to_work_order/2`)
  and feeds it to `Xaas.Ultracode.SemanticJiraBridge.admit_candidate/2`
  (kernel admission, plus SHACL when `opts[:shapes]` is given). Returns
  `{:ok, admitted}` (the kernel-normalized order carrying
  `work_order_digest` / `definition_digest`, authority `NONE`),
  `{:error, {:refused, :candidate_underdetermined, missing}}` for an
  underdetermined candidate, or `{:error, {:refused_bridge, reason}}` /
  `{:error, {:raised, message}}` for anything the kernel or the bridge
  refuses. NEVER raises.

  NOT called by the drive: the drive's `:plan_next` step journals the
  candidate and stops. This function exists so a bounded consumer (a court,
  an operator command, a future gated step) can admit a journaled candidate
  explicitly, one document at a time.
  """
  @spec admit(map(), keyword()) ::
          {:ok, map()}
          | {:error, {:refused, :candidate_underdetermined, [String.t()]}}
          | {:error, {:refused_bridge, term()}}
          | {:error, {:raised, String.t()}}
  def admit(journal_doc, opts \\ []) when is_map(journal_doc) do
    try do
      case to_work_order(journal_doc, opts) do
        {:refused, :candidate_underdetermined, missing} ->
          {:error, {:refused, :candidate_underdetermined, missing}}

        {:ok, work_order} ->
          bridge_opts = Keyword.take(opts, [:shapes])

          with {:ok, bridge} <- bridge() do
            case apply(bridge, :admit_candidate, [work_order, bridge_opts]) do
              {:ok, admitted} -> {:ok, admitted}
              {:error, reason} -> {:error, reason}
            end
          end
      end
    rescue
      error -> {:error, {:raised, Exception.message(error)}}
    end
  end

  # The bridge is conditionally compiled (the post-G1 guard on the pinned
  # ggen_igniter), so the seam dispatches dynamically: no compile-time
  # dependency, and a build whose dep drifted loses the seam with a typed
  # error instead of a compile failure.
  defp bridge do
    mod = Xaas.Ultracode.SemanticJiraBridge

    if Code.ensure_loaded?(mod) and function_exported?(mod, :admit_candidate, 2) do
      {:ok, mod}
    else
      {:error, {:bridge_unavailable, "post-G1 semantic-jira seam not compiled in"}}
    end
  end

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

  # -- seam derivation helpers (pure) ---------------------------------------------

  # A map part of a JSON-able journal doc: nil unless a plain map.
  defp map_part(value) when is_map(value) and not is_struct(value), do: value
  defp map_part(_), do: nil

  # A non-empty string, else nil.
  defp text(value) when is_binary(value), do: if(value == "", do: nil, else: value)
  defp text(_), do: nil

  # A non-empty list of non-empty strings, else nil.
  defp text_list(value) do
    if is_list(value) and value != [] and Enum.all?(value, &is_binary/1) and
         Enum.all?(value, &(&1 != "")) do
      value
    else
      nil
    end
  end

  defp nonempty(list) when is_list(list), do: list != []
  defp nonempty(_), do: false

  # The kernel's own blank vocabulary: a present value is one that is not
  # nil / "" / [].
  defp blank?(value), do: value in [nil, "", []]

  # A validation report honestly usable as a required-court source: a plain
  # non-empty map.
  defp valid_report?(value) when is_map(value) and not is_struct(value) do
    value != %{}
  end

  defp valid_report?(_), do: nil
end
