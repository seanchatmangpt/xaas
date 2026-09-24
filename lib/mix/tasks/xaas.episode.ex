defmodule Mix.Tasks.Xaas.Episode do
  @shortdoc "Prepare or drive a no-LLM KNOWN episode (GC-26.9.23 GC23-4..GC23-8)"

  @moduledoc """
  The no-LLM KNOWN episode runner (lane V23-D; PRD PR-008..PR-012; ARD
  sections 8, 10, 13, 14, 18).

      mix xaas.episode --name N --ggen-igniter-dir DIR --prepare --base SHA --drift PATH
      mix xaas.episode --name N --ggen-igniter-dir DIR [--work-root DIR] [--ggen-build-path DIR] [--no-pin]
      mix xaas.episode --check-env
      mix xaas.episode --verify-hops PATH --anchor-work-graph WORK --ggen-igniter-dir DIR [--ggen-build-path DIR] [--order ID]
      mix xaas.episode --verify-receipt EP_DIR --ggen-igniter-dir DIR [--order ID]
      mix xaas.episode --graph-toolchain --ggen-igniter-dir DIR [--ggen-build-path DIR]

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

  `--verify-hops` replays the ARD section 8 digest law over a recorded
  `hops.json` ANCHORED at the admitted order (lane R1-X-COURTS): the hop-0
  anchor is re-derived from the committed work graph `--anchor-work-graph`
  through the graph side's `mix semantic_jira.descriptor` in
  `--ggen-igniter-dir` (`Xaas.Ultracode.SemanticDrive.anchor/1`; pass a
  private `--ggen-build-path` clone so the judged build is never written),
  and every hop must equal it (`SemanticDrive.verify_hops/2`). `--order`
  defaults to the document's `work_order`. Without `--anchor-work-graph`
  the replay is `REFUSED(hops_unanchored)`: internal agreement alone admits
  a document forged consistently at every hop.

  `--verify-receipt` judges the episode's R projection
  (`EP_DIR/receipt.r.json`) against the order it claims
  (`EP_DIR/work.json`, order `--order`, default `EP_DIR/drive.json`'s
  `order`) and the subject repository `--ggen-igniter-dir`
  (`Xaas.Receipt.RProjection.consistency/2`): ALIVE needs every acceptance
  true, the consequence commits inside `base_sha..subject_sha`, the changed
  files inside the order's `path_scope`, and every replay command equal to
  the command the court binding recorded.

  `--graph-toolchain` prints the toolchain the drive would run the graph
  side with (`Xaas.Ultracode.SemanticDrive.graph_toolchain/2`: the Elixir
  that compiled `--ggen-build-path`, default `DIR/_build/test`, else the
  `.tool-versions` pin) as one JSON line, so the GC23-8 court's live
  frontier recompute uses the same resolution as the drive. It resolves
  paths only; nothing is executed.

  ## The no-LLM guard (F3)

  Every mode except `--verify-hops`, `--verify-receipt` and
  `--graph-toolchain` first runs
  `Xaas.Ultracode.SemanticDrive.no_llm_guard/1` over the process
  environment, BEFORE the application starts, and fails closed over
  `priv/no_llm/policy.json`: a provider-claimed variable (`ANTHROPIC_*`,
  `GEMINI_*`, `OPENROUTER_*`, ...) or a provider executable on `PATH`
  (`claude`, `zcode`, `gemini`, `codex`, `ollama`, ...) is
  `REFUSED(llm_credential_present)`, any other variable the policy does not
  admit `REFUSED(unadmitted_environment)` (broken term `mu_on_O`).
  `--check-env` runs only the guard.

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

  alias Xaas.Receipt.RProjection
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
    anchor_work_graph: :string,
    verify_receipt: :string,
    graph_toolchain: :boolean,
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
        verify_hops(opts[:verify_hops], opts)

      opts[:verify_receipt] ->
        verify_receipt(opts[:verify_receipt], opts)

      opts[:graph_toolchain] ->
        graph_toolchain(opts)

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

  defp verify_hops(path, opts) do
    with {:ok, body} <- File.read(path),
         {:ok, hops} <- Jason.decode(body) do
      # the internal law first (no graph-side process for a document that
      # already disagrees with itself), then the admitted-order anchor
      with {:ok, _internal} <- SemanticDrive.verify_hops(hops),
           {:ok, anchor} <- hops_anchor(hops, opts),
           {:ok, digests} <- SemanticDrive.verify_hops(hops, anchor) do
        emit(0, Map.merge(digests, %{"standing" => "ALIVE", "hops" => path}))
      else
        {:refused, typed} -> refuse(typed)
      end
    else
      error -> usage("--verify-hops #{path}: #{inspect(error)}")
    end
  end

  defp hops_anchor(hops, opts) do
    case {opts[:anchor_work_graph], opts[:ggen_igniter_dir]} do
      {work, dir} when is_binary(work) and is_binary(dir) ->
        dir = Path.expand(dir)

        SemanticDrive.anchor(
          ggen_igniter_dir: dir,
          work_graph: Path.expand(work),
          # hops is the map SemanticDrive.verify_hops/1 already admitted
          order: opts[:order] || hops["work_order"] || "EP-A",
          ggen_build_path: opts[:ggen_build_path] && Path.expand(opts[:ggen_build_path])
        )

      {nil, _dir} ->
        {:refused,
         %{
           "standing" => "REFUSED(hops_unanchored)",
           "reason" => "hops_unanchored",
           "broken_term" => "admission_vacuous",
           "hop" => "sjira",
           "detail" => %{
             "reason" =>
               "--verify-hops needs --anchor-work-graph and --ggen-igniter-dir: hop agreement without the admitted-order anchor admits a consistent all-hop forgery"
           }
         }}

      {_work, nil} ->
        usage("--anchor-work-graph needs --ggen-igniter-dir")
    end
  end

  defp verify_receipt(dir, opts) do
    with repo when is_binary(repo) <- opts[:ggen_igniter_dir],
         {:ok, r} <- read_json(Path.join(dir, "receipt.r.json")),
         {:ok, graph} <- read_json(Path.join(dir, "work.json")) do
      order_id = opts[:order] || episode_order(dir)
      rows = if is_map(graph), do: graph["work_orders"] || [], else: graph
      row = Enum.find(List.wrap(rows), &(is_map(&1) and &1["identity"] == order_id))

      case RProjection.consistency(r,
             order: row || %{"identity" => order_id},
             repo: Path.expand(repo)
           ) do
        {:ok, facts} ->
          emit(0, Map.merge(facts, %{"receipt" => Path.join(dir, "receipt.r.json")}))

        {:refused, typed} ->
          refuse(typed)
      end
    else
      nil -> usage("--verify-receipt needs --ggen-igniter-dir (the subject repository)")
      {:error, why} -> usage("--verify-receipt #{dir}: #{inspect(why)}")
    end
  end

  defp episode_order(dir) do
    case read_json(Path.join(dir, "drive.json")) do
      {:ok, %{"order" => order}} when is_binary(order) -> order
      _ -> "EP-A"
    end
  end

  defp read_json(path) do
    with {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body) do
      {:ok, json}
    else
      {:error, reason} -> {:error, {path, reason}}
    end
  end

  defp graph_toolchain(opts) do
    case opts[:ggen_igniter_dir] do
      nil ->
        usage("--graph-toolchain needs --ggen-igniter-dir")

      dir ->
        dir = Path.expand(dir)
        build = Path.expand(opts[:ggen_build_path] || Path.join([dir, "_build", "test"]))

        case SemanticDrive.graph_toolchain(dir, build) do
          {:ok, toolchain} -> emit(0, Map.put(toolchain, "standing", "RESOLVED"))
          {:refused, typed} -> refuse(typed)
        end
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
