defmodule Mix.Tasks.Xaas.Replay do
  @shortdoc "Cold replay of a recorded episode: subject, evidence, standing, completed work, frontier (GC23-10)"

  @moduledoc """
  Cold replay of a recorded no-LLM episode (lane V23-R; GC-26.9.23 gate
  GC23-10; PRD PR-013; ARD sections 7 and 16; falsifiers F5, F6).

      mix xaas.replay --episode docs/sjira/v26.9.23/episodes/fmt-1 \\
        --ggen-igniter-dir DIR --out STATE.json \\
        [--subject-repo DIR] [--subject-ref REF] [--ggen-build-path DIR] [--scratch DIR]

  Reconstructs subject identity, evidence, standing, completed work and the
  current frontier from the episode's sealed receipts, its TransitionLog, its
  work graph and git refs only (`Xaas.Ultracode.SemanticReplay`), with every
  graph-side step a real `mix semantic_jira.*` / `mix run
  scripts/semantic_replay_task.exs` OS process in `--ggen-igniter-dir`
  (private `MIX_BUILD_PATH`), and writes `--out` as canonical JSON (keys
  sorted, compact): `{"schema", "replay", "digest", "state", "sources",
  "graph_side", "committed"}`, `digest` = sha256 of the canonical JSON of
  `state`.

  The no-LLM guard (F3) runs first, before anything is read, and fails
  closed (`SemanticDrive.no_llm_guard/1` over `priv/no_llm/policy.json`): a
  provider-claimed variable or a provider executable on `PATH` is
  `REFUSED(llm_credential_present)`, any other variable the policy does not
  admit `REFUSED(unadmitted_environment)` (broken term `mu_on_O`). The task
  never starts the application and needs no database.

  ## Exit codes

    * `0` -- `KNOWN_REPLAY`: the recorded state was re-derived, nothing diverged;
    * `4` -- `DIVERGED`: the replay ran and the state is written, but it
      carries typed divergence (e.g. `unreceipted_transition` after a deleted
      receipt, `subject_changed` after a commit on a covered path);
    * `3` -- refused (typed JSON on the last stdout line, nothing written);
    * `2` -- invalid invocation.

  The last stdout line is always one JSON object.
  """

  use Mix.Task

  alias Xaas.Ultracode.{SemanticDrive, SemanticReplay}

  @switches [
    episode: :string,
    ggen_igniter_dir: :string,
    out: :string,
    subject_repo: :string,
    subject_ref: :string,
    ggen_build_path: :string,
    scratch: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: @switches)

    cond do
      invalid != [] or rest != [] ->
        usage("unknown arguments: #{inspect(invalid ++ rest)}")

      is_nil(opts[:episode]) or is_nil(opts[:ggen_igniter_dir]) or is_nil(opts[:out]) ->
        usage("--episode, --ggen-igniter-dir and --out are required")

      true ->
        case SemanticDrive.no_llm_guard(System.get_env()) do
          :ok -> replay(opts)
          {:refused, typed} -> emit(3, typed)
        end
    end
  end

  defp replay(opts) do
    result =
      SemanticReplay.replay(
        episode_dir: opts[:episode],
        ggen_igniter_dir: opts[:ggen_igniter_dir],
        subject_repo: opts[:subject_repo],
        subject_ref: opts[:subject_ref],
        ggen_build_path: opts[:ggen_build_path] && Path.expand(opts[:ggen_build_path]),
        scratch: opts[:scratch] && Path.expand(opts[:scratch])
      )

    case result do
      {:ok, envelope} ->
        out = Path.expand(opts[:out])
        File.mkdir_p!(Path.dirname(out))
        File.write!(out, SemanticReplay.canonical_json(envelope) <> "\n")

        emit(if(envelope["replay"] == "KNOWN_REPLAY", do: 0, else: 4), summary(envelope, out))

      {:refused, typed} ->
        emit(3, typed)
    end
  end

  defp summary(envelope, out) do
    state = envelope["state"]

    %{
      "replay" => envelope["replay"],
      "digest" => envelope["digest"],
      "standing" => state["standing"],
      "completed" => state["completed"],
      "eligible" => state["frontier"]["eligible"],
      "ledger_tail" => state["frontier"]["ledger_tail"],
      "divergence" =>
        Enum.map(state["divergence"], &Map.take(&1, ~w(reason broken_term identity))),
      "out" => out
    }
  end

  defp emit(code, map) do
    Mix.shell().info(Jason.encode!(map))
    if code != 0, do: exit({:shutdown, code})
    :ok
  end

  defp usage(message) do
    Mix.shell().info(Jason.encode!(%{"standing" => "invalid_invocation", "reason" => message}))
    exit({:shutdown, 2})
  end
end
