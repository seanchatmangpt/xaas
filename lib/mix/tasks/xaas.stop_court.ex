defmodule Mix.Tasks.Xaas.StopCourt do
  @shortdoc "Stop court for a GoalCheckpoint: run gate courts, write R receipts, ASK STOP (exit 0 = STOP)"

  @moduledoc """
  Stop court for a Semantic Jira `sj:GoalCheckpoint` (GC-FRI-0800, the Friday
  2026-09-25 08:00 PT checkpoint).

      mix xaas.stop_court --checkpoint GC-FRI-0800
      mix xaas.stop_court --checkpoint GC-FRI-0800 --only G6
      mix xaas.stop_court --checkpoint GC-FRI-0800 --graph PATH \\
        --receipts-dir PATH --order-receipts-dir PATH --timeout SECONDS

  For each gate (a `sj:GoalCheckpoint` with `sj:checkpointOf` the named root)
  it runs the gate's `sj:courtCommand` with `/bin/sh -c` from the repository
  root, in its own process group, under a deadline (`--timeout`, default 900
  seconds; the whole group is killed on timeout). It writes one R-schema gate
  receipt per gate to `<receipts-dir>/<gate>.json`
  (`~/.claude/dfcm/receipt.schema.json`: identity, authority, consequence,
  replay, standing). A gate's standing is `ALIVE` when its court command
  exited 0 and `UNKNOWN` otherwise (a failing or missing court witnesses
  nothing). `--only` (repeatable or comma-separated) runs just those gates;
  every other gate is judged by the receipt already on disk.

  STOP is the root's `sj:stopQuery`, a SPARQL ASK, evaluated over the goal
  graph plus one `sj:Receipt` node per receipt that
  `~/.claude/dfcm/validate_receipt.py` ADMITS:

    * gate receipts are linked only when `identity.subject` is
      `<checkpoint>/<gate>`;
    * each `sj:WorkOrder` with `sj:checkpointOf` the root is read from
      `<order-receipts-dir>/<identifier>.json` and linked only when its tuple
      is complete and `identity.tuple_digest` equals the order's tuple digest
      (`"sha256:" <> hex(sha256(canonical JSON))` over `subject`,
      `postcondition`, `capability` (the `sj:capabilityId`),
      `evidence_ceiling`, `authority_ceiling`, `consequence_class`,
      `exclusions` sorted; sorted keys, compact).

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
  `ALIVE` iff STOP, `UNKNOWN` otherwise), prints the per-gate table and
  `STOP=true|false`.

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

  @default_graph "docs/sjira/v26.9.22/friday/goal.ttl"
  @default_receipts_dir "docs/sjira/v26.9.22/friday/receipts"
  @default_order_receipts_dir "receipts/v26.9.22"
  @default_timeout_s 900

  @perl "/usr/bin/perl"
  @wrapper "setpgrp(0,0); alarm(shift @ARGV); exec @ARGV or exit 127;"
  @alarm_grace_s 2
  @timeout_exit 124
  @tail_bytes 4096

  @sha ~r/\A[0-9a-f]{40}\z/
  @ask ~r/\A((?:\s*(?:#[^\n]*(?:\n|\z)|(?:PREFIX|BASE)\b[^\n]*(?:\n|\z)))*\s*)ASK\b/i
  @tuple_fields ~w(subject postcondition capability evidence_ceiling authority_ceiling consequence_class exclusions)

  @switches [
    checkpoint: :string,
    graph: :string,
    receipts_dir: :string,
    order_receipts_dir: :string,
    only: :keep,
    timeout: :integer,
    repo: :string,
    stop_query: :string,
    validator: :string
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
         {:ok, validator} <- validator(opts[:validator]),
         graph_path = abs(opts[:graph] || @default_graph, repo),
         {:ok, bytes} <- read(graph_path),
         {:ok, graph} <- turtle(bytes, graph_path),
         :ok <- no_asserted_receipts(graph),
         {:ok, root} <- root(graph, opts[:checkpoint]),
         {:ok, stop_query} <- stop_query(root, graph_path, opts),
         {:ok, gates} <- gates(graph, root),
         {:ok, selected} <- select(gates, only(opts)),
         {:ok, subject_sha} <- git(repo, ["rev-parse", "HEAD"]) do
      ctx = %{
        checkpoint: opts[:checkpoint],
        repo: repo,
        subject_sha: subject_sha,
        base_sha: base_sha(root, subject_sha),
        graph_hash: "sha256:" <> sha256_hex(bytes),
        receipts_dir: abs(opts[:receipts_dir] || @default_receipts_dir, repo),
        order_receipts_dir: abs(opts[:order_receipts_dir] || @default_order_receipts_dir, repo),
        timeout_ms: (opts[:timeout] || @default_timeout_s) * 1000,
        validator: validator
      }

      File.mkdir_p!(ctx.receipts_dir)
      ran = Map.new(selected, &{&1.id, run_gate(&1, ctx)})

      gates = Enum.map(gates, &Map.put(&1, :ran, Map.get(ran, &1.id)))
      orders = orders(graph, root, ctx)

      judged_paths =
        Enum.map(gates, &gate_receipt_path(&1, ctx)) ++ Enum.map(orders, & &1.receipt_path)

      with {:ok, verdicts} <- validate(judged_paths, ctx) do
        gates = Enum.map(gates, &judge_gate(&1, ctx, verdicts))
        orders = Enum.map(orders, &judge_order(&1, verdicts))

        with {:ok, stop} <- ask(graph, gates, orders, stop_query) do
          stop_receipt = write_stop_receipt(stop, gates, ctx)

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
             graph: graph_path,
             gates: gates,
             orders: orders,
             stop: stop,
             stop_receipt: stop_receipt,
             stop_receipt_verdict: stop_verdict
           }}
        end
      end
    end
  end

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

  defp orders(graph, root, ctx) do
    graph
    |> typed(@sj <> "WorkOrder")
    |> Enum.filter(&(root.subject in values(&1, "checkpointOf")))
    |> Enum.map(fn desc ->
      id = identifier(desc) || to_string(desc.subject)

      %{
        id: id,
        iri: desc.subject,
        successor?: RDF.iri(@sj <> "Successor") in values(desc, "boundaryClass"),
        tuple: order_tuple(graph, desc),
        receipt_path: Path.join(ctx.order_receipts_dir, id <> ".json")
      }
    end)
    |> Enum.sort_by(&natural(&1.id))
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
      {:ok, %{"exclusions" => []}} -> {:incomplete, "exclusions"}
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
    started = System.monotonic_time(:millisecond)
    {status, exit_code, digest, tail} = shell(gate.command, ctx.repo, ctx.timeout_ms)
    duration_ms = System.monotonic_time(:millisecond) - started

    standing = if status == :exited and exit_code == 0, do: "ALIVE", else: "UNKNOWN"
    path = gate_receipt_path(gate, ctx)

    summary =
      case status do
        :timeout -> "timeout after #{ctx.timeout_ms} ms; process group killed"
        :exited -> last_line(tail)
      end

    receipt = %{
      "identity" => %{
        "subject" => "#{ctx.checkpoint}/#{gate.id}",
        "repo" => ctx.repo,
        "subject_sha" => ctx.subject_sha,
        "base_sha" => ctx.base_sha,
        "graph_hash" => ctx.graph_hash
      },
      "authority" => %{"ceiling" => "OBSERVE", "grant" => "NONE", "actor" => "xaas.stop_court"},
      "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
      "replay" => %{
        "commands" => [
          %{
            "cmd" => gate.command,
            "cwd" => ctx.repo,
            "exit" => exit_code,
            "summary" => summary,
            "output_sha256" => digest
          }
        ],
        "durable_location" => Path.relative_to(path, ctx.repo)
      },
      "standing" => %{
        "value" => standing,
        "derived_from" =>
          "court command of #{ctx.checkpoint}/#{gate.id} exited #{exit_code}" <>
            if(status == :timeout, do: " (timeout)", else: "") <>
            " at #{ctx.subject_sha}; ALIVE iff exit 0"
      },
      "gate" => %{
        "checkpoint" => ctx.checkpoint,
        "gate" => gate.id,
        "boundary_class" => gate.boundary,
        "duration_ms" => duration_ms,
        "timeout_ms" => ctx.timeout_ms,
        "timed_out" => status == :timeout
      }
    }

    File.write!(path, Jason.encode!(receipt, pretty: true) <> "\n")
    %{exit: exit_code, duration_ms: duration_ms, timed_out: status == :timeout}
  end

  defp gate_receipt_path(gate, ctx), do: Path.join(ctx.receipts_dir, gate.id <> ".json")

  # `/bin/sh -c command` in its own process group (perl setpgrp wrapper, the
  # same one Xaas.Ultracode.ZcodePackage uses), under a deadline; the group is
  # reaped on every exit path.
  defp shell(command, cwd, timeout_ms) do
    alarm_s = div(timeout_ms + 999, 1000) + @alarm_grace_s

    port =
      Port.open({:spawn_executable, @perl}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :hide,
        {:cd, to_charlist(cwd)},
        {:env, [{~c"MIX_ENV", false}]},
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

  defp write_stop_receipt(stop, gates, ctx) do
    path = Path.join(ctx.receipts_dir, "STOP-#{ctx.checkpoint}.json")
    linked = Enum.filter(gates, & &1.linked?)

    gate_commands =
      Enum.flat_map(linked, fn gate ->
        gate.receipt |> get_in(["replay", "commands"]) |> List.wrap()
      end)

    alive = Enum.count(gates, &(&1.standing == "ALIVE"))

    receipt = %{
      "identity" => %{
        "subject" => "#{ctx.checkpoint}/STOP",
        "repo" => ctx.repo,
        "subject_sha" => ctx.subject_sha,
        "base_sha" => ctx.base_sha,
        "graph_hash" => ctx.graph_hash
      },
      "authority" => %{"ceiling" => "OBSERVE", "grant" => "NONE", "actor" => "xaas.stop_court"},
      "consequence" => %{"commits" => [], "files_changed" => [], "remote_effects" => []},
      "replay" => %{
        "commands" =>
          gate_commands ++
            [
              %{
                "cmd" => "mix xaas.stop_court --checkpoint #{ctx.checkpoint}",
                "cwd" => ctx.repo,
                "exit" => if(stop, do: 0, else: 1),
                "summary" =>
                  "sj:stopQuery ASK over the goal graph + #{length(linked)} admitted gate receipts: STOP=#{stop}"
              }
            ],
        "durable_location" => Path.relative_to(path, ctx.repo)
      },
      "standing" => %{
        "value" => if(stop, do: "ALIVE", else: "UNKNOWN"),
        "derived_from" =>
          "sj:stopQuery of #{ctx.checkpoint} at #{ctx.subject_sha}: #{alive}/#{length(gates)} gates ALIVE; STOP=#{stop}"
      }
    }

    File.write!(path, Jason.encode!(receipt, pretty: true) <> "\n")
    path
  end

  # ------------------------------------------------------------------ print

  defp print(report) do
    shell = Mix.shell()
    shell.info("stop court #{report.checkpoint} at #{report.subject_sha}")
    shell.info("graph #{report.graph}")

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
          if(order.successor?, do: " successor=true", else: "")
      )
    end)

    shell.info(
      "stop receipt #{report.stop_receipt} #{verdict_label(report.stop_receipt_verdict, true)}"
    )

    shell.info("STOP=#{report.stop}")
  end

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

  defp sha256_hex(bytes), do: hex(:crypto.hash(:sha256, bytes))
  defp hex(bin), do: Base.encode16(bin, case: :lower)
end
