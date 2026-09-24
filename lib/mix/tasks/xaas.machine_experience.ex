defmodule Mix.Tasks.Xaas.MachineExperience do
  @shortdoc "Prepare, route or run a MachineExperience episode (GC-26.9.23 GC23-9)"

  @moduledoc """
  The MachineExperience ratchet runner (lane V23-M; PRD PR-014, PR-016; ARD
  sections 13 and 15; `Xaas.Ultracode.MachineExperience.Episode`).

      mix xaas.machine_experience --prepare --name N --ggen-igniter-dir DIR --base SHA --drift PATH [--failure-class C]
      mix xaas.machine_experience --route --work PATH [--order ID] [--experience TTL ...]
      mix xaas.machine_experience --name N --ggen-igniter-dir DIR [--experience TTL ...] [--exploration PATH]
                                  [--work-root DIR] [--ggen-build-path DIR] [--pin-ref REF | --no-pin]
      mix xaas.machine_experience --check-env

  `--prepare` makes the UNKNOWN-class episode in `<out-root>/<N>/`: the
  deterministic drift subject `v23/episode-<N>` and the two-order work graph
  with every `requires_capability` removed and `failure_class` set.

  `--route` only routes (the GC23-9 falsifier surface): KNOWN from the
  order's own capability or from an ADMITTED MachineExperience in the
  `--experience` Turtle graph, else UNKNOWN. Nothing executes.

  Without a mode it runs the episode: route; KNOWN -> the no-LLM drive of
  `Xaas.Ultracode.SemanticDrive` with the experience's capability (Episode
  2); UNKNOWN + `<out-root>/<N>/exploration.json` -> the bounded
  exploration's candidates through the same drive, then the manufactured,
  admitted and SHACL-validated MachineExperience (Episode 1); UNKNOWN
  without an exploration -> nothing executes, `unknown/unknown.json` is the
  receipt. The produced head is pinned as `v23/episode-<N>-receipt`, or as
  `--pin-ref REF` (a regenerated episode pins a new ref: pins are
  create-only, an existing ref is never moved); `--no-pin` skips.
  `--out-root` defaults to `docs/sjira/v26.9.23/episodes`.

  Every mode first runs the no-LLM guard (`SemanticDrive.no_llm_guard/1`,
  F3, fail closed over `priv/no_llm/policy.json`): a provider-claimed
  variable or a provider executable on PATH is
  `REFUSED(llm_credential_present)`, any other variable the policy does not
  admit `REFUSED(unadmitted_environment)`.

  Persistence, runtime registration (repo alias `ggen_igniter`, epoch
  worktree root, the `ggen-igniter-format` court suite) and the sandbox
  checkout under `MIX_ENV=test` are those of `mix xaas.episode`.

  ## Exit codes

  `0` KNOWN / ALIVE (last stdout line: the JSON summary or route), `2`
  invalid invocation, `3` a typed refusal, `4` UNKNOWN (last stdout line:
  `{"standing": "UNKNOWN", "reason", ...}`).
  """

  use Mix.Task

  alias Mix.Tasks.Xaas.Episode, as: EpisodeTask
  alias Xaas.Ultracode.{SemanticDrive, Verifier}
  alias Xaas.Ultracode.MachineExperience.Episode
  alias Xaas.Ultracode.SemanticDrive.Episode, as: DriveEpisode

  @switches [
    name: :string,
    ggen_igniter_dir: :string,
    prepare: :boolean,
    route: :boolean,
    check_env: :boolean,
    base: :string,
    drift: :string,
    failure_class: :string,
    work: :string,
    order: :string,
    experience: :keep,
    exploration: :string,
    out_root: :string,
    work_root: :string,
    ggen_build_path: :string,
    subject_repo: :string,
    pin: :boolean,
    pin_ref: :string
  ]

  @default_out_root "docs/sjira/v26.9.23/episodes"
  @suite "ggen-igniter-format"
  @repo_alias "ggen_igniter"

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: @switches)

    cond do
      invalid != [] or rest != [] ->
        usage("unknown arguments: #{inspect(invalid ++ rest)}")

      true ->
        case SemanticDrive.no_llm_guard(System.get_env()) do
          :ok -> guarded(opts, args)
          {:refused, typed} -> emit(3, typed)
        end
    end
  end

  defp guarded(opts, args) do
    cond do
      opts[:check_env] ->
        emit(0, %{"standing" => "ALIVE", "no_llm_guard" => "passed"})

      opts[:route] ->
        route(opts)

      is_nil(opts[:name]) or is_nil(opts[:ggen_igniter_dir]) ->
        usage("--name and --ggen-igniter-dir are required")

      opts[:prepare] ->
        prepare(opts)

      true ->
        run_episode(opts, args)
    end
  end

  defp route(opts) do
    case opts[:work] do
      nil ->
        usage("--route needs --work")

      work ->
        result =
          Episode.route(
            work: work,
            order: opts[:order] || "EP-A",
            experience: Keyword.get_values(opts, :experience)
          )

        case result do
          {:known, route} -> emit(0, Map.merge(route, %{"standing" => "KNOWN"}))
          {:unknown, typed} -> emit(4, typed)
          {:refused, typed} -> emit(3, typed)
        end
    end
  end

  defp prepare(opts) do
    with base when is_binary(base) <- opts[:base],
         drift when is_binary(drift) <- opts[:drift] do
      result =
        Episode.prepare(
          repo: opts[:subject_repo] || opts[:ggen_igniter_dir],
          name: opts[:name],
          base: base,
          drift: drift,
          failure_class: opts[:failure_class] || Episode.failure_class(),
          out_dir: out_dir(opts)
        )

      case result do
        {:ok, facts} -> emit(0, Map.put(facts, "standing", "PREPARED"))
        {:refused, typed} -> emit(3, typed)
      end
    else
      _ -> usage("--prepare needs --base and --drift")
    end
  end

  defp run_episode(opts, args) do
    Mix.Task.run("app.start")
    checkin = sandbox_checkout()

    try do
      repo = configure(opts)

      result =
        Episode.run(
          name: opts[:name],
          out_dir: out_dir(opts),
          ggen_igniter_dir: Path.expand(opts[:ggen_igniter_dir]),
          experience: Keyword.get_values(opts, :experience),
          exploration: opts[:exploration],
          order: opts[:order] || "EP-A",
          ggen_build_path: opts[:ggen_build_path] && Path.expand(opts[:ggen_build_path]),
          repo_path: repo,
          command: Enum.join(["mix xaas.machine_experience" | args], " "),
          pin_ref:
            if(Keyword.get(opts, :pin, true),
              do: opts[:pin_ref] || DriveEpisode.branch(opts[:name]) <> "-receipt"
            )
        )

      case result do
        {:ok, summary} -> emit(0, Map.drop(summary, ["experience_sources"]))
        {:unknown, typed} -> emit(4, typed)
        {:refused, typed} -> emit(3, typed)
      end
    after
      checkin.()
    end
  end

  # Runtime registration for this invocation only (never persisted), as in
  # `mix xaas.episode`: the subject repository alias, the epoch worktree
  # root, the court suite. Returns the subject repository path.
  defp configure(opts) do
    {:ok, repo} = DriveEpisode.repo_root(opts[:subject_repo] || opts[:ggen_igniter_dir])
    repos = Application.get_env(:xaas, :ultracode_repos, %{}) || %{}
    Application.put_env(:xaas, :ultracode_repos, Map.put(repos, @repo_alias, repo))

    root =
      opts[:work_root] ||
        Path.join(System.tmp_dir!(), "xaas-me-runs-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    Application.put_env(:xaas, :ultracode_worktree_root, real_path(root))

    unless Verifier.registered?(@suite) do
      suites = Application.get_env(:xaas, :ultracode_verifier_suites, %{}) || %{}

      Application.put_env(
        :xaas,
        :ultracode_verifier_suites,
        Map.put(suites, @suite, EpisodeTask.court_suite())
      )
    end

    repo
  end

  defp sandbox_checkout do
    if Xaas.Repo.config()[:pool] == Ecto.Adapters.SQL.Sandbox do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo, ownership_timeout: :infinity)
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
      fn -> Ecto.Adapters.SQL.Sandbox.checkin(Xaas.Repo) end
    else
      fn -> :ok end
    end
  end

  defp out_dir(opts), do: Path.join(opts[:out_root] || @default_out_root, opts[:name])

  defp real_path(path) do
    case System.cmd("pwd", ["-P"], cd: path) do
      {out, 0} -> String.trim(out)
      _ -> path
    end
  end

  defp emit(code, map) do
    Mix.shell().info(Jason.encode!(map))
    if code != 0, do: exit({:shutdown, code})
    :ok
  end

  defp usage(message) do
    Mix.shell().error("mix xaas.machine_experience: #{message}")
    exit({:shutdown, 2})
  end
end
