defmodule Mix.Tasks.Xaas.StopCourt do
  @shortdoc "Stop court for a GoalCheckpoint: run gate courts, write R receipts, ASK STOP (exit 0 = STOP)"

  @moduledoc """
  Stop court for a Semantic Jira `sj:GoalCheckpoint`: GC-FRI-0800 (the Friday
  2026-09-25 08:00 PT checkpoint) and GC-26.9.23 (the v26.9.23 release
  checkpoint, PRD section 13 / ARD section 19).

      mix xaas.stop_court --checkpoint GC-26.9.23
      mix xaas.stop_court --checkpoint GC-FRI-0800 --only G6
      mix xaas.stop_court --checkpoint GC-FRI-0800 --graph PATH \\
        --receipts-dir PATH --order-receipts-dir PATH --timeout SECONDS \\
        --ggen-igniter-dir PATH

  Per-checkpoint defaults come from a registry (`checkpoints/0`), not from
  Friday-only constants:

    * `GC-FRI-0800` -> `docs/sjira/v26.9.22/friday/goal.ttl`, gate receipts in
      `docs/sjira/v26.9.22/friday/receipts`, order receipts in
      `receipts/v26.9.22` (one directory), `GGEN_IGNITER_DIR` default
      `~/ggen_igniter` (the fallback its court commands already name);
    * `GC-26.9.23` -> `docs/sjira/v26.9.23/goal.ttl`, gate receipts in
      `docs/sjira/v26.9.23/receipts`, order receipts in the ordered list
      `receipts/v26.9.23` (the xaas repository under judgement), then
      `$GGEN_IGNITER_DIR/receipts/v26.9.23` (the other critical-path
      repository, resolved with the same precedence as the court env below),
      `GGEN_IGNITER_DIR` default `~/ggen_igniter` (the canonical checkout).

  An explicit option always wins; `--order-receipts-dir` is repeatable and,
  when given, replaces the registry's list (in the given order). A
  checkpoint outside the registry needs `--graph`, `--receipts-dir` and
  `--order-receipts-dir`.

  For each gate (a `sj:GoalCheckpoint` with `sj:checkpointOf` the named root)
  it runs the gate's `sj:courtCommand` with `/bin/sh -c` from the repository
  root, in its own process group, under a deadline (`--timeout`, default 900
  seconds; the whole group is killed on timeout). The court's environment
  carries `XAAS_DIR` (the repository root under judgement) and
  `GGEN_IGNITER_DIR` (`--ggen-igniter-dir`, else the caller's
  `GGEN_IGNITER_DIR`, else the registry default); both, and the
  ggen_igniter HEAD when that directory is a git checkout, are recorded in
  the gate receipt. It writes one R-schema gate receipt per gate to
  `<receipts-dir>/<gate>.json` (`~/.claude/dfcm/receipt.schema.json`:
  identity, authority, consequence, replay, standing). A gate's standing is
  `ALIVE` when its court command exited 0, `BLOCKED:<reason>` for a typed
  exit 77 (below), and `UNKNOWN` otherwise (a failing or missing court
  witnesses nothing). Court exit-code contract, recorded as
  `gate.outcome`:

    * `0` -> `passed` (standing `ALIVE`);
    * `75` (`unknown_exit/0`, sysexits EX_TEMPFAIL) -> `machinery_absent`: the
      court printed `UNKNOWN: <gate> machinery lands in lane <LANE>`
      (standing `UNKNOWN`);
    * `77` (`blocked_exit/0`, sysexits EX_NOPERM) -> `blocked`: every witness
      of the court held and its only open item is an edge the court may not
      close itself (e.g. operator acceptance, GC23-12 lane V23-H). Its last
      output line must be typed `BLOCKED(<reason>): ... (broken_term <term>)`
      with `<reason>` in `[a-z][a-z0-9_]*` and `<term>` a Chatman broken term
      of the R schema; the gate standing is then `BLOCKED:<reason>` and the
      receipt's `standing.broken_term` is `<term>`. An exit 77 without such a
      line is `court_failed` (an untyped block witnesses nothing);
    * `124` after the deadline -> `timeout` (standing `UNKNOWN`);
    * anything else -> `court_failed` (standing `UNKNOWN`).

  `--only` (repeatable or comma-separated) runs just those gates; every other
  gate is judged by the receipt already on disk.

  STOP is the root's `sj:stopQuery`, a SPARQL ASK, evaluated over the goal
  graph plus one `sj:Receipt` node per receipt that
  `~/.claude/dfcm/validate_receipt.py` ADMITS:

    * gate receipts are linked only when `identity.subject` is
      `<checkpoint>/<gate>`;
    * each `sj:WorkOrder` under the root (`sj:checkpointOf+`: on the root
      itself or on one of its gates, transitively) is looked up as
      `<dir>/<identifier>.json` in every order-receipts directory and linked
      only when its tuple is complete and `identity.tuple_digest` equals the
      order's tuple digest (`"sha256:" <> hex(sha256(canonical JSON))` over
      `subject`, `postcondition`, `capability` (the `sj:capabilityId`),
      `evidence_ceiling`, `authority_ceiling`, `consequence_class`,
      `exclusions` sorted; sorted keys, compact). `sj:exclusion` is 0..n:
      an order without one has `exclusions` `[]`. A receipt found in one
      directory is judged from there; the same bytes found in several
      directories are judged from the first; different bytes for one order in
      two directories are never picked silently: the order is refused
      `REFUSED(duplicate_order_receipt)` (broken term `R_missing_identity`)
      and stays open.

  The goal graph itself may not assert a receipt (`sj:receipt` or an
  `sj:Receipt` node): it is refused, so standing is only ever observed. When
  a `stop.rq` sits next to the graph (or `--stop-query` names one), its
  trimmed text must equal the root's `sj:stopQuery`, or the court refuses to
  run.

  The ASK is evaluated by the native oxigraph engine already in the
  dependency tree (`GgenIgniter.Native.GraphNif`, ggen_igniter). That NIF
  yields rows for SELECT only, so the ASK is evaluated as the equivalent
  existence query (SPARQL 1.1 section 16.3: ASK is true iff the pattern has a
  solution): the `ASK` keyword becomes `SELECT *` with `LIMIT 1`, and STOP is
  true iff one row comes back.

  After the ASK it writes `<receipts-dir>/STOP-<checkpoint>.json` (standing
  `ALIVE` iff STOP, `UNKNOWN` otherwise), prints the per-gate table, one line
  per order and `STOP=true|false`. The STOP receipt's `stop` section lists
  the order-receipts directories (with the git toplevel and HEAD of the
  repository holding each, SHA-1 or SHA-256; when the HEAD is `null`,
  `repo_head_why` says why: directory absent, no git checkout, unborn HEAD,
  or the git failure, never a git failure reported as "no git checkout") and,
  per order, the directory and repository HEAD its receipt came from, whether
  those receipt bytes are the blob committed at that HEAD (`true`, `false`
  with the reason, or `null` with the git failure), every path it was found
  at, and the refusal if any.

  Release evidence (lane V23-S; operator release sequence steps 3 and 5,
  ARD sections 12 and 27). Every gate receipt and the STOP receipt carry:

    * `identity.repo`: the GitHub slug (`owner/name`) of the repository
      under judgement, from its first github.com remote (`origin` first); the
      observed worktree path is `identity.worktree` and `identity.repo_source`
      names where the slug came from (a checkout without a github.com remote
      keeps its path in `identity.repo` and says so there);
    * `verifier`: `runner` (`mix xaas.stop_court`), `runner_source` and
      `runner_source_sha256` (this module's source, digested at compile time)
      with `runner_source_at_subject` (whether those bytes are the blob at the
      subject), `court_command` and `court_command_sha256`, `court_script` and
      `court_script_sha256` (the script a `sh|bash|python3 <file>` court
      command names, read just before it runs; `null` with
      `court_script_why` for an inline command) with `court_script_at_subject`
      (`true`, `false` with the reason, or `null` with the git failure),
      `validator`/`validator_sha256`, `schema`/`schema_sha256`
      (`~/.claude/dfcm/receipt.schema.json`, the schema the validator loads)
      and `stop_query_sha256` (the root's `sj:stopQuery` text as evaluated).
      The STOP receipt's court is the runner itself (`court_script` =
      `runner_source`);
    * `toolchain`: `elixir` (`System.version/0`), `otp_release`,
      `erts_version`, `python3` (`python3 --version`) and `python3_path`;
    * `replay.commands[].invocation`: the exact reproducible invocation
      (`argv`, `env`, `cwd` and a `shell` line): `mix xaas.stop_court
      --checkpoint <cp>` with every explicit option resolved to an absolute
      path and `--only <gate>` for a gate receipt (the `--only` list as given
      for the STOP receipt), under `env` = `MIX_ENV` (the court's own
      `Mix.env/0`), `GGEN_IGNITER_DIR` (the resolved court env value),
      `GC23_FLEET_RECEIPTS_DIR` and every other `GC23_*`/`DFCM_*` variable of
      the caller (an unset variable is `null` and `env -u` in `shell`).

  The STOP receipt also derives (never asserts) the ARD section 27 counters in
  `release_counters`, each `{value, why, source, rule, ...evidence}`; a
  counter whose source cannot be read is `value: null` with `why`, never 0:

    * `REQUIRED_UNKNOWN`: gates of the root plus non-Successor WorkOrders under
      it whose linked, validator-ADMITTED receipt is not terminal (ALIVE,
      BLOCKED*, UNSUPPORTED*, REFUSED*), missing or unlinked (this run);
    * `UNCLASSIFIED_REQUIRED_WORK`: the violation count of the GC23-11 court's
      step 1 (`fleet_matrix.py check-classification`, same argv, re-executed
      at the subject under the court deadline);
    * `LLM_INVOCATIONS_ON_KNOWN_REFERENCE_PATH` and `REQUIRED_LLM_KNOWN`:
      LLM-provider events in the known-reference episodes' OCEL logs
      (`episodes/{fmt-1,me-2}/ocel.json`) by the GC23-5 and GC23-9 court
      rules (`llm_provider_events/1`), summed, and the number of those
      episodes with at least one;
    * `UNRECEIPTED_ACTUATION`: episode ledger actuations (every
      `ledger.ndjson` line of every episode directory) whose OCEL
      `StandingChanged` event (same `event_digest`) does not name a receipt a
      `ReceiptSealed` event sealed.

  Checkpoints without episodes or a classification check in the registry
  (GC-FRI-0800) get those counters `null` with the reason.

  Exit codes: `0` STOP=true, `1` STOP=false, `2` the court could not run
  (bad arguments, unreadable graph, unknown checkpoint, asserted receipts,
  stop-query drift, missing validator, query engine error).

  No LLM and no network in the court itself. It loads config but starts no
  application (no Repo, no Oban). Court commands are whatever the goal graph
  names; the graph is the authority for what gets run.
  """

  use Mix.Task

  alias GgenIgniter.Native.GraphNif
  alias Xaas.Ultracode.ProcessGroup

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @dcterms_identifier "http://purl.org/dc/terms/identifier"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  # Per-checkpoint defaults (paths relative to the repository root). The goal
  # graph stays the authority for gates and court commands; this registry only
  # says where each checkpoint's graph and receipts live.
  # `order_receipts_dirs` is ordered: `{:repo, rel}` is relative to the
  # repository under judgement, `{:ggen_igniter, rel}` to the resolved
  # GGEN_IGNITER_DIR (lane V23-L: the GC-26.9.23 orders V23-B and V23-C
  # carry their receipts in ggen_igniter).
  @checkpoints %{
    "GC-FRI-0800" => %{
      graph: "docs/sjira/v26.9.22/friday/goal.ttl",
      receipts_dir: "docs/sjira/v26.9.22/friday/receipts",
      order_receipts_dirs: [{:repo, "receipts/v26.9.22"}],
      ggen_igniter_dir: "~/ggen_igniter"
    },
    "GC-26.9.23" => %{
      graph: "docs/sjira/v26.9.23/goal.ttl",
      receipts_dir: "docs/sjira/v26.9.23/receipts",
      order_receipts_dirs: [{:repo, "receipts/v26.9.23"}, {:ggen_igniter, "receipts/v26.9.23"}],
      ggen_igniter_dir: "~/ggen_igniter",
      # Release counters (lane V23-S, ARD section 27): the episodes whose
      # OCEL/ledger the counters read, and the GC23-11 court's step 1 argv
      # (docs/sjira/v26.9.23/courts/GC23-11.sh, relative to the repository).
      episodes: %{dir: "docs/sjira/v26.9.23/episodes", known_reference: ["fmt-1", "me-2"]},
      classification_check: %{
        court: "docs/sjira/v26.9.23/courts/GC23-11.sh",
        argv: [
          "python3",
          "scripts/sjira/fleet_matrix.py",
          "check-classification",
          "--classification",
          "docs/sjira/v26.9.23/fleet/classification.ttl",
          "--universe",
          "docs/sjira/v26.9.23/fleet/universe.json",
          "--courts-dir",
          "docs/sjira/v26.9.23/courts",
          "--expect-critical",
          "xaas",
          "--expect-critical",
          "ggen_igniter"
        ]
      }
    }
  }
  @path_options [
    graph: "--graph",
    receipts_dir: "--receipts-dir",
    order_receipts_dirs: "--order-receipts-dir"
  ]
  @default_timeout_s 900

  # Court exit-code contract: 0 passed (ALIVE); @unknown_exit = the gate's
  # machinery has not landed (UNKNOWN); @blocked_exit = every witness held and
  # the one open item is an edge outside the court (BLOCKED:<reason>, typed
  # last line required); @timeout_exit = deadline (UNKNOWN); anything else =
  # the court ran and witnessed nothing (UNKNOWN).
  @unknown_exit 75
  @blocked_exit 77
  @blocked_line ~r/\ABLOCKED\(([a-z][a-z0-9_]*)\)/
  @broken_terms ~w(mu_on_O admission_vacuous mu_unlawful R_missing_identity R_missing_authority
                   R_missing_consequence R_missing_replay R_missing_standing R_not_fed_back)

  @perl "/usr/bin/perl"
  @wrapper "setpgrp(0,0); alarm(shift @ARGV); exec @ARGV or exit 127;"
  @alarm_grace_s 2
  @timeout_exit 124
  @tail_bytes 4096

  @sha ~r/\A[0-9a-f]{40}\z/
  # A commit id in either object format (SHA-1, SHA-256): the HEAD of a
  # repository that holds order receipts is provenance, not a receipt subject.
  @object_id ~r/\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/
  @ask ~r/\A((?:\s*(?:#[^\n]*(?:\n|\z)|(?:PREFIX|BASE)\b[^\n]*(?:\n|\z)))*\s*)ASK\b/i
  @tuple_fields ~w(subject postcondition capability evidence_ceiling authority_ceiling consequence_class exclusions)

  # Verifier identity (lane V23-S): this module's own source, digested when it
  # is compiled, is the runner that judged; the schema is the one the fleet
  # validator loads (`Path.home() / ".claude/dfcm/receipt.schema.json"`).
  @runner "mix xaas.stop_court"
  @runner_source Path.relative_to_cwd(__ENV__.file)
  @runner_source_sha256 "sha256:" <>
                          Base.encode16(:crypto.hash(:sha256, File.read!(__ENV__.file)),
                            case: :lower
                          )
  @schema "~/.claude/dfcm/receipt.schema.json"
  # A court command that runs one script file: `sh|bash|dash|zsh|python3 <file>`.
  @script_command ~r/\A\s*(?:\S*\/)?(?:sh|bash|dash|zsh|python3?)\s+([^\s;&|<>'"$`\-][^\s;&|<>'"$`]*)(?:\s|\z)/
  # Caller env the courts read (beyond MIX_ENV, GGEN_IGNITER_DIR and
  # GC23_FLEET_RECEIPTS_DIR, always recorded), by prefix.
  @replay_env_prefixes ~w(GC23_ DFCM_)
  @shell_safe ~r/\A[A-Za-z0-9_@%+=:,.\/-]+\z/
  @github ~r{\A(?:https?://(?:[^@/]+@)?github\.com/|git@github\.com:|ssh://git@github\.com/)([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?\z}

  # LLM-provider event rules, each with its own court's words: GC23-5
  # (witness 2: an LLM word in a provider/executor/leased_to attribute or in a
  # provider:* relationship) and GC23-9 (`measure`: a relationship to a
  # Provider object with deterministic=false or an LLM-named id, or an LLM
  # word in a provider/producer/candidate_producer attribute).
  @gc23_5_words ~w(zcode claude anthropic openai glm zai)
  @gc23_5_keys ~w(provider executor leased_to)
  @gc23_9_words ~w(llm claude anthropic openai zcode glm zai)
  @gc23_9_keys ~w(provider producer candidate_producer)
  @terminal ~r/\A(?:ALIVE\z|BLOCKED|UNSUPPORTED|REFUSED)/

  @switches [
    checkpoint: :string,
    graph: :string,
    receipts_dir: :string,
    order_receipts_dir: :keep,
    only: :keep,
    timeout: :integer,
    repo: :string,
    stop_query: :string,
    validator: :string,
    ggen_igniter_dir: :string
  ]

  @impl Mix.Task
  def run(args) do
    # Config WITHOUT app.start: the court runs shell courts and parses RDF; it boots no Repo.
    Mix.Task.run("loadconfig")

    case cli(args) do
      0 -> :ok
      code -> exit({:shutdown, code})
    end
  end

  @doc "Runs the court for `args` and returns the exit code (0 STOP, 1 not STOP, 2 cannot run)."
  @spec cli([String.t()]) :: 0 | 1 | 2
  def cli(args) do
    case court(args) do
      {:ok, %{stop: stop} = report} ->
        print(report)
        if stop, do: 0, else: 1

      {:error, reason} ->
        Mix.shell().error("stop court could not run: #{inspect(reason)}")
        2
    end
  end

  @doc """
  Runs the court and returns the report map (`:stop`, `:gates`, `:orders`,
  `:stop_receipt`, ...) without printing, or `{:error, reason}`.
  """
  @spec court([String.t()]) :: {:ok, map()} | {:error, term()}
  def court(args) do
    with {:ok, opts} <- parse(args),
         {:ok, repo} <- repo_root(opts[:repo]),
         {:ok, paths} <- paths(opts),
         {:ok, validator} <- validator(opts[:validator]),
         graph_path = abs(paths.graph, repo),
         {:ok, bytes} <- read(graph_path),
         {:ok, graph} <- turtle(bytes, graph_path),
         :ok <- no_asserted_receipts(graph),
         {:ok, root} <- root(graph, opts[:checkpoint]),
         {:ok, stop_query} <- stop_query(root, graph_path, opts),
         {:ok, gates} <- gates(graph, root),
         {:ok, selected} <- select(gates, only(opts)),
         {:ok, subject_sha} <- git(repo, ["rev-parse", "HEAD"]) do
      court_env = court_env(repo, paths.ggen_igniter_dir)

      ctx = %{
        checkpoint: opts[:checkpoint],
        opts: opts,
        repo: repo,
        subject_sha: subject_sha,
        base_sha: base_sha(root, subject_sha),
        graph_path: graph_path,
        graph_hash: "sha256:" <> sha256_hex(bytes),
        receipts_dir: abs(paths.receipts_dir, repo),
        order_receipts_dirs: order_receipts_dirs(paths, repo),
        timeout_ms: (opts[:timeout] || @default_timeout_s) * 1000,
        validator: validator,
        court_env: court_env,
        ggen_igniter_sha: ggen_igniter_sha(court_env)
      }

      ctx =
        Map.merge(ctx, %{
          identity: repo_identity(repo),
          verifier: verifier(ctx, stop_query),
          toolchain: toolchain(),
          replay_env: replay_env(court_env)
        })

      File.mkdir_p!(ctx.receipts_dir)
      ran = Map.new(selected, &{&1.id, run_gate(&1, ctx)})

      gates = Enum.map(gates, &Map.put(&1, :ran, Map.get(ran, &1.id)))
      orders = orders(graph, root, ctx)

      judged_paths =
        Enum.map(gates, &gate_receipt_path(&1, ctx)) ++
          (orders |> Enum.reject(& &1.conflict) |> Enum.map(& &1.receipt_path))

      with {:ok, verdicts} <- validate(judged_paths, ctx) do
        gates = Enum.map(gates, &judge_gate(&1, ctx, verdicts))
        orders = Enum.map(orders, &judge_order(&1, verdicts))

        with {:ok, stop} <- ask(graph, gates, orders, stop_query) do
          counters = release_counters(gates, orders, ctx)
          stop_receipt = write_stop_receipt(stop, gates, orders, counters, ctx)

          stop_verdict =
            case validate([stop_receipt], ctx) do
              {:ok, verdicts} -> Map.get(verdicts, stop_receipt, :missing)
              {:error, _} -> :refused
            end

          {:ok,
           %{
             checkpoint: ctx.checkpoint,
             repo: repo,
             subject_sha: subject_sha,
             court_env: court_env,
             receipts_dir: ctx.receipts_dir,
             order_receipts_dir: hd(ctx.order_receipts_dirs).dir,
             order_receipts_dirs: ctx.order_receipts_dirs,
             graph: graph_path,
             gates: gates,
             orders: orders,
             stop: stop,
             stop_receipt: stop_receipt,
             stop_receipt_verdict: stop_verdict,
             release_counters: counters
           }}
        end
      end
    end
  end

  @doc """
  The checkpoint registry: checkpoint identifier -> default `:graph` and
  `:receipts_dir` (relative to the repository root), the ordered
  `:order_receipts_dirs` (`{:repo, rel}` relative to the repository root,
  `{:ggen_igniter, rel}` relative to the resolved `GGEN_IGNITER_DIR`) and
  `:ggen_igniter_dir` (exported to court commands as `GGEN_IGNITER_DIR`).
  """
  @spec checkpoints() :: %{String.t() => %{atom() => term()}}
  def checkpoints, do: @checkpoints

  @doc "The court exit code that means the gate's machinery has not landed (standing UNKNOWN)."
  @spec unknown_exit() :: 75
  def unknown_exit, do: @unknown_exit

  @doc """
  The court exit code that means every witness held and the one open item is
  an edge the court may not close (standing `BLOCKED:<reason>` from a typed
  `BLOCKED(<reason>): ... (broken_term <term>)` last line).
  """
  @spec blocked_exit() :: 77
  def blocked_exit, do: @blocked_exit

  @doc """
  The contract tuple digest: `"sha256:" <> hex(sha256(canonical JSON))` over
  exactly the tuple fields, keys sorted, compact separators, `exclusions`
  sorted (the same bytes as Python's
  `json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`).
  """
  @spec tuple_digest(map()) :: String.t()
  def tuple_digest(%{} = tuple) do
    encoded =
      @tuple_fields
      |> Enum.sort()
      |> Enum.map(fn
        "exclusions" = field -> {field, tuple |> Map.fetch!(field) |> Enum.sort()}
        field -> {field, Map.fetch!(tuple, field)}
      end)
      |> Jason.OrderedObject.new()
      |> Jason.encode!()

    "sha256:" <> sha256_hex(encoded)
  end

  @doc """
  Rewrites a SPARQL ASK into its existence-equivalent SELECT (`SELECT *` +
  `LIMIT 1`): the ASK is true iff the rewritten query yields a row.
  """
  @spec ask_as_select(String.t()) :: {:ok, String.t()} | {:error, :not_an_ask_query}
  def ask_as_select(query) when is_binary(query) do
    if Regex.match?(@ask, query) do
      {:ok, Regex.replace(@ask, query, "\\1SELECT *", global: false) <> "\nLIMIT 1\n"}
    else
      {:error, :not_an_ask_query}
    end
  end

  # ------------------------------------------------------------------ options

  defp parse(args) do
    case OptionParser.parse(args, strict: @switches) do
      {opts, [], []} ->
        if is_binary(opts[:checkpoint]) and opts[:checkpoint] != "",
          do: {:ok, opts},
          else: {:error, {:missing_option, "--checkpoint"}}

      {_opts, rest, invalid} ->
        {:error, {:invalid_arguments, rest ++ Enum.map(invalid, &elem(&1, 0))}}
    end
  end

  # Explicit options win; a registered checkpoint fills the rest; an
  # unregistered checkpoint must name every path.
  defp paths(opts) do
    defaults = Map.get(@checkpoints, opts[:checkpoint], %{})

    explicit_order_dirs =
      case opts |> Keyword.get_values(:order_receipts_dir) |> Enum.filter(&present/1) do
        [] -> nil
        dirs -> Enum.map(dirs, &{:option, &1})
      end

    resolved = %{
      graph: present(opts[:graph]) || defaults[:graph],
      receipts_dir: present(opts[:receipts_dir]) || defaults[:receipts_dir],
      order_receipts_dirs: explicit_order_dirs || defaults[:order_receipts_dirs]
    }

    case for({key, flag} <- @path_options, resolved[key] == nil, do: flag) do
      [] ->
        ggen_igniter_dir =
          present(opts[:ggen_igniter_dir]) || present(System.get_env("GGEN_IGNITER_DIR")) ||
            defaults[:ggen_igniter_dir]

        {:ok, Map.put(resolved, :ggen_igniter_dir, ggen_igniter_dir)}

      missing ->
        {:error, {:unregistered_checkpoint, opts[:checkpoint], missing}}
    end
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil

  # The ordered order-receipts directories, absolute and de-duplicated, each
  # with the typed probe of the repository that holds it (`checkout/1`). A
  # `{:ggen_igniter, _}` entry resolves against the same GGEN_IGNITER_DIR the
  # court env exports and is dropped when none is known.
  defp order_receipts_dirs(paths, repo) do
    paths.order_receipts_dirs
    |> Enum.flat_map(fn
      {:repo, rel} ->
        [{"repo", Path.expand(rel, repo)}]

      {:option, dir} ->
        [{"option", Path.expand(dir, repo)}]

      {:ggen_igniter, rel} ->
        case paths.ggen_igniter_dir do
          nil -> []
          dir -> [{"ggen_igniter", Path.expand(rel, Path.expand(dir))}]
        end
    end)
    |> Enum.uniq_by(fn {_origin, dir} -> dir end)
    |> Enum.map(fn {origin, dir} -> Map.merge(%{dir: dir, origin: origin}, checkout(dir)) end)
  end

  # The repository holding an order-receipts dir, typed; a git failure is
  # never reported as "no git checkout" (`probe`, `repo` toplevel, `head`
  # object id, `why` = the reason `head` is nil):
  #
  #   * `:ok`          - toplevel and HEAD commit id (SHA-1, or SHA-256 in a
  #                      `--object-format=sha256` repository);
  #   * `:absent`      - the directory does not exist;
  #   * `:no_checkout` - git finds no repository AND no ancestor of the
  #                      directory holds a `.git` entry (an independent
  #                      filesystem observation, not a parse of git's message);
  #   * `:unborn`      - a checkout whose HEAD branch has no commit (proven:
  #                      `symbolic-ref` names the branch, `show-ref` exits 1);
  #   * `:git_failed`  - git could not answer although a `.git` is there
  #                      (dubious ownership, corrupt HEAD, not a work tree, git
  #                      missing), or git's toplevel is not the directory that
  #                      holds the nearest `.git` (a skipped nested repository).
  defp checkout(dir) do
    if File.dir?(dir),
      do: probe_checkout(dir, git_holder(dir)),
      else: probe(:absent, "directory absent")
  end

  defp probe_checkout(dir, holder) do
    case git(dir, ["rev-parse", "--show-toplevel"]) do
      {:ok, root} ->
        case same_dir(root, holder) do
          :same -> probe_head(dir, root)
          mismatch -> probe(:git_failed, inspect(mismatch), root)
        end

      {:error, {:git_failed, _args, _code, _out}} when holder == nil ->
        probe(:no_checkout, "no git checkout holds the receipt dir")

      {:error, reason} ->
        probe(:git_failed, inspect(reason))
    end
  end

  defp probe_head(dir, root) do
    case git(dir, ["rev-parse", "--verify", "HEAD"]) do
      {:ok, head} ->
        if Regex.match?(@object_id, head),
          do: %{probe: :ok, repo: root, head: head, why: nil},
          else: probe(:git_failed, inspect({:not_an_object_id, head}), root)

      {:error, reason} ->
        # Unborn only when proven; otherwise the original git failure stands.
        with {:ok, ref} <- git(dir, ["symbolic-ref", "--quiet", "HEAD"]),
             {:error, {:git_failed, _args, 1, ""}} <-
               git(dir, ["show-ref", "--verify", "--quiet", ref]) do
          probe(:unborn, "HEAD #{ref} has no commit (unborn branch)", root)
        else
          _not_proven -> probe(:git_failed, inspect(reason), root)
        end
    end
  end

  defp probe(kind, why, root \\ nil), do: %{probe: kind, repo: root, head: nil, why: why}

  # The nearest ancestor (or the directory itself) holding a `.git` entry (a
  # directory, or the file of a linked worktree / submodule).
  defp git_holder(dir) do
    dir |> Path.expand() |> ancestors() |> Enum.find(&File.exists?(Path.join(&1, ".git")))
  end

  defp ancestors(path) do
    case Path.dirname(path) do
      ^path -> [path]
      parent -> [path | ancestors(parent)]
    end
  end

  # Same directory by inode (git prints the resolved path: /private/var for /var).
  defp same_dir(root, nil), do: {:toplevel_mismatch, root, nil}

  defp same_dir(root, holder) do
    with {:ok, a} <- File.stat(root),
         {:ok, b} <- File.stat(holder) do
      if {a.major_device, a.inode} == {b.major_device, b.inode},
        do: :same,
        else: {:toplevel_mismatch, root, holder}
    else
      {:error, posix} -> {:stat_failed, root, holder, posix}
    end
  end

  # XAAS_DIR is always the repository root under judgement (the receipts'
  # subject_sha is its HEAD); GGEN_IGNITER_DIR is exported only when known.
  defp court_env(repo, nil), do: %{"XAAS_DIR" => repo}

  defp court_env(repo, ggen_igniter_dir),
    do: %{"XAAS_DIR" => repo, "GGEN_IGNITER_DIR" => Path.expand(ggen_igniter_dir)}

  defp ggen_igniter_sha(%{"GGEN_IGNITER_DIR" => dir}) do
    with true <- File.dir?(dir),
         {:ok, sha} <- git(dir, ["rev-parse", "HEAD"]),
         true <- Regex.match?(@sha, sha) do
      sha
    else
      _ -> nil
    end
  end

  defp ggen_igniter_sha(_env), do: nil

  defp only(opts) do
    opts
    |> Keyword.get_values(:only)
    |> Enum.flat_map(&String.split(&1, ",", trim: true))
    |> Enum.map(&String.trim/1)
  end

  defp repo_root(nil) do
    case git(File.cwd!(), ["rev-parse", "--show-toplevel"]) do
      {:ok, top} -> {:ok, top}
      {:error, _} -> {:error, {:not_a_git_repository, File.cwd!()}}
    end
  end

  defp repo_root(path) do
    path = Path.expand(path)

    case git(path, ["rev-parse", "--show-toplevel"]) do
      {:ok, top} -> {:ok, top}
      {:error, _} -> {:error, {:not_a_git_repository, path}}
    end
  end

  defp validator(path) do
    path = Path.expand(path || "~/.claude/dfcm/validate_receipt.py")

    cond do
      System.find_executable("python3") == nil -> {:error, {:validator_unavailable, "python3"}}
      not File.regular?(path) -> {:error, {:validator_unavailable, path}}
      true -> {:ok, path}
    end
  end

  defp abs(path, repo), do: Path.expand(path, repo)

  defp read(path) do
    case File.read(path) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> {:error, {:unreadable, path, reason}}
    end
  end

  defp turtle(bytes, path) do
    case RDF.Turtle.read_string(bytes) do
      {:ok, graph} -> {:ok, graph}
      {:error, reason} -> {:error, {:unparseable_graph, path, reason}}
    end
  end

  # ------------------------------------------------------------------ graph

  defp no_asserted_receipts(graph) do
    asserted =
      for {s, p, o} <- RDF.Graph.triples(graph),
          to_string(p) == @sj <> "receipt" or
            (to_string(p) == @rdf_type and to_string(o) == @sj <> "Receipt"),
          uniq: true,
          do: to_string(s)

    if asserted == [], do: :ok, else: {:error, {:graph_asserts_receipts, asserted}}
  end

  defp root(graph, checkpoint) do
    graph
    |> typed(@sj <> "GoalCheckpoint")
    |> Enum.filter(&(identifier(&1) == checkpoint))
    |> case do
      [root] -> {:ok, root}
      [] -> {:error, {:unknown_checkpoint, checkpoint}}
      many -> {:error, {:ambiguous_checkpoint, checkpoint, length(many)}}
    end
  end

  defp stop_query(root, graph_path, opts) do
    with {:ok, query} <-
           single_literal(root, "stopQuery", {:root_without_stop_query, root.subject}) do
      file = opts[:stop_query] && abs(opts[:stop_query], Path.dirname(graph_path))
      beside = Path.join(Path.dirname(graph_path), "stop.rq")

      cond do
        file && not File.regular?(file) ->
          {:error, {:unreadable, file, :enoent}}

        file ->
          same_query(query, file)

        File.regular?(beside) ->
          same_query(query, beside)

        true ->
          {:ok, query}
      end
    end
  end

  defp same_query(query, file) do
    if String.trim(File.read!(file)) == String.trim(query),
      do: {:ok, query},
      else: {:error, {:stop_query_drift, file}}
  end

  defp gates(graph, root) do
    graph
    |> typed(@sj <> "GoalCheckpoint")
    |> Enum.filter(&(root.subject in values(&1, "checkpointOf")))
    |> Enum.reduce_while({:ok, []}, fn desc, {:ok, acc} ->
      with {:ok, id} <- required(identifier(desc), {:gate_without_identifier, desc.subject}),
           {:ok, command} <-
             single_literal(desc, "courtCommand", {:gate_without_court_command, id}) do
        gate = %{
          id: id,
          iri: desc.subject,
          command: command,
          boundary: desc |> values("boundaryClass") |> Enum.map(&local_name/1) |> Enum.join(",")
        }

        {:cont, {:ok, [gate | acc]}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, []} -> {:error, {:checkpoint_without_gates, identifier(root)}}
      {:ok, gates} -> {:ok, Enum.sort_by(gates, &natural(&1.id))}
      error -> error
    end
  end

  defp select(gates, []), do: {:ok, gates}

  defp select(gates, only) do
    ids = MapSet.new(gates, & &1.id)

    case Enum.reject(only, &MapSet.member?(ids, &1)) do
      [] -> {:ok, Enum.filter(gates, &(&1.id in only))}
      unknown -> {:error, {:unknown_gates, unknown}}
    end
  end

  # Every WorkOrder with `sj:checkpointOf+` the root: on the root itself or on
  # one of its gates, transitively (the same set the stop query's
  # `?order sj:checkpointOf+ ?gc` ranges over).
  defp orders(graph, root, ctx) do
    under = checkpoint_closure(graph, root.subject)

    graph
    |> typed(@sj <> "WorkOrder")
    |> Enum.filter(fn desc -> Enum.any?(values(desc, "checkpointOf"), &(&1 in under)) end)
    |> Enum.map(fn desc ->
      id = identifier(desc) || to_string(desc.subject)

      Map.merge(
        %{
          id: id,
          iri: desc.subject,
          successor?: RDF.iri(@sj <> "Successor") in values(desc, "boundaryClass"),
          tuple: order_tuple(graph, desc)
        },
        locate(id, ctx.order_receipts_dirs)
      )
    end)
    |> Enum.sort_by(&natural(&1.id))
  end

  # Where an order's receipt comes from: `<dir>/<id>.json` in every
  # order-receipts dir, in order. Not found -> the first dir's path (judged
  # MISSING). Found once, or the same bytes found several times -> the first
  # hit. Different bytes in two dirs -> `conflict` (never a silent pick).
  defp locate(id, [first | _] = dirs) do
    hits =
      for dir <- dirs,
          path = Path.join(dir.dir, id <> ".json"),
          File.regular?(path),
          do: {dir, path}

    found = Enum.map(hits, &elem(&1, 1))

    case hits do
      [] ->
        %{
          receipt_path: Path.join(first.dir, id <> ".json"),
          source: nil,
          found: [],
          conflict: nil
        }

      [{dir, path} | rest] ->
        bytes = File.read!(path)

        if Enum.all?(rest, fn {_dir, other} -> File.read!(other) == bytes end),
          do: %{receipt_path: path, source: dir, found: found, conflict: nil},
          else: %{receipt_path: path, source: nil, found: found, conflict: found}
    end
  end

  # The root plus every node that reaches it over sj:checkpointOf edges.
  defp checkpoint_closure(graph, root_iri) do
    checkpoint_of = RDF.iri(@sj <> "checkpointOf")

    edges =
      for {s, p, o} <- RDF.Graph.triples(graph), p == checkpoint_of, do: {s, o}

    grow(MapSet.new([root_iri]), edges)
  end

  defp grow(set, edges) do
    next =
      Enum.reduce(edges, set, fn {child, parent}, acc ->
        if MapSet.member?(acc, parent), do: MapSet.put(acc, child), else: acc
      end)

    if MapSet.size(next) == MapSet.size(set), do: set, else: grow(next, edges)
  end

  defp order_tuple(graph, desc) do
    capability =
      case values(desc, "requiresCapability") do
        [cap] ->
          graph |> RDF.Graph.description(cap) |> values("capabilityId") |> Enum.map(&lexical/1)

        many ->
          many
      end

    scalars = [
      {"subject", desc |> values("subject") |> Enum.map(&lexical/1)},
      {"postcondition", desc |> values("postcondition") |> Enum.map(&lexical/1)},
      {"capability", capability},
      {"evidence_ceiling", desc |> values("evidenceCeiling") |> Enum.map(&lexical/1)},
      {"authority_ceiling", desc |> values("authorityCeiling") |> Enum.map(&lexical/1)},
      {"consequence_class", desc |> values("consequenceClass") |> Enum.map(&lexical/1)}
    ]

    exclusions = desc |> values("exclusion") |> Enum.map(&lexical/1)

    Enum.reduce_while(scalars, {:ok, %{"exclusions" => exclusions}}, fn
      {field, [value]}, {:ok, acc} when is_binary(value) ->
        {:cont, {:ok, Map.put(acc, field, value)}}

      {field, []}, _acc ->
        {:halt, {:incomplete, field}}

      {field, _many}, _acc ->
        {:halt, {:ambiguous, field}}
    end)
    |> case do
      {:ok, tuple} -> {:ok, tuple, tuple_digest(tuple)}
      refusal -> refusal
    end
  end

  defp typed(graph, class) do
    class = RDF.iri(class)

    graph
    |> RDF.Graph.descriptions()
    |> Enum.filter(&(class in RDF.Description.get(&1, RDF.iri(@rdf_type), [])))
  end

  defp values(nil, _local), do: []
  defp values(desc, local), do: RDF.Description.get(desc, RDF.iri(@sj <> local), [])

  defp identifier(desc) do
    case RDF.Description.get(desc, RDF.iri(@dcterms_identifier), []) ++ values(desc, "identity") do
      [id | _] -> lexical(id)
      [] -> nil
    end
  end

  defp single_literal(desc, local, error) do
    case values(desc, local) do
      [value] -> {:ok, lexical(value)}
      _ -> {:error, error}
    end
  end

  defp required(nil, error), do: {:error, error}
  defp required(value, _error), do: {:ok, value}

  defp base_sha(root, subject_sha) do
    case values(root, "baseSha") |> Enum.map(&lexical/1) do
      [sha] -> if Regex.match?(@sha, sha), do: sha, else: subject_sha
      _ -> subject_sha
    end
  end

  defp lexical(%RDF.Literal{} = literal), do: RDF.Literal.lexical(literal)
  defp lexical(term), do: to_string(term)

  defp local_name(term) do
    term |> to_string() |> String.split(["#", "/"]) |> List.last()
  end

  defp natural(id) do
    ~r/(\d+)/
    |> Regex.split(id, include_captures: true, trim: true)
    |> Enum.map(fn part ->
      case Integer.parse(part) do
        {n, ""} -> {0, n}
        _ -> {1, part}
      end
    end)
  end

  # ------------------------------------------------------------------ run

  defp run_gate(gate, ctx) do
    # The script is read before it runs: its digest is the court that judged.
    script = court_script(gate.command, ctx)
    started = System.monotonic_time(:millisecond)

    {status, exit_code, digest, tail} =
      shell(gate.command, ctx.repo, ctx.timeout_ms, ctx.court_env)

    duration_ms = System.monotonic_time(:millisecond) - started

    {standing, outcome, broken_term} = judge_exit(status, exit_code, tail)
    path = gate_receipt_path(gate, ctx)

    summary =
      case status do
        :timeout -> "timeout after #{ctx.timeout_ms} ms; process group killed"
        :exited -> last_line(tail)
      end

    receipt = %{
      "identity" => identity_json("#{ctx.checkpoint}/#{gate.id}", ctx),
      "authority" => %{"ceiling" => "OBSERVE", "grant" => "NONE", "actor" => "xaas.stop_court"},
      "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
      "verifier" =>
        Map.merge(ctx.verifier, %{
          "court_command" => gate.command,
          "court_command_sha256" => "sha256:" <> sha256_hex(gate.command)
        })
        |> Map.merge(script),
      "toolchain" => ctx.toolchain,
      "replay" => %{
        "commands" => [
          %{
            "cmd" => gate.command,
            "cwd" => ctx.repo,
            "exit" => exit_code,
            "summary" => summary,
            "output_sha256" => digest,
            "invocation" => invocation(ctx, [gate.id])
          }
        ],
        "durable_location" => Path.relative_to(path, ctx.repo)
      },
      "standing" =>
        %{
          "value" => standing,
          "derived_from" =>
            "court command of #{ctx.checkpoint}/#{gate.id} exited #{exit_code}" <>
              " (#{outcome}) at #{ctx.subject_sha}; ALIVE iff exit 0, BLOCKED iff exit" <>
              " #{@blocked_exit} with a typed BLOCKED(<reason>) (broken_term <term>) line"
        }
        |> put_broken_term(broken_term),
      "gate" => %{
        "checkpoint" => ctx.checkpoint,
        "gate" => gate.id,
        "boundary_class" => gate.boundary,
        "duration_ms" => duration_ms,
        "timeout_ms" => ctx.timeout_ms,
        "timed_out" => status == :timeout,
        "outcome" => outcome,
        "env" => ctx.court_env,
        "ggen_igniter_sha" => ctx.ggen_igniter_sha
      }
    }

    File.write!(path, Jason.encode!(receipt, pretty: true) <> "\n")

    %{
      exit: exit_code,
      duration_ms: duration_ms,
      timed_out: status == :timeout,
      outcome: outcome
    }
  end

  # {standing, outcome, broken_term} of one court run (the exit-code contract
  # in the moduledoc). A BLOCKED standing needs the court's typed last line;
  # an exit 77 without one witnesses nothing and is court_failed.
  defp judge_exit(:exited, 0, _tail), do: {"ALIVE", "passed", nil}

  defp judge_exit(:exited, @blocked_exit, tail) do
    case blocked_line(tail) do
      {:ok, reason, term} -> {"BLOCKED:" <> reason, "blocked", term}
      :error -> {"UNKNOWN", "court_failed", nil}
    end
  end

  defp judge_exit(status, exit_code, _tail), do: {"UNKNOWN", outcome(status, exit_code), nil}

  @doc """
  Parses a court's typed BLOCKED line (its last non-empty output line):
  `{:ok, reason, broken_term}` for `BLOCKED(<reason>): ... (broken_term
  <term>)` with `<term>` one of the R schema's broken terms, else `:error`.
  """
  @spec blocked_line(String.t()) :: {:ok, String.t(), String.t()} | :error
  def blocked_line(output) when is_binary(output) do
    line =
      output
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> List.last() || ""

    with [_, reason] <- Regex.run(@blocked_line, line),
         [_, term] <- Regex.run(~r/\(broken_term ([A-Za-z_]+)\)\s*\z/, line),
         true <- term in @broken_terms do
      {:ok, reason, term}
    else
      _ -> :error
    end
  end

  defp put_broken_term(standing, nil), do: standing
  defp put_broken_term(standing, term), do: Map.put(standing, "broken_term", term)

  defp outcome(:timeout, _exit_code), do: "timeout"
  defp outcome(:exited, 0), do: "passed"
  defp outcome(:exited, @unknown_exit), do: "machinery_absent"
  defp outcome(:exited, _exit_code), do: "court_failed"

  defp gate_receipt_path(gate, ctx), do: Path.join(ctx.receipts_dir, gate.id <> ".json")

  # `/bin/sh -c command` in its own process group (perl setpgrp wrapper, the
  # same one Xaas.Ultracode.ZcodePackage uses), under a deadline; the group is
  # reaped on every exit path. MIX_ENV is unset; court_env (XAAS_DIR,
  # GGEN_IGNITER_DIR) is exported.
  defp shell(command, cwd, timeout_ms, court_env) do
    alarm_s = div(timeout_ms + 999, 1000) + @alarm_grace_s

    env =
      [{~c"MIX_ENV", false}] ++
        Enum.map(court_env, fn {key, value} -> {to_charlist(key), to_charlist(value)} end)

    port =
      Port.open({:spawn_executable, @perl}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :hide,
        {:cd, to_charlist(cwd)},
        {:env, env},
        {:args, ["-e", @wrapper, Integer.to_string(alarm_s), "/bin/sh", "-c", command]}
      ])

    os_pid =
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> pid
        _ -> nil
      end

    deadline = System.monotonic_time(:millisecond) + timeout_ms

    try do
      collect(port, deadline, :crypto.hash_init(:sha256), "")
    after
      if os_pid, do: ProcessGroup.kill(os_pid)

      try do
        Port.close(port)
      rescue
        ArgumentError -> :ok
      end
    end
  end

  defp collect(port, deadline, hash, tail) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, data}} ->
        tail = tail <> data
        size = byte_size(tail)

        tail =
          if size > @tail_bytes,
            do: binary_part(tail, size - @tail_bytes, @tail_bytes),
            else: tail

        collect(port, deadline, :crypto.hash_update(hash, data), tail)

      {^port, {:exit_status, status}} ->
        {:exited, status, hex(:crypto.hash_final(hash)), tail}
    after
      remaining -> {:timeout, @timeout_exit, hex(:crypto.hash_final(hash)), tail}
    end
  end

  defp last_line(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> List.last()
    |> case do
      nil -> "(no output)"
      line -> line |> String.replace(~r/[^[:print:]]/u, "") |> String.slice(0, 200)
    end
  end

  # ------------------------------------------------------------------ judge

  defp validate(paths, ctx) do
    existing = paths |> Enum.filter(&File.regular?/1) |> Enum.uniq()

    if existing == [] do
      {:ok, %{}}
    else
      {out, _code} = System.cmd("python3", [ctx.validator | existing], stderr_to_stdout: true)

      verdicts =
        out
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          case String.split(line, " ", parts: 2) do
            ["ADMITTED", path] -> Map.put(acc, path, :admitted)
            ["REFUSED", path] -> Map.put(acc, path, :refused)
            _ -> acc
          end
        end)

      case Enum.reject(existing, &Map.has_key?(verdicts, &1)) do
        [] -> {:ok, verdicts}
        unjudged -> {:error, {:validator_output_unreadable, unjudged, String.slice(out, 0, 400)}}
      end
    end
  end

  defp judge_gate(gate, ctx, verdicts) do
    path = gate_receipt_path(gate, ctx)
    subject = "#{ctx.checkpoint}/#{gate.id}"

    {verdict, receipt} = load(path, verdicts)

    linked? =
      verdict == :admitted and get_in(receipt, ["identity", "subject"]) == subject

    Map.merge(gate, %{
      receipt_path: path,
      verdict: verdict,
      receipt: receipt,
      linked?: linked?,
      standing: if(linked?, do: get_in(receipt, ["standing", "value"]), else: nil)
    })
  end

  # Different receipts for one order in two dirs: refused, never picked.
  defp judge_order(%{conflict: [_ | _] = paths} = order, _verdicts) do
    Map.merge(order, %{
      verdict: :refused,
      receipt: nil,
      digest: tuple_digest_or_nil(order.tuple),
      linked?: false,
      why_unlinked: {:duplicate_order_receipt, paths},
      standing: nil
    })
  end

  defp judge_order(order, verdicts) do
    {verdict, receipt} = load(order.receipt_path, verdicts)

    {digest, why_unlinked} =
      case order.tuple do
        {:ok, _tuple, digest} ->
          cond do
            verdict != :admitted ->
              {digest, verdict}

            get_in(receipt, ["identity", "tuple_digest"]) != digest ->
              {digest, :tuple_digest_mismatch}

            true ->
              {digest, nil}
          end

        refusal ->
          {nil, refusal}
      end

    linked? = why_unlinked == nil

    Map.merge(order, %{
      verdict: verdict,
      receipt: receipt,
      digest: digest,
      linked?: linked?,
      why_unlinked: why_unlinked,
      standing: if(linked?, do: get_in(receipt, ["standing", "value"]), else: nil)
    })
  end

  defp tuple_digest_or_nil({:ok, _tuple, digest}), do: digest
  defp tuple_digest_or_nil(_refusal), do: nil

  defp load(path, verdicts) do
    case Map.get(verdicts, path) do
      nil ->
        {:missing, nil}

      verdict ->
        case path |> File.read!() |> Jason.decode() do
          {:ok, %{} = receipt} -> {verdict, receipt}
          _ -> {:refused, nil}
        end
    end
  end

  # ------------------------------------------------------------------ ask

  defp ask(graph, gates, orders, stop_query) do
    projected =
      (gates ++ orders)
      |> Enum.filter(& &1.linked?)
      |> Enum.reduce(graph, fn node, acc ->
        receipt_iri =
          RDF.iri("urn:xaas:stop-court:receipt:" <> sha256_hex(File.read!(receipt_path(node))))

        acc
        |> RDF.Graph.add({node.iri, RDF.iri(@sj <> "receipt"), receipt_iri})
        |> RDF.Graph.add({receipt_iri, RDF.iri(@rdf_type), RDF.iri(@sj <> "Receipt")})
        |> RDF.Graph.add({receipt_iri, RDF.iri(@sj <> "standing"), RDF.literal(node.standing)})
        |> RDF.Graph.add(
          {receipt_iri, RDF.iri(@sj <> "subjectSha"),
           RDF.literal(get_in(node.receipt, ["identity", "subject_sha"]))}
        )
      end)

    with {:ok, select} <- ask_as_select(stop_query) do
      try do
        case GraphNif.query_turtle(RDF.NTriples.write_string!(projected), select) do
          {:ok, rows} -> {:ok, rows != []}
          {:error, reason} -> {:error, {:stop_query_failed, reason}}
        end
      rescue
        error in ErlangError -> {:error, {:query_engine_unavailable, inspect(error.original)}}
      end
    end
  end

  defp receipt_path(%{receipt_path: path}), do: path

  # ------------------------------------------------------------------ stop receipt

  defp write_stop_receipt(stop, gates, orders, counters, ctx) do
    path = Path.join(ctx.receipts_dir, "STOP-#{ctx.checkpoint}.json")
    linked = Enum.filter(gates, & &1.linked?)
    linked_orders = Enum.count(orders, & &1.linked?)

    gate_commands =
      Enum.flat_map(linked, fn gate ->
        gate.receipt |> get_in(["replay", "commands"]) |> List.wrap()
      end)

    alive = Enum.count(gates, &(&1.standing == "ALIVE"))
    command = "mix xaas.stop_court --checkpoint #{ctx.checkpoint}"

    receipt = %{
      "identity" => identity_json("#{ctx.checkpoint}/STOP", ctx),
      "authority" => %{"ceiling" => "OBSERVE", "grant" => "NONE", "actor" => "xaas.stop_court"},
      "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
      # The STOP court is the runner itself: its script is this module's source.
      "verifier" =>
        Map.merge(ctx.verifier, %{
          "court_command" => command,
          "court_command_sha256" => "sha256:" <> sha256_hex(command),
          "court_script" => @runner_source,
          "court_script_sha256" => @runner_source_sha256,
          "court_script_why" => nil,
          "court_script_at_subject" => ctx.verifier["runner_source_at_subject"],
          "court_script_at_subject_why" => ctx.verifier["runner_source_at_subject_why"]
        }),
      "toolchain" => ctx.toolchain,
      "release_counters" => counters,
      "replay" => %{
        "commands" =>
          gate_commands ++
            [
              %{
                "cmd" => command,
                "cwd" => ctx.repo,
                "exit" => if(stop, do: 0, else: 1),
                "summary" =>
                  "sj:stopQuery ASK over the goal graph + #{length(linked)} admitted gate receipts" <>
                    " + #{linked_orders}/#{length(orders)} linked order receipts: STOP=#{stop}",
                "invocation" => invocation(ctx, only(ctx.opts))
              }
            ],
        "durable_location" => Path.relative_to(path, ctx.repo)
      },
      "standing" => %{
        "value" => if(stop, do: "ALIVE", else: "UNKNOWN"),
        "derived_from" =>
          "sj:stopQuery of #{ctx.checkpoint} at #{ctx.subject_sha}: #{alive}/#{length(gates)} gates ALIVE; STOP=#{stop}"
      },
      "stop" => %{
        "checkpoint" => ctx.checkpoint,
        "order_receipt_dirs" => Enum.map(ctx.order_receipts_dirs, &dir_json/1),
        "orders" => Enum.map(orders, &order_json/1)
      }
    }

    File.write!(path, Jason.encode!(receipt, pretty: true) <> "\n")
    path
  end

  defp dir_json(dir) do
    %{
      "dir" => dir.dir,
      "origin" => dir.origin,
      "repo" => dir.repo,
      "repo_head" => dir.head,
      "repo_head_why" => dir.why
    }
  end

  # Per order: where its receipt came from (dir + the HEAD of the repository
  # holding it, and whether those bytes are the blob committed at that HEAD),
  # every path it was found at, and the typed refusal if any.
  defp order_json(order) do
    source = order.source

    %{
      "order" => order.id,
      "tuple_digest" => order.digest,
      "verdict" => verdict_label(order.verdict, order.linked?),
      "linked" => order.linked?,
      "standing" => order.standing,
      "why_unlinked" => order.why_unlinked && inspect(order.why_unlinked),
      "found_in" => order.found,
      "receipt" => source && order.receipt_path,
      "receipt_sha256" => source && "sha256:" <> sha256_hex(File.read!(order.receipt_path)),
      "dir" => source && source.dir,
      "origin" => source && source.origin,
      "repo" => source && source.repo,
      "repo_head" => source && source.head,
      "repo_head_why" => source && source.why,
      "committed_at_head" => nil,
      "committed_at_head_why" => nil
    }
    |> Map.merge(commit_json(order.receipt_path, source))
    |> Map.merge(refusal_json(order.why_unlinked))
  end

  defp refusal_json({:duplicate_order_receipt, _paths}),
    do: %{"refusal" => "REFUSED(duplicate_order_receipt)", "broken_term" => "R_missing_identity"}

  defp refusal_json(_why), do: %{}

  # Whether the receipt bytes are exactly the blob at HEAD in the repository
  # holding them, typed three ways: `true`; `false` with the reason (no git
  # checkout, an unborn HEAD, no blob at that path in HEAD, different bytes);
  # `null` with the git failure when git could not answer, e.g. a directory
  # probe git refused (`:git_failed`) or an unreadable HEAD tree (never folded
  # into `false`). `ls-tree` is used rather than `rev-parse --verify --quiet
  # HEAD:./name`, which exits 1 silently for both "no such path" and "tree
  # object missing". Both git calls run in the receipt's own directory (paths
  # relative to it), so a symlinked path (macOS /var -> /private/var) cannot
  # mis-relativize.
  defp commit_json(_path, nil), do: %{}

  defp commit_json(path, source) do
    {state, why} = commit_state(path, source)
    %{"committed_at_head" => state, "committed_at_head_why" => why}
  end

  defp commit_state(_path, %{probe: :git_failed, why: why}), do: {nil, why}

  defp commit_state(_path, %{probe: probe, why: why})
       when probe in [:no_checkout, :unborn, :absent],
       do: {false, why}

  defp commit_state(path, %{probe: :ok}) do
    dir = Path.dirname(path)
    name = Path.basename(path)

    with {:ok, listing} <- git(dir, ["ls-tree", "HEAD", "--", name]),
         {:ok, hashed} <- git(dir, ["hash-object", "--", name]) do
      case Regex.run(~r/^\d+ blob ([0-9a-f]{40,64})\t/, listing) do
        [_, ^hashed] -> {true, nil}
        [_, _other] -> {false, "receipt bytes differ from the blob at HEAD"}
        nil -> {false, "HEAD has no blob at this path"}
      end
    else
      {:error, reason} -> {nil, inspect(reason)}
    end
  end

  # ------------------------------------------------------------------ release evidence (lane V23-S)

  # identity.repo is the GitHub slug; the observed worktree is its own field.
  defp identity_json(subject, ctx) do
    Map.merge(ctx.identity, %{
      "subject" => subject,
      "subject_sha" => ctx.subject_sha,
      "base_sha" => ctx.base_sha,
      "graph_hash" => ctx.graph_hash
    })
  end

  defp repo_identity(repo) do
    case github_slug(repo) do
      {:ok, slug, remote} ->
        %{
          "repo" => slug,
          "worktree" => repo,
          "repo_source" => "git remote #{remote} (github.com)"
        }

      {:none, why} ->
        %{"repo" => repo, "worktree" => repo, "repo_source" => why}
    end
  end

  @doc """
  The GitHub slug (`owner/name`) of the checkout at `dir`: the first remote
  (`origin` first, then by name) whose URL is on github.com, as
  `{:ok, slug, remote_name}`, else `{:none, reason}`. The URL itself (which
  may carry credentials) is never returned.
  """
  @spec github_slug(Path.t()) :: {:ok, String.t(), String.t()} | {:none, String.t()}
  def github_slug(dir) do
    case git(dir, ["remote"]) do
      {:ok, out} ->
        out
        |> String.split("\n", trim: true)
        |> Enum.sort_by(&{&1 != "origin", &1})
        |> Enum.find_value(
          {:none, "no github.com remote: identity.repo is the worktree path"},
          fn remote ->
            with {:ok, url} <- git(dir, ["remote", "get-url", remote]),
                 [_, owner, name] <- Regex.run(@github, url) do
              {:ok, owner <> "/" <> name, remote}
            else
              _ -> nil
            end
          end
        )

      {:error, reason} ->
        {:none, "git remote failed (#{inspect(reason)}): identity.repo is the worktree path"}
    end
  end

  defp verifier(ctx, stop_query) do
    {runner_at, runner_why} =
      blob_at_subject(ctx.repo, ctx.subject_sha, @runner_source, @runner_source_sha256)

    schema = Path.expand(@schema)
    {schema_sha, schema_why} = file_sha256(schema)
    {validator_sha, validator_why} = file_sha256(ctx.validator)

    %{
      "runner" => @runner,
      "runner_source" => @runner_source,
      "runner_source_sha256" => @runner_source_sha256,
      "runner_source_at_subject" => runner_at,
      "runner_source_at_subject_why" => runner_why,
      "validator" => ctx.validator,
      "validator_sha256" => validator_sha,
      "validator_why" => validator_why,
      "schema" => schema,
      "schema_sha256" => schema_sha,
      "schema_why" => schema_why,
      "stop_query_sha256" => "sha256:" <> sha256_hex(stop_query)
    }
  end

  defp file_sha256(path) do
    case File.read(path) do
      {:ok, bytes} -> {"sha256:" <> sha256_hex(bytes), nil}
      {:error, reason} -> {nil, "#{path} unreadable: #{:file.format_error(reason)}"}
    end
  end

  # The script a `sh|bash|python3 <file>` court command runs, read before it
  # runs: its digest, and whether those bytes are the blob at the subject.
  defp court_script(command, ctx) do
    case Regex.run(@script_command, command) do
      [_, file] ->
        abs = Path.expand(file, ctx.repo)

        case File.read(abs) do
          {:ok, bytes} ->
            digest = "sha256:" <> sha256_hex(bytes)

            {at, why} =
              case Path.relative_to(abs, ctx.repo) do
                ^abs -> {nil, "#{file} is outside the repository under judgement"}
                rel -> blob_at_subject(ctx.repo, ctx.subject_sha, rel, digest)
              end

            script_json(file, digest, nil, at, why)

          {:error, reason} ->
            why = "court script #{file} unreadable: #{:file.format_error(reason)}"
            script_json(file, nil, why, nil, why)
        end

      nil ->
        why = "the court command is inline (no script file); court_command_sha256 binds its text"
        script_json(nil, nil, why, nil, why)
    end
  end

  defp script_json(file, digest, why, at, at_why) do
    %{
      "court_script" => file,
      "court_script_sha256" => digest,
      "court_script_why" => why,
      "court_script_at_subject" => at,
      "court_script_at_subject_why" => at_why
    }
  end

  # Whether the bytes digested as `digest` are the blob at `rel` in commit
  # `sha` of `repo`: `{true, nil}`, `{false, reason}`, or `{nil, why}` when
  # git cannot answer (never folded into false).
  defp blob_at_subject(repo, sha, rel, digest) do
    if Path.type(rel) == :absolute do
      {nil, "#{rel} is not a repository-relative path"}
    else
      with {:ok, listing} <- git(repo, ["ls-tree", sha, "--", rel]) do
        case Regex.run(~r/^\d+ blob ([0-9a-f]{40,64})\t/, listing) do
          nil ->
            {false, "no blob at #{rel} in #{sha}"}

          [_, blob] ->
            case git_raw(repo, ["cat-file", "blob", blob]) do
              {:ok, bytes} ->
                if "sha256:" <> sha256_hex(bytes) == digest,
                  do: {true, nil},
                  else: {false, "the bytes differ from the blob at #{rel} in #{sha}"}

              {:error, reason} ->
                {nil, inspect(reason)}
            end
        end
      else
        {:error, reason} -> {nil, inspect(reason)}
      end
    end
  end

  defp toolchain do
    python3 = System.find_executable("python3")

    version =
      case python3 && System.cmd(python3, ["--version"], stderr_to_stdout: true) do
        {out, 0} -> String.trim(out)
        _ -> nil
      end

    %{
      "elixir" => System.version(),
      "otp_release" => List.to_string(:erlang.system_info(:otp_release)),
      "erts_version" => List.to_string(:erlang.system_info(:version)),
      "python3" => version,
      "python3_path" => python3
    }
  end

  # MIX_ENV (this court's own), GGEN_IGNITER_DIR (the resolved court env) and
  # GC23_FLEET_RECEIPTS_DIR (the caller's; nil when unset) always, plus every
  # other GC23_*/DFCM_* variable of the caller.
  defp replay_env(court_env) do
    caller =
      for {key, value} <- System.get_env(),
          Enum.any?(@replay_env_prefixes, &String.starts_with?(key, &1)),
          into: %{},
          do: {key, value}

    Map.merge(caller, %{
      "MIX_ENV" => to_string(Mix.env()),
      "GGEN_IGNITER_DIR" => court_env["GGEN_IGNITER_DIR"],
      "GC23_FLEET_RECEIPTS_DIR" => present(System.get_env("GC23_FLEET_RECEIPTS_DIR"))
    })
  end

  # The exact invocation that reproduces a receipt: every explicit option,
  # resolved as the court resolved it, then `--only`.
  defp invocation(ctx, only) do
    opts = ctx.opts

    optional = fn
      true, args -> args
      _, _args -> []
    end

    argv =
      ["mix", "xaas.stop_court", "--checkpoint", ctx.checkpoint] ++
        optional.(opts[:repo] != nil, ["--repo", ctx.repo]) ++
        optional.(present(opts[:graph]) != nil, ["--graph", ctx.graph_path]) ++
        optional.(present(opts[:receipts_dir]) != nil, ["--receipts-dir", ctx.receipts_dir]) ++
        (opts
         |> Keyword.get_values(:order_receipts_dir)
         |> Enum.filter(&present/1)
         |> Enum.flat_map(&["--order-receipts-dir", Path.expand(&1, ctx.repo)])) ++
        optional.(opts[:stop_query] != nil, [
          "--stop-query",
          Path.expand(opts[:stop_query] || "", Path.dirname(ctx.graph_path))
        ]) ++
        optional.(opts[:validator] != nil, ["--validator", ctx.validator]) ++
        optional.(present(opts[:ggen_igniter_dir]) != nil, [
          "--ggen-igniter-dir",
          Path.expand(opts[:ggen_igniter_dir] || "")
        ]) ++
        optional.(opts[:timeout] != nil, ["--timeout", to_string(opts[:timeout])]) ++
        Enum.flat_map(only, &["--only", &1])

    env = ctx.replay_env
    cwd = File.cwd!()
    unset = for {key, nil} <- Enum.sort(env), do: " -u " <> key
    set = for {key, value} <- Enum.sort(env), value != nil, do: " #{key}=#{shell_quote(value)}"

    %{
      "argv" => argv,
      "env" => env,
      "cwd" => cwd,
      "shell" =>
        "cd #{shell_quote(cwd)} && env" <>
          Enum.join(unset) <> Enum.join(set) <> " " <> Enum.map_join(argv, " ", &shell_quote/1)
    }
  end

  defp shell_quote(value) do
    if Regex.match?(@shell_safe, value),
      do: value,
      else: "'" <> String.replace(value, "'", "'\\''") <> "'"
  end

  # ARD section 27 counters, derived from this run and the observed episode
  # evidence; a counter whose source cannot be read is null with `why`.
  defp release_counters(gates, orders, ctx) do
    registry = Map.get(@checkpoints, ctx.checkpoint, %{})

    episodes =
      case registry[:episodes] do
        %{dir: dir, known_reference: known} ->
          episode_counters(Path.expand(dir, ctx.repo), known)

        nil ->
          why = "checkpoint #{ctx.checkpoint} registers no episodes directory"

          Map.new(
            ~w(REQUIRED_LLM_KNOWN LLM_INVOCATIONS_ON_KNOWN_REFERENCE_PATH UNRECEIPTED_ACTUATION),
            &{&1, %{"value" => nil, "why" => why, "source" => nil, "rule" => nil}}
          )
      end

    episodes
    |> Map.put("REQUIRED_UNKNOWN", required_unknown(gates, orders, ctx))
    |> Map.put(
      "UNCLASSIFIED_REQUIRED_WORK",
      unclassified_required_work(registry[:classification_check], ctx)
    )
  end

  defp required_unknown(gates, orders, ctx) do
    required_orders = Enum.reject(orders, & &1.successor?)

    items =
      for(
        gate <- gates,
        not terminal?(gate.standing),
        do: "gate #{gate.id}: #{standing_label(gate)}"
      ) ++
        for order <- required_orders,
            not terminal?(order.standing),
            do: "order #{order.id}: #{standing_label(order)}"

    %{
      "value" => length(items),
      "why" => nil,
      "items" => items,
      "source" =>
        "this court run at #{ctx.subject_sha}: #{length(gates)} gates of #{ctx.checkpoint} judged from" <>
          " #{ctx.receipts_dir} and #{length(required_orders)} non-Successor WorkOrders under it" <>
          " judged against the order-receipts dirs",
      "rule" =>
        "a gate or a non-Successor WorkOrder counts unless its linked, validator-ADMITTED receipt" <>
          " has a terminal standing (ALIVE, BLOCKED*, UNSUPPORTED*, REFUSED*)"
    }
  end

  defp terminal?(nil), do: false
  defp terminal?(standing), do: Regex.match?(@terminal, standing)

  defp standing_label(%{standing: nil} = node),
    do: "no linked receipt (#{verdict_label(node.verdict, node.linked?)})"

  defp standing_label(%{standing: standing}), do: standing

  defp unclassified_required_work(nil, ctx) do
    %{
      "value" => nil,
      "why" => "checkpoint #{ctx.checkpoint} registers no fleet classification check (GC23-11)",
      "source" => nil,
      "rule" => nil
    }
  end

  defp unclassified_required_work(%{court: court, argv: [_exe, script | _] = argv}, ctx) do
    command = Enum.map_join(argv, " ", &shell_quote/1)
    {court_sha, _why} = file_sha256(Path.expand(court, ctx.repo))

    base = %{
      "source" =>
        "GC23-11 court step 1 (#{court} #{court_sha || "absent"}) re-executed at #{ctx.subject_sha}",
      "rule" =>
        "the violation count check-classification reports (`REFUSED (N violations)`, exit 1);" <>
          " 0 on `OK` (exit 0); any other outcome could not run and is null",
      "command" => command,
      "cwd" => ctx.repo
    }

    if File.regular?(Path.expand(script, ctx.repo)) do
      {status, code, digest, tail} = shell(command, ctx.repo, ctx.timeout_ms, ctx.court_env)
      summary = last_line(tail)
      base = Map.merge(base, %{"exit" => code, "output_sha256" => digest, "summary" => summary})
      refused = Regex.run(~r/\Acheck-classification: REFUSED \((\d+) violations?\)/, summary)

      cond do
        status == :exited and code == 0 and
            String.starts_with?(summary, "check-classification: OK") ->
          Map.merge(base, %{"value" => 0, "why" => nil, "items" => []})

        status == :exited and code == 1 and refused != nil ->
          items =
            tail
            |> String.split("\n", trim: true)
            |> Enum.filter(&String.starts_with?(&1, "REFUSED("))

          Map.merge(base, %{
            "value" => refused |> List.last() |> String.to_integer(),
            "why" => nil,
            "items" => items
          })

        true ->
          Map.merge(base, %{
            "value" => nil,
            "why" => "check-classification could not run (#{status} #{code}): #{summary}"
          })
      end
    else
      Map.merge(base, %{"value" => nil, "why" => "#{script} absent in #{ctx.repo}"})
    end
  end

  @doc """
  The episode-derived release counters (ARD section 27) over `dir`, each
  `%{"value" => integer | nil, "why" => ...}`:

    * `"LLM_INVOCATIONS_ON_KNOWN_REFERENCE_PATH"`: LLM-provider events
      (`llm_provider_events/1`) summed over `<dir>/<name>/ocel.json` for each
      known-reference episode `name`;
    * `"REQUIRED_LLM_KNOWN"`: the known-reference episodes with at least one;
    * `"UNRECEIPTED_ACTUATION"`: `ledger.ndjson` lines of every episode
      directory under `dir` whose OCEL `StandingChanged` event (same
      `event_digest`) relates to no receipt a `ReceiptSealed` event sealed.

  An unreadable source (absent, not JSON, not an OCEL log, an unparseable
  ledger line) makes its counters `nil` with the reason, never 0.
  """
  @spec episode_counters(Path.t(), [String.t()]) :: %{String.t() => map()}
  def episode_counters(dir, known_reference) do
    llm_source =
      "LLM-provider events in " <>
        Enum.map_join(known_reference, ", ", &"#{&1}/ocel.json") <> " under #{dir}"

    llm_rule =
      "an OCEL event counts when the GC23-5 rule (a word of #{Enum.join(@gc23_5_words, "/")} in its" <>
        " provider/executor/leased_to attribute or in a provider:* relationship) or the GC23-9 rule" <>
        " (a relationship to a Provider object with deterministic=false or an id holding a word of" <>
        " #{Enum.join(@gc23_9_words, "/")}, or such a word in its provider/producer/candidate_producer" <>
        " attribute) holds"

    {invocations, required} =
      case known_path_llm(dir, known_reference) do
        {:ok, per} ->
          total =
            per |> Map.values() |> Enum.map(&length(&1["llm_provider_events"])) |> Enum.sum()

          using = for {name, %{"llm_provider_events" => [_ | _]}} <- per, do: name

          {%{"value" => total, "why" => nil, "episodes" => per},
           %{"value" => length(using), "why" => nil, "items" => Enum.sort(using)}}

        {:error, why} ->
          {%{"value" => nil, "why" => why}, %{"value" => nil, "why" => why}}
      end

    actuation =
      case unreceipted_actuations(dir) do
        {:ok, per} ->
          total = per |> Map.values() |> Enum.map(&length(&1["unreceipted"])) |> Enum.sum()
          %{"value" => total, "why" => nil, "episodes" => per}

        {:error, why} ->
          %{"value" => nil, "why" => why}
      end

    %{
      "LLM_INVOCATIONS_ON_KNOWN_REFERENCE_PATH" =>
        Map.merge(invocations, %{"source" => llm_source, "rule" => llm_rule}),
      "REQUIRED_LLM_KNOWN" =>
        Map.merge(required, %{
          "source" => llm_source,
          "rule" =>
            "the known-reference episodes with at least one LLM-provider event (#{llm_rule})"
        }),
      "UNRECEIPTED_ACTUATION" =>
        Map.merge(actuation, %{
          "source" => "every ledger.ndjson line of every episode directory under #{dir}",
          "rule" =>
            "a ledger actuation is receipted when its episode's ocel.json has a StandingChanged" <>
              " event with the same event_digest relating to a receipt:* object that a" <>
              " ReceiptSealed event relates to"
        })
    }
  end

  @doc """
  The ids of the LLM-provider events of a decoded OCEL log (`ocel:events`,
  `ocel:objects`): an event counts when the GC23-5 court rule or the GC23-9
  court rule (`measure`) holds for it, each with its own court's words.
  """
  @spec llm_provider_events(map()) :: [String.t()]
  def llm_provider_events(%{"ocel:events" => events, "ocel:objects" => objects}) do
    nondeterministic =
      for %{"type" => "Provider"} = object <- objects,
          Map.get(attributes(object), "deterministic") == "false" or
            word?(object["id"], @gc23_9_words),
          into: MapSet.new(),
          do: object["id"]

    for event <- events, gc23_5?(event) or gc23_9?(event, nondeterministic), do: event["id"]
  end

  defp gc23_5?(event) do
    attrs = attributes(event)

    Enum.any?(@gc23_5_keys, &(Map.has_key?(attrs, &1) and word?(attrs[&1], @gc23_5_words))) or
      Enum.any?(relationships(event), fn %{"objectId" => id} ->
        String.starts_with?(id, "provider:") and word?(id, @gc23_5_words)
      end)
  end

  defp gc23_9?(event, nondeterministic) do
    attrs = attributes(event)

    Enum.any?(relationships(event), &MapSet.member?(nondeterministic, &1["objectId"])) or
      Enum.any?(@gc23_9_keys, &word?(Map.get(attrs, &1, ""), @gc23_9_words))
  end

  defp word?(value, words) do
    text = if is_binary(value), do: value, else: Jason.encode!(value)
    text = String.downcase(text)
    Enum.any?(words, &String.contains?(text, &1))
  end

  defp attributes(item), do: Map.get(item, "attributes", %{})
  defp relationships(item), do: Map.get(item, "relationships", [])

  defp known_path_llm(dir, known) do
    Enum.reduce_while(known, {:ok, %{}}, fn name, {:ok, acc} ->
      path = Path.join([dir, name, "ocel.json"])

      case read_ocel(path) do
        {:ok, ocel, bytes} ->
          entry = %{
            "ocel" => path,
            "ocel_sha256" => "sha256:" <> sha256_hex(bytes),
            "events" => length(ocel["ocel:events"]),
            "llm_provider_events" => llm_provider_events(ocel)
          }

          {:cont, {:ok, Map.put(acc, name, entry)}}

        {:error, why} ->
          {:halt, {:error, why}}
      end
    end)
  end

  defp read_ocel(path) do
    with {:ok, bytes} <- read_source(path) do
      case Jason.decode(bytes) do
        {:ok, %{"ocel:events" => events, "ocel:objects" => objects} = ocel}
        when is_list(events) and is_list(objects) ->
          if Enum.all?(events ++ objects, &ocel_item?/1),
            do: {:ok, ocel, bytes},
            else:
              {:error,
               "#{path}: an OCEL event or object lacks a string id/type, an attributes map" <>
                 " or a relationships list of objectId strings"}

        {:ok, _other} ->
          {:error, "#{path} is not an OCEL log (no ocel:events/ocel:objects lists)"}

        {:error, error} ->
          {:error, "#{path} is not JSON: #{Exception.message(error)}"}
      end
    end
  end

  defp ocel_item?(%{"id" => id, "type" => type} = item) when is_binary(id) and is_binary(type) do
    rels = relationships(item)

    is_map(attributes(item)) and is_list(rels) and
      Enum.all?(rels, &match?(%{"objectId" => object_id} when is_binary(object_id), &1))
  end

  defp ocel_item?(_item), do: false

  defp read_source(path) do
    case File.read(path) do
      {:ok, bytes} -> {:ok, bytes}
      {:error, reason} -> {:error, "#{path} unreadable: #{:file.format_error(reason)}"}
    end
  end

  defp unreceipted_actuations(dir) do
    with {:ok, names} <- episode_dirs(dir) do
      Enum.reduce_while(names, {:ok, %{}}, fn name, {:ok, acc} ->
        case episode_actuations(Path.join(dir, name)) do
          {:ok, entry} -> {:cont, {:ok, Map.put(acc, name, entry)}}
          {:error, why} -> {:halt, {:error, why}}
        end
      end)
    end
  end

  defp episode_dirs(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        case entries |> Enum.filter(&File.dir?(Path.join(dir, &1))) |> Enum.sort() do
          [] -> {:error, "#{dir} holds no episode directory"}
          names -> {:ok, names}
        end

      {:error, reason} ->
        {:error, "#{dir} unreadable: #{:file.format_error(reason)}"}
    end
  end

  defp episode_actuations(episode) do
    ledger = Path.join(episode, "ledger.ndjson")

    with {:ok, bytes} <- read_source(ledger),
         {:ok, lines} <- ledger_lines(ledger, bytes),
         {:ok, sealed?} <- sealing(episode, lines) do
      {:ok,
       %{
         "ledger" => ledger,
         "ledger_sha256" => "sha256:" <> sha256_hex(bytes),
         "actuations" => length(lines),
         "unreceipted" =>
           for(
             line <- lines,
             not sealed?.(line),
             do: Jason.encode!(Map.take(line, ~w(seq identity from to event_digest)))
           )
       }}
    end
  end

  defp ledger_lines(path, bytes) do
    bytes
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _n} -> String.trim(line) == "" end)
    |> Enum.reduce_while({:ok, []}, fn {line, n}, {:ok, acc} ->
      case Jason.decode(line) do
        {:ok, %{} = entry} -> {:cont, {:ok, [entry | acc]}}
        _ -> {:halt, {:error, "#{path} line #{n} is not a JSON object"}}
      end
    end)
    |> case do
      {:ok, lines} -> {:ok, Enum.reverse(lines)}
      error -> error
    end
  end

  # An empty ledger has nothing to bind: its OCEL is not read.
  defp sealing(_episode, []), do: {:ok, fn _line -> true end}

  defp sealing(episode, _lines) do
    with {:ok, ocel, _bytes} <- read_ocel(Path.join(episode, "ocel.json")) do
      events = ocel["ocel:events"]

      sealed =
        for %{"type" => "ReceiptSealed"} = event <- events,
            %{"objectId" => "receipt:" <> _ = id} <- relationships(event),
            into: MapSet.new(),
            do: id

      {:ok,
       fn line ->
         digest = line["event_digest"]

         is_binary(digest) and
           Enum.any?(events, fn event ->
             event["type"] == "StandingChanged" and
               Map.get(attributes(event), "event_digest") == digest and
               Enum.any?(relationships(event), &MapSet.member?(sealed, &1["objectId"]))
           end)
       end}
    end
  end

  # ------------------------------------------------------------------ print

  defp print(report) do
    shell = Mix.shell()
    shell.info("stop court #{report.checkpoint} at #{report.subject_sha}")
    shell.info("graph #{report.graph}")

    shell.info(
      "court env " <>
        (report.court_env |> Enum.sort() |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{v}" end))
    )

    Enum.each(report.order_receipts_dirs, fn dir ->
      shell.info("order receipts #{dir.origin} #{dir.dir}" <> dir_label(dir))
    end)

    shell.info(row(["GATE", "BOUNDARY", "STANDING", "EXIT", "SECS", "RECEIPT", "SOURCE"]))

    Enum.each(report.gates, fn gate ->
      {exit_code, secs, source} =
        case gate.ran do
          nil ->
            {receipt_exit(gate.receipt), "-", "disk"}

          ran ->
            {to_string(ran.exit) <> if(ran.timed_out, do: "(timeout)", else: ""),
             :erlang.float_to_binary(ran.duration_ms / 1000, decimals: 1), "ran"}
        end

      shell.info(
        row([
          gate.id,
          gate.boundary,
          gate.standing || "NONE",
          exit_code,
          secs,
          verdict_label(gate.verdict, gate.linked?),
          source
        ])
      )
    end)

    Enum.each(report.orders, fn order ->
      shell.info(
        "order #{order.id} standing=#{order.standing || "NONE"} receipt=#{verdict_label(order.verdict, order.linked?)}" <>
          " digest=#{order.digest || "-"}" <>
          if(order.why_unlinked, do: " unlinked=#{inspect(order.why_unlinked)}", else: "") <>
          if(order.successor?, do: " successor=true", else: "") <>
          if(order.source,
            do: " from=#{order.source.origin}:#{order.source.dir}@#{order.source.head || "-"}",
            else: ""
          )
      )
    end)

    shell.info(
      "release counters " <>
        (report.release_counters
         |> Enum.sort()
         |> Enum.map_join(" ", fn {name, counter} ->
           "#{name}=#{if counter["value"] == nil, do: "null", else: counter["value"]}"
         end))
    )

    shell.info(
      "stop receipt #{report.stop_receipt} #{verdict_label(report.stop_receipt_verdict, true)}"
    )

    shell.info("STOP=#{report.stop}")
  end

  defp dir_label(%{probe: :ok} = dir), do: " (#{dir.repo} @ #{dir.head})"
  defp dir_label(%{probe: :no_checkout}), do: " (no git checkout)"
  defp dir_label(%{probe: :absent}), do: " (absent)"
  defp dir_label(%{probe: :unborn} = dir), do: " (#{dir.repo} @ unborn: #{dir.why})"
  defp dir_label(%{probe: :git_failed} = dir), do: " (#{dir.repo || "-"} git failed: #{dir.why})"

  defp receipt_exit(%{"replay" => %{"commands" => [%{"exit" => exit_code} | _]}}),
    do: to_string(exit_code)

  defp receipt_exit(_), do: "-"

  defp verdict_label(:missing, _), do: "MISSING"
  defp verdict_label(:refused, _), do: "REFUSED"
  defp verdict_label(:admitted, true), do: "ADMITTED"
  defp verdict_label(:admitted, false), do: "ADMITTED-UNLINKED"

  defp row(cells) do
    widths = [6, 10, 14, 12, 7, 18, 6]

    cells
    |> Enum.zip(widths)
    |> Enum.map_join(" ", fn {cell, width} -> String.pad_trailing(to_string(cell), width) end)
    |> String.trim_trailing()
  end

  # ------------------------------------------------------------------ util

  defp git(dir, args) do
    case System.cmd("git", ["-C", dir | args], stderr_to_stdout: true) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, code} -> {:error, {:git_failed, args, code, String.trim(out)}}
    end
  rescue
    error in ErlangError -> {:error, {:git_unavailable, inspect(error.original)}}
  end

  # Untrimmed stdout (blob bytes); stderr is discarded.
  defp git_raw(dir, args) do
    case System.cmd("sh", ["-c", "exec git -C \"$0\" \"$@\" 2>/dev/null", dir | args]) do
      {out, 0} -> {:ok, out}
      {_out, code} -> {:error, {:git_failed, args, code}}
    end
  rescue
    error in ErlangError -> {:error, {:git_unavailable, inspect(error.original)}}
  end

  defp sha256_hex(bytes), do: hex(:crypto.hash(:sha256, bytes))
  defp hex(bin), do: Base.encode16(bin, case: :lower)
end
