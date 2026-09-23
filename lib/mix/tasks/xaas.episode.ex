defmodule Mix.Tasks.Xaas.Episode do
  @shortdoc "Prepare or drive a no-LLM KNOWN episode (GC-26.9.23 GC23-4..GC23-8)"

  @moduledoc """
  The no-LLM KNOWN episode runner (lane V23-D; PRD PR-008..PR-012; ARD
  sections 8, 10, 13, 14, 18).

      mix xaas.episode --name N --ggen-igniter-dir DIR --prepare --base SHA --drift PATH
      mix xaas.episode --name N --ggen-igniter-dir DIR [--work-root DIR] [--ggen-build-path DIR] [--no-pin]
      mix xaas.episode --check-env
      mix xaas.episode --verify-hops PATH

  `--prepare` creates branch `v23/episode-<N>` in the ggen_igniter
  repository of `DIR` at `SHA` with ONE deterministic format-drift commit
  in `PATH`, and writes `<out-root>/<N>/work.json` (EP-A repairs the drift;
  EP-B depends on EP-A) and a fresh `ledger.ndjson`
  (`Xaas.Ultracode.SemanticDrive.Episode`).

  Without `--prepare` it drives EP-A through `Xaas.Ultracode.SemanticDrive`
  and writes the artifacts into `<out-root>/<N>/` (`hops.json`,
  `receipt.json`, `receipt.r.json`, `ocel.json`, `ocel2.json`,
  `frontier_before.json`, `frontier_after.json`, ...). The produced head is
  pinned as branch `v23/episode-<N>-receipt` (`--no-pin` skips). An episode
  whose `receipt.json` already exists is refused (`episode_already_driven`):
  committed evidence is never overwritten.

  `--out-root` defaults to `docs/sjira/v26.9.23/episodes` (relative to the
  cwd, the xaas root). `--subject-repo` names the repository that holds the
  episode subject when it is not the repository of `DIR` (the graph-side
  tooling checkout), e.g. a scratch clone.

  ## The no-LLM guard (F3)

  Every mode except `--verify-hops` first runs
  `Xaas.Ultracode.SemanticDrive.no_llm_guard/1` over the process
  environment, BEFORE the application starts: any `ANTHROPIC_*`,
  `CLAUDE_*`, `CLAUDECODE`, `OPENAI_*`, `ZAI_*`, `Z_AI_*`, `GLM_*`,
  `ZCODE_*` variable, or a `zcode` / `claude` executable on `PATH`, is
  `REFUSED(llm_credential_present)` (broken term `mu_on_O`). `--check-env`
  runs only the guard.

  ## Persistence

  The drive needs `Xaas.Repo` (Run/Epoch/Receipt rows). Under a sandbox
  pool (`MIX_ENV=test`, e.g. with `MIX_TEST_PARTITION`) the whole episode
  runs inside ONE sandbox checkout that is rolled back at exit: the durable
  record is the episode artifacts, not the rows. Under any other pool the
  rows persist.

  The subject repository is registered at runtime as repo alias
  `ggen_igniter` (the repository that owns `DIR`), the epoch worktree root
  is `--work-root` (default a fresh temp dir), and the
  `ggen-igniter-format` court suite is taken from
  `Xaas.Ultracode.TargetSuites.devs/0` when not already registered.

  ## Exit codes

  `0` success (the last stdout line is the JSON summary), `2` invalid
  invocation, `3` a typed refusal (the last stdout line is
  `{"standing": "REFUSED(<reason>)" | "BLOCKED:<reason>" | "BUILD_BROKEN",
  "reason", "broken_term", "hop", "detail"}`).
  """

  use Mix.Task

  alias Xaas.Ultracode.{SemanticDrive, TargetSuites, Verifier}
  alias Xaas.Ultracode.SemanticDrive.Episode

  @switches [
    name: :string,
    ggen_igniter_dir: :string,
    prepare: :boolean,
    base: :string,
    drift: :string,
    out_root: :string,
    work_root: :string,
    ggen_build_path: :string,
    pin: :boolean,
    check_env: :boolean,
    verify_hops: :string,
    order: :string,
    subject_repo: :string
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

      opts[:verify_hops] ->
        verify_hops(opts[:verify_hops])

      true ->
        case SemanticDrive.no_llm_guard(System.get_env()) do
          :ok -> guarded(opts)
          {:refused, typed} -> refuse(typed)
        end
    end
  end

  defp guarded(opts) do
    cond do
      opts[:check_env] ->
        emit(0, %{"standing" => "ALIVE", "no_llm_guard" => "passed"})

      is_nil(opts[:name]) or is_nil(opts[:ggen_igniter_dir]) ->
        usage("--name and --ggen-igniter-dir are required")

      opts[:prepare] ->
        prepare(opts)

      true ->
        drive(opts)
    end
  end

  defp verify_hops(path) do
    with {:ok, body} <- File.read(path),
         {:ok, hops} <- Jason.decode(body) do
      case SemanticDrive.verify_hops(hops) do
        {:ok, digests} ->
          emit(0, Map.merge(digests, %{"standing" => "ALIVE", "hops" => path}))

        {:refused, typed} ->
          refuse(typed)
      end
    else
      error -> usage("--verify-hops #{path}: #{inspect(error)}")
    end
  end

  defp prepare(opts) do
    with base when is_binary(base) <- opts[:base],
         drift when is_binary(drift) <- opts[:drift] do
      case Episode.prepare(
             repo: opts[:subject_repo] || opts[:ggen_igniter_dir],
             name: opts[:name],
             base: base,
             drift: drift,
             out_dir: out_dir(opts)
           ) do
        {:ok, facts} -> emit(0, Map.put(facts, "standing", "PREPARED"))
        {:refused, typed} -> refuse(typed)
      end
    else
      _ -> usage("--prepare needs --base and --drift")
    end
  end

  defp drive(opts) do
    dir = out_dir(opts)

    if File.exists?(Path.join(dir, "receipt.json")) do
      refuse(%{
        "standing" => "REFUSED(episode_already_driven)",
        "reason" => "episode_already_driven",
        "broken_term" => "mu_on_O",
        "hop" => "episode",
        "detail" => %{"out_dir" => dir}
      })
    else
      Mix.Task.run("app.start")
      checkin = sandbox_checkout()

      try do
        configure(opts)

        result =
          SemanticDrive.drive(
            ggen_igniter_dir: Path.expand(opts[:ggen_igniter_dir]),
            work_graph: Path.expand(Path.join(dir, "work.json")),
            ledger: Path.expand(Path.join(dir, "ledger.ndjson")),
            order: opts[:order] || "EP-A",
            out_dir: dir,
            ggen_build_path: opts[:ggen_build_path] && Path.expand(opts[:ggen_build_path]),
            pin_ref:
              if(Keyword.get(opts, :pin, true), do: Episode.branch(opts[:name]) <> "-receipt")
          )

        case result do
          {:ok, summary} -> emit(0, summary)
          {:refused, typed} -> refuse(typed)
        end
      after
        checkin.()
      end
    end
  end

  # Runtime registration for this invocation only (never persisted): the
  # subject repository alias, the epoch worktree root, the court suite.
  defp configure(opts) do
    {:ok, repo} = Episode.repo_root(opts[:subject_repo] || opts[:ggen_igniter_dir])
    repos = Application.get_env(:xaas, :ultracode_repos, %{}) || %{}
    Application.put_env(:xaas, :ultracode_repos, Map.put(repos, @repo_alias, repo))

    root =
      opts[:work_root] ||
        Path.join(System.tmp_dir!(), "xaas-episode-runs-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    Application.put_env(:xaas, :ultracode_worktree_root, real_path(root))

    unless Verifier.registered?(@suite) do
      suites = Application.get_env(:xaas, :ultracode_verifier_suites, %{}) || %{}

      Application.put_env(
        :xaas,
        :ultracode_verifier_suites,
        Map.put(suites, @suite, court_suite())
      )
    end
  end

  @doc """
  The `ggen-igniter-format` court suite of `Xaas.Ultracode.TargetSuites.devs/0`
  with its toolchain `PATH` bound to the asdf data dir
  (`ASDF_DATA_DIR`, else `config :xaas, :ultracode_asdf_data_dir`) instead of
  `~/.asdf`: the declaration expands `~` when it is read, and the F3 court
  runs with a fresh `HOME`, where `~/.asdf` names nothing and the court would
  judge the subject with whatever `elixir` happens to be on the fallback path.
  Steps, argv and result format are untouched.
  """
  @spec court_suite() :: map()
  def court_suite do
    suite = Map.fetch!(TargetSuites.devs(), @suite)
    home_asdf = Path.expand("~/.asdf")

    asdf =
      System.get_env("ASDF_DATA_DIR") || Application.get_env(:xaas, :ultracode_asdf_data_dir) ||
        home_asdf

    if asdf == home_asdf do
      suite
    else
      update_in(suite, [:env, "PATH"], &String.replace(&1, home_asdf, asdf))
    end
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

  defp refuse(typed), do: emit(3, typed)

  defp usage(message) do
    Mix.shell().error("mix xaas.episode: #{message}")
    exit({:shutdown, 2})
  end
end
