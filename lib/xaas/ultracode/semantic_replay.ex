defmodule Xaas.Ultracode.SemanticReplay do
  @moduledoc """
  Cold replay of a recorded no-LLM episode (GC-26.9.23 gate GC23-10; PRD
  PR-013; ARD sections 7 and 16; falsifiers F5 and F6).

  `replay/1` reconstructs, from durable artifacts only -- the episode's
  sealed XaaS receipts, its TransitionLog, its work graph and git refs --
  the five things PR-013 names:

    * **subject identity**: the subject ref's current tip, and per receipt
      its exact head, base and whether the head is still current over the
      order's `path_scope`;
    * **evidence**: every sealed receipt, integrity-checked
      (`SemanticReceipt.receipt_digest/1` recomputes), mapped by the graph
      side (`mix semantic_jira.xaas_receipt`) and re-admitted by the graph
      side (`mix semantic_jira.reconcile`) into a FRESH ledger;
    * **standing**: the projection of that re-derived ledger
      (`mix semantic_jira.frontier`, i.e. `SemanticJira.frontier_from_events/3`),
      never a stored standing;
    * **completed work**: the orders whose derived standing is ALIVE;
    * **current frontier**: eligible / blocked / events / ledger tail of the
      re-derived ledger.

  The committed TransitionLog is an input, not an authority: an event is
  admitted only when a receipt re-derives it. `SemanticJira.replay_check/2`
  (the graph side's KNOWN_REPLAY law, run by `mix run
  scripts/semantic_replay_task.exs`) compares the committed log's standing
  projection with the re-derived one.

  ## Typed divergence

  A replay that runs but cannot re-derive the recorded state is
  `DIVERGED`, never a crash, and every divergence carries a Chatman broken
  term:

    * `unreceipted_transition` (`R_missing_replay`): a committed event no
      receipt re-derives -- F5, a deleted receipt;
    * `subject_changed` (`R_missing_identity`): a commit after the receipt
      head touches the order's `path_scope` -- F6, the previously ALIVE
      standing no longer applies to the current subject;
    * `subject_rewritten`, `subject_absent`, `subject_ref_absent`
      (`R_missing_identity`): the receipt head is not on the subject line;
    * `receipt_digest_mismatch` (`R_missing_identity`), `receipt_unreadable`
      (`R_missing_replay`), `receipt_names_no_order`, `receipt_mapping_refused`,
      `reconcile_refused` (`mu_on_O`);
    * `transition_not_logged` (`R_not_fed_back`): a receipt the committed
      log never recorded; `transition_log_refused` (`R_missing_replay`): the
      graph side refuses the committed log (tampered/undecodable).

  ## Output

  `{:ok, envelope}` with `envelope["replay"]` = `"KNOWN_REPLAY"` (the law
  replays and nothing diverges) or `"DIVERGED"`; `envelope["state"]` is the
  reconstructed semantic state and `envelope["digest"]` =
  `"sha256:" <> hex(sha256(canonical_json(state)))`, canonical JSON = keys
  sorted by byte order, no insignificant whitespace (`canonical_json/1`).
  The state carries no path, timestamp, host or toolchain identity, so two
  replays of the same artifacts and refs are byte-identical, and the digest
  equals the one projected from the episode-time artifacts
  (`docs/sjira/v26.9.23/courts/replay_project.py`, recorded as the
  episode's `replay.json`). Sources, graph-side identity and the committed
  log's projection sit in the envelope beside the state.

  `{:refused, typed}` when the replay cannot run: the no-LLM guard (F3,
  `REFUSED(llm_credential_present)`, `mu_on_O`), a missing work graph or
  subject ref, or a graph side that does not build (`BUILD_BROKEN`).

  Options: `:episode_dir` (required), `:ggen_igniter_dir` (required),
  `:subject_repo` (default the ggen_igniter checkout: its refs are the
  repository's), `:subject_ref` (default the drive record's
  `subject.pinned`), `:ggen_build_path` (default a private APFS clone of
  `<ggen>/_build/<mix_env>`), `:mix_env` (`"test"`), `:scratch` (parent of
  the private work directory, removed afterwards), `:env` (what the no-LLM
  guard judges, default `System.get_env()`), `:timeout_s` (600),
  `:script` (default `scripts/semantic_replay_task.exs` under the cwd).
  """

  alias Xaas.Ultracode.{SemanticDrive, SemanticReceipt}

  @schema "xaas/semantic-replay/v1"
  @state_schema "xaas/semantic-replay-state/v1"
  @genesis "sha256:" <> String.duplicate("0", 64)
  @law_identity "semantic-jira:xaas_receipt+reconcile+frontier+replay_check"

  @git_env [
    {"GIT_CONFIG_NOSYSTEM", "1"},
    {"GIT_TERMINAL_PROMPT", "0"}
  ]

  @doc "The state schema the digest is taken over."
  @spec state_schema() :: String.t()
  def state_schema, do: @state_schema

  @doc """
  Canonical JSON: objects with keys sorted by byte order, arrays in order,
  compact separators, UTF-8 unescaped -- the same bytes as Python's
  `json.dumps(v, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`
  for the values a replay state holds.
  """
  @spec canonical_json(term()) :: String.t()
  def canonical_json(value), do: value |> ordered() |> Jason.encode!()

  @doc "`sha256:` + hex of `canonical_json/1`."
  @spec digest(term()) :: String.t()
  def digest(value),
    do: "sha256:" <> (:crypto.hash(:sha256, canonical_json(value)) |> Base.encode16(case: :lower))

  defp ordered(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), ordered(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp ordered(list) when is_list(list), do: Enum.map(list, &ordered/1)
  defp ordered(value), do: value

  @spec replay(keyword()) :: {:ok, map()} | {:refused, map()}
  def replay(opts) do
    env = Keyword.get(opts, :env) || System.get_env()

    case SemanticDrive.no_llm_guard(env) do
      :ok -> guarded(opts)
      {:refused, typed} -> {:refused, Map.put(typed, "step", "guard")}
    end
  end

  defp guarded(opts) do
    root = Keyword.get(opts, :scratch) || System.tmp_dir!()
    work = Path.join(root, "semantic-replay-#{System.unique_integer([:positive])}")
    File.mkdir_p!(work)

    try do
      with {:ok, ctx} <- context(opts, work),
           {:ok, ctx} <- toolchain(ctx),
           {:ok, ctx} <- map_receipts(ctx),
           {:ok, ctx} <- digest_receipts(ctx),
           {:ok, ctx} <- subjects(ctx),
           {:ok, ctx} <- reconstruct(ctx),
           {:ok, ctx} <- frontiers(ctx),
           {:ok, ctx} <- check(ctx) do
        {:ok, envelope(ctx)}
      end
    after
      File.rm_rf(work)
    end
  end

  # -- inputs -------------------------------------------------------------------

  defp context(opts, work) do
    episode = Path.expand(Keyword.fetch!(opts, :episode_dir))
    ggen = Path.expand(Keyword.fetch!(opts, :ggen_igniter_dir))
    mix_env = Keyword.get(opts, :mix_env, "test")

    with :ok <- present(File.regular?(Path.join(ggen, "mix.exs")), "ggen_igniter_missing", ggen),
         {:ok, graph} <- work_graph(episode),
         {:ok, drive} <- optional_json(Path.join(episode, "drive.json")),
         {:ok, ref} <- subject_ref(opts, drive) do
      script =
        Path.expand(
          Keyword.get(opts, :script) || Path.join(File.cwd!(), "scripts/semantic_replay_task.exs")
        )

      with :ok <- present(File.regular?(script), "replay_script_missing", script) do
        {:ok,
         %{
           episode: episode,
           ggen: ggen,
           mix_env: mix_env,
           work: work,
           script: script,
           timeout_s: Keyword.get(opts, :timeout_s, 600),
           build_path: Keyword.get(opts, :ggen_build_path),
           subject_repo: Path.expand(Keyword.get(opts, :subject_repo) || ggen),
           subject_ref: ref,
           graph: graph,
           work_graph_path: Path.join(episode, "work.json"),
           drive: drive,
           ledger_path: Path.join(episode, "ledger.ndjson"),
           receipts: receipt_files(episode),
           divergence: []
         }}
      end
    end
  end

  defp present(true, _reason, _detail), do: :ok

  defp present(false, reason, detail),
    do: {:refused, typed("UNKNOWN", reason, "mu_on_O", "context", %{"path" => detail})}

  defp work_graph(episode) do
    path = Path.join(episode, "work.json")

    with {:ok, body} <- File.read(path),
         {:ok, %{"work_orders" => orders} = graph} when is_list(orders) <- Jason.decode(body) do
      {:ok, graph}
    else
      _ ->
        {:refused,
         typed("UNKNOWN", "work_graph_unreadable", "R_missing_replay", "context", %{
           "path" => path
         })}
    end
  end

  defp optional_json(path) do
    with {:ok, body} <- File.read(path),
         {:ok, %{} = decoded} <- Jason.decode(body) do
      {:ok, decoded}
    else
      _ -> {:ok, nil}
    end
  end

  defp subject_ref(opts, drive) do
    case Keyword.get(opts, :subject_ref) || get_in(drive || %{}, ["subject", "pinned"]) do
      ref when is_binary(ref) and ref != "" ->
        {:ok, ref}

      _ ->
        {:refused,
         typed("UNKNOWN", "subject_ref_unknown", "R_missing_identity", "context", %{
           "why" => "no --subject-ref and no subject.pinned in the episode's drive.json"
         })}
    end
  end

  # The episode's sealed XaaS receipts: `receipt.json` plus `receipts/*.json`.
  defp receipt_files(episode) do
    main = Path.join(episode, "receipt.json")
    more = Path.wildcard(Path.join([episode, "receipts", "*.json"])) |> Enum.sort()
    if(File.regular?(main), do: [main], else: []) ++ more
  end

  # -- graph side -----------------------------------------------------------------

  defp toolchain(ctx) do
    build = ctx.build_path || clone_build(ctx)

    case SemanticDrive.graph_toolchain(ctx.ggen, build) do
      {:ok, toolchain} ->
        {:ok, Map.merge(ctx, %{build_path: build, toolchain: toolchain})}

      {:refused, typed} ->
        {:refused, Map.put(typed, "step", "toolchain")}
    end
  end

  # A private APFS clone (plain copy where cloning is unavailable) of the
  # checkout's build: the graph side never writes into the checkout itself.
  defp clone_build(ctx) do
    source = Path.join([ctx.ggen, "_build", ctx.mix_env])
    parent = Path.join(ctx.work, "ggen_build")
    File.mkdir_p!(parent)

    if File.dir?(source) do
      case System.cmd("cp", ["-cRp", source, parent], stderr_to_stdout: true) do
        {_, 0} -> :ok
        _ -> File.cp_r!(source, Path.join(parent, ctx.mix_env))
      end
    end

    Path.join(parent, ctx.mix_env)
  end

  defp ggen(ctx, task, args) do
    out_file = Path.join(ctx.work, "ggen-#{System.unique_integer([:positive])}.out")
    script = ~S(out="$1"; shift; exec "$@" >"$out" 2>&1 </dev/null)

    env =
      [
        {"MIX_ENV", ctx.mix_env},
        {"PATH", ctx.toolchain["path"]},
        {"ASDF_ELIXIR_VERSION", nil},
        {"ASDF_ERLANG_VERSION", nil},
        {"MIX_BUILD_PATH", ctx.build_path}
      ] ++ llm_unset()

    {_, code} =
      System.cmd(
        "/bin/sh",
        [
          "-c",
          script,
          "sh",
          out_file,
          "perl",
          "-e",
          "alarm shift; exec @ARGV or exit 127",
          Integer.to_string(ctx.timeout_s),
          ctx.toolchain["mix"],
          task | args
        ],
        cd: ctx.ggen,
        env: env
      )

    out = File.read!(out_file)
    File.rm(out_file)
    {code, last_json(out), out}
  end

  defp llm_unset do
    %{prefixes: prefixes, names: names} = SemanticDrive.llm_variables()

    for {name, _value} <- System.get_env(),
        name in names or Enum.any?(prefixes, &String.starts_with?(name, &1)),
        do: {name, nil}
  end

  defp build_broken(code, out, step) do
    if code != 0 and
         (String.contains?(out, "== Compilation error") or
            String.contains?(out, "could not compile dependency")) do
      {:refused,
       typed("BUILD_BROKEN", "graph_side_build_broken", "mu_unlawful", step, %{
         "exit" => code,
         "tail" => String.slice(out, -600, 600)
       })}
    else
      :ok
    end
  end

  # -- evidence: receipts -> reconciler receipts ------------------------------------

  defp map_receipts(ctx) do
    ctx.receipts
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, %{ctx | receipts: []}}, fn {path, index}, {:ok, acc} ->
      case map_receipt(acc, path, index) do
        {:ok, entry, divergence} ->
          {:cont,
           {:ok,
            %{acc | receipts: acc.receipts ++ [entry], divergence: acc.divergence ++ divergence}}}

        {:refused, _} = refused ->
          {:halt, refused}
      end
    end)
  end

  defp map_receipt(ctx, path, index) do
    base = %{path: path, name: Path.relative_to(path, ctx.episode), mapped: nil, ggen_digest: nil}

    with {:ok, body} <- File.read(path),
         {:ok, %{"bridge" => %{"identity" => identity} = bridge} = receipt} <- Jason.decode(body) do
      entry =
        Map.merge(base, %{
          identity: identity,
          receipt: receipt,
          bridge: bridge,
          receipt_digest: receipt["receipt_digest"]
        })

      if SemanticReceipt.receipt_digest(receipt) != receipt["receipt_digest"] do
        {:ok, entry,
         [
           divergence("receipt_digest_mismatch", "R_missing_identity", identity, %{
             "receipt" => entry.name,
             "recorded" => receipt["receipt_digest"],
             "recomputed" => SemanticReceipt.receipt_digest(receipt)
           })
         ]}
      else
        mapped = Path.join(ctx.work, "mapped-#{index}.json")

        case ggen(ctx, "semantic_jira.xaas_receipt", [
               "--bridge",
               path,
               "--xaas-receipt",
               path,
               "--out",
               mapped
             ]) do
          {0, _json, _out} ->
            {:ok, %{entry | mapped: mapped}, []}

          {code, json, out} ->
            with :ok <- build_broken(code, out, "evidence") do
              {:ok, entry,
               [
                 divergence("receipt_mapping_refused", "mu_on_O", identity, %{
                   "receipt" => entry.name,
                   "exit" => code,
                   "reason" => brief(json, out)
                 })
               ]}
            end
        end
      end
    else
      _ ->
        entry = Map.merge(base, %{identity: nil, receipt: nil, bridge: nil, receipt_digest: nil})

        {:ok, entry,
         [
           divergence("receipt_unreadable", "R_missing_replay", nil, %{"receipt" => base.name})
         ]}
    end
  end

  # The digest the Reconciler binds an event's `receipt_digest` to, computed
  # by the graph side's own `SemanticJira.digest/1`.
  defp digest_receipts(ctx) do
    mapped = for entry <- ctx.receipts, entry.mapped, do: entry.mapped

    if mapped == [] do
      {:ok, ctx}
    else
      out = Path.join(ctx.work, "digests.json")

      case ggen(ctx, "run", ["--no-start", ctx.script, "digest", out | mapped]) do
        {0, %{"ok" => true}, _} ->
          digests = out |> File.read!() |> Jason.decode!() |> Map.fetch!("digests")

          {:ok,
           %{
             ctx
             | receipts:
                 Enum.map(ctx.receipts, fn entry ->
                   %{entry | ggen_digest: entry.mapped && digests[entry.mapped]}
                 end)
           }}

        {code, json, out} ->
          with :ok <- build_broken(code, out, "evidence") do
            {:refused,
             typed("UNKNOWN", "graph_digest_failed", "mu_unlawful", "evidence", %{
               "exit" => code,
               "reason" => brief(json, out)
             })}
          end
      end
    end
  end

  # -- subject identity: git refs --------------------------------------------------

  defp subjects(ctx) do
    tip = rev(ctx.subject_repo, ctx.subject_ref)
    orders = Map.new(ctx.graph["work_orders"], &{&1["identity"], &1})

    {receipts, divergence} =
      Enum.map_reduce(ctx.receipts, ctx.divergence, fn entry, acc ->
        {subject, found} = subject(ctx, entry, Map.get(orders, entry.identity), tip)
        {Map.put(entry, :subject, subject), acc ++ found}
      end)

    {:ok, %{ctx | receipts: receipts, divergence: divergence} |> Map.put(:tip, tip)}
  end

  defp subject(_ctx, %{receipt: nil}, _order, _tip),
    do: {%{current: false, changed: [], head: nil}, []}

  defp subject(_ctx, entry, nil, _tip) do
    {%{current: false, changed: [], head: entry.receipt["final_head"]},
     [divergence("receipt_names_no_order", "mu_on_O", entry.identity, %{"receipt" => entry.name})]}
  end

  defp subject(ctx, entry, order, tip) do
    repo = ctx.subject_repo
    head = entry.receipt["final_head"]
    base = order["base_sha"]
    scope = order["path_scope"] || []

    detail = %{"receipt" => entry.name, "head" => head, "ref" => ctx.subject_ref, "tip" => tip}

    cond do
      is_nil(tip) ->
        {%{current: false, changed: [], head: head},
         [divergence("subject_ref_absent", "R_missing_identity", entry.identity, detail)]}

      not (is_binary(head) and commit?(repo, head)) or not ancestor?(repo, base, head) ->
        {%{current: false, changed: [], head: head},
         [
           divergence(
             "subject_absent",
             "R_missing_identity",
             entry.identity,
             Map.put(detail, "base", base)
           )
         ]}

      not ancestor?(repo, head, tip) ->
        {%{current: false, changed: [], head: head},
         [divergence("subject_rewritten", "R_missing_identity", entry.identity, detail)]}

      true ->
        case changed(repo, head, tip, scope) do
          [] ->
            {%{current: true, changed: [], head: head}, []}

          paths ->
            {%{current: false, changed: paths, head: head},
             [
               divergence(
                 "subject_changed",
                 "R_missing_identity",
                 entry.identity,
                 Map.merge(detail, %{"changed_paths" => paths, "path_scope" => scope})
               )
             ]}
        end
    end
  end

  defp rev(repo, ref) do
    case git(repo, ["rev-parse", "--verify", "--quiet", ref <> "^{commit}"]) do
      {out, 0} -> String.trim(out)
      _ -> nil
    end
  end

  defp commit?(repo, sha), do: match?({_, 0}, git(repo, ["cat-file", "-e", sha <> "^{commit}"]))

  defp ancestor?(_repo, nil, _descendant), do: false

  defp ancestor?(repo, ancestor, descendant),
    do: match?({_, 0}, git(repo, ["merge-base", "--is-ancestor", ancestor, descendant]))

  defp changed(_repo, same, same, _scope), do: []

  defp changed(repo, head, tip, scope) do
    case git(repo, ["diff", "--name-only", head, tip, "--" | scope]) do
      {out, 0} -> out |> String.split("\n", trim: true) |> Enum.sort()
      {out, _} -> ["<git diff failed: #{String.trim(out)}>"]
    end
  end

  defp git(repo, args),
    do:
      System.cmd("git", ["-C", repo | args], env: @git_env ++ llm_unset(), stderr_to_stdout: true)

  # -- standing: the TransitionLog re-derived from receipts ---------------------------

  defp reconstruct(ctx) do
    committed = committed_events(ctx.ledger_path)
    seq_of = Map.new(committed, &{&1["receipt_digest"], &1["seq"] || 0})
    admitted_ledger = Path.join(ctx.work, "admitted.ndjson")

    admissible =
      ctx.receipts
      |> Enum.filter(&(&1.mapped && &1.ggen_digest && &1.subject.current))
      |> Enum.sort_by(&{Map.get(seq_of, &1.ggen_digest, :unlogged), &1.receipt_digest})

    result =
      Enum.reduce_while(admissible, {:ok, %{}, []}, fn entry, {:ok, events, found} ->
        case ggen(ctx, "semantic_jira.reconcile", [
               "--work-orders",
               ctx.work_graph_path,
               "--ledger",
               admitted_ledger,
               "--receipt",
               entry.mapped
             ]) do
          {0, %{"event" => event}, _} ->
            {:cont, {:ok, Map.put(events, entry.path, event), found}}

          {code, json, out} ->
            case build_broken(code, out, "standing") do
              :ok ->
                {:cont,
                 {:ok, events,
                  found ++
                    [
                      divergence("reconcile_refused", "mu_on_O", entry.identity, %{
                        "receipt" => entry.name,
                        "exit" => code,
                        "reason" => brief(json, out)
                      })
                    ]}}

              refused ->
                {:halt, refused}
            end
        end
      end)

    with {:ok, events_by_receipt, found} <- result do
      receipts = Enum.map(ctx.receipts, &Map.put(&1, :event, events_by_receipt[&1.path]))
      admitted = events_by_receipt |> Map.values() |> Enum.uniq_by(& &1["event_digest"])

      {:ok,
       %{
         ctx
         | receipts: receipts,
           divergence: ctx.divergence ++ found ++ log_divergence(committed, admitted, receipts)
       }
       |> Map.merge(%{committed: committed, admitted: admitted, admitted_ledger: admitted_ledger})}
    end
  end

  defp log_divergence(committed, admitted, receipts) do
    admitted_digests = MapSet.new(admitted, & &1["event_digest"])
    committed_digests = MapSet.new(committed, & &1["event_digest"])
    receipt_digests = MapSet.new(receipts, & &1.ggen_digest)

    unreceipted =
      for event <- committed,
          not MapSet.member?(admitted_digests, event["event_digest"]),
          not MapSet.member?(receipt_digests, event["receipt_digest"]) do
        divergence("unreceipted_transition", "R_missing_replay", event["identity"], %{
          "event_digest" => event["event_digest"],
          "receipt_digest" => event["receipt_digest"],
          "seq" => event["seq"],
          "to" => event["to"]
        })
      end

    unlogged =
      for event <- admitted, not MapSet.member?(committed_digests, event["event_digest"]) do
        divergence("transition_not_logged", "R_not_fed_back", event["identity"], %{
          "event_digest" => event["event_digest"],
          "to" => event["to"]
        })
      end

    unreceipted ++ unlogged
  end

  # The committed log's events as recorded (file ledger: one JSON per line;
  # directory ledger: one JSON file per event). Integrity is the graph side's
  # verdict (`frontiers/1`), not this reader's.
  defp committed_events(path) do
    cond do
      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort()
        |> Enum.flat_map(&decode_event(File.read!(Path.join(path, &1))))

      File.regular?(path) ->
        path |> File.read!() |> String.split("\n", trim: true) |> Enum.flat_map(&decode_event/1)

      true ->
        []
    end
    |> Enum.sort_by(&(&1["seq"] || 0))
  end

  defp decode_event(json) do
    case Jason.decode(json) do
      {:ok, %{} = event} -> [event]
      _ -> []
    end
  end

  # -- frontier ---------------------------------------------------------------------

  defp frontiers(ctx) do
    committed_copy = copy_ledger(ctx.ledger_path, Path.join(ctx.work, "committed"))

    with {:ok, admitted} <- frontier(ctx, ctx.admitted_ledger, "frontier") do
      case frontier(ctx, committed_copy, "frontier") do
        {:ok, committed} ->
          {:ok, Map.merge(ctx, %{frontier: admitted, committed_frontier: committed})}

        {:refused, %{"standing" => "BUILD_BROKEN"}} = refused ->
          refused

        {:refused, typed} ->
          {:ok,
           %{
             ctx
             | divergence:
                 ctx.divergence ++
                   [
                     divergence("transition_log_refused", "R_missing_replay", nil, %{
                       "reason" => typed["detail"]
                     })
                   ]
           }
           |> Map.merge(%{frontier: admitted, committed_frontier: nil})}
      end
    end
  end

  defp copy_ledger(source, dir) do
    File.mkdir_p!(dir)
    dest = Path.join(dir, Path.basename(source))

    cond do
      File.dir?(source) -> File.cp_r!(source, dest)
      File.regular?(source) -> File.cp!(source, dest)
      true -> :absent
    end

    dest
  end

  defp frontier(ctx, ledger, step) do
    case ggen(ctx, "semantic_jira.frontier", [
           "--work-orders",
           ctx.work_graph_path,
           "--ledger",
           ledger
         ]) do
      {0, %{"status" => "ok"} = frontier, _} ->
        {:ok, frontier}

      {code, json, out} ->
        with :ok <- build_broken(code, out, step) do
          {:refused,
           typed("REFUSED(frontier_refused)", "frontier_refused", "R_missing_standing", step, %{
             "exit" => code,
             "reason" => brief(json, out)
           })}
        end
    end
  end

  # -- replay law: SemanticJira.replay_check/2 --------------------------------------------

  defp check(ctx) do
    expected = manifest(ctx, ctx.committed, expected_environment(ctx.drive))
    observed = manifest(ctx, ctx.admitted, "no-llm")
    expected_path = Path.join(ctx.work, "expected.json")
    observed_path = Path.join(ctx.work, "observed.json")
    out = Path.join(ctx.work, "replay_check.json")
    File.write!(expected_path, Jason.encode!(expected))
    File.write!(observed_path, Jason.encode!(observed))

    case ggen(ctx, "run", [
           "--no-start",
           ctx.script,
           "replay_check",
           expected_path,
           observed_path,
           out
         ]) do
      {0, %{"ok" => true}, _} ->
        {:ok, Map.put(ctx, :replay_check, out |> File.read!() |> Jason.decode!())}

      {code, json, text} ->
        with :ok <- build_broken(code, text, "replay") do
          {:refused,
           typed("UNKNOWN", "replay_check_failed", "mu_unlawful", "replay", %{
             "exit" => code,
             "reason" => brief(json, text)
           })}
        end
    end
  end

  defp expected_environment(%{"no_llm_guard" => "passed"}), do: "no-llm"
  defp expected_environment(_drive), do: "unguarded"

  defp manifest(ctx, events, environment) do
    orders = ctx.graph["work_orders"]

    %{
      "pack_subject" => "semantic-jira:episode:" <> to_string(ctx.graph["episode"]),
      "dependency_set" =>
        orders
        |> Enum.map(&"#{&1["identity"]}:#{digest(&1["dependencies"] || [])}")
        |> Enum.sort(),
      "graph_digest" => digest(orders),
      "consequence_set" => ["ledger_tail:" <> tail(events)],
      "toolchain_identity" => @law_identity,
      "environment_identity" => environment,
      "replay_identity" => "semantic-jira:v26.9.23:episode:" <> to_string(ctx.graph["episode"]),
      "standing_transitions" =>
        Enum.map(events, fn event ->
          %{
            "work_order_id" => event["identity"],
            "to_standing" => event["to"],
            "definition_digest" => event["definition_digest"],
            "event_digest" => event["event_digest"]
          }
        end)
    }
  end

  defp tail([]), do: @genesis
  defp tail(events), do: List.last(events)["event_digest"]

  # -- state ------------------------------------------------------------------------

  defp envelope(ctx) do
    state = state(ctx)
    known = state["replay"]["status"] == "KNOWN_REPLAY" and state["divergence"] == []

    %{
      "schema" => @schema,
      "replay" => if(known, do: "KNOWN_REPLAY", else: "DIVERGED"),
      "digest" => digest(state),
      "state" => state,
      "sources" => sources(ctx),
      "graph_side" => %{
        "sha" => rev(ctx.ggen, "HEAD"),
        "toolchain" => Map.take(ctx.toolchain, ~w(source elixir erlang))
      },
      "committed" =>
        ctx.committed_frontier &&
          Map.take(ctx.committed_frontier, ~w(standings events ledger_tail))
    }
  end

  @doc false
  @spec state(map()) :: map()
  def state(ctx) do
    frontier = ctx.frontier
    standings = frontier["standings"] || %{}

    %{
      "schema" => @state_schema,
      "episode" => ctx.graph["episode"],
      "checkpoint" => ctx.graph["checkpoint"],
      "subject" => %{
        "repositories" =>
          ctx.graph["work_orders"] |> Enum.map(& &1["repository"]) |> Enum.uniq() |> Enum.sort(),
        "ref" => ctx.subject_ref,
        "tip" => ctx.tip
      },
      "evidence" =>
        ctx.receipts
        |> Enum.map(&evidence/1)
        |> Enum.sort_by(&{&1["identity"] || "", &1["receipt_digest"] || ""}),
      "standing" => standings,
      "completed" => for({id, "ALIVE"} <- standings, do: id) |> Enum.sort(),
      "frontier" => %{
        "eligible" => Enum.map(frontier["eligible"] || [], & &1["identity"]),
        "blocked" =>
          Enum.map(
            frontier["blocked"] || [],
            &%{"identity" => &1["identity"], "reason" => &1["reason"]}
          ),
        "events" => frontier["events"],
        "ledger_tail" => frontier["ledger_tail"]
      },
      "replay" => replay_status(ctx.replay_check),
      "divergence" =>
        Enum.sort_by(ctx.divergence, &{&1["reason"], &1["identity"] || "", canonical_json(&1)})
    }
  end

  defp evidence(entry) do
    event = entry[:event]

    %{
      "identity" => entry.identity,
      "receipt_digest" => entry.receipt_digest,
      "base_sha" => entry.bridge && entry.bridge["base_sha"],
      "head" => entry.receipt && entry.receipt["final_head"],
      "outcome" => entry.receipt && entry.receipt["outcome"],
      "current" => entry.subject.current,
      "changed_paths" => entry.subject.changed,
      "admitted" => not is_nil(event),
      "event_digest" => event && event["event_digest"],
      "standing" => event && event["to"]
    }
  end

  defp replay_status(%{"ok" => true, "receipt" => receipt}),
    do: %{
      "status" => receipt["status"],
      "standing_projection" => receipt["standing_projection"] || %{}
    }

  defp replay_status(%{"ok" => false, "reason" => reason}),
    do: %{"status" => "REFUSED", "reason" => reason}

  defp sources(ctx) do
    files =
      [
        {"work_graph", ctx.work_graph_path},
        {"transition_log", ctx.ledger_path},
        {"drive_record", Path.join(ctx.episode, "drive.json")}
      ] ++ Enum.map(ctx.receipts, &{"receipt", &1.path})

    Enum.map(files, fn {class, path} ->
      %{
        "class" => class,
        "path" => Path.relative_to(path, ctx.episode),
        "sha256" => file_digest(path)
      }
    end) ++
      [
        %{
          "class" => "git_ref",
          "ref" => ctx.subject_ref,
          "sha" => ctx.tip,
          "repository" => ctx.subject_repo
        }
      ]
  end

  defp file_digest(path) do
    case File.read(path) do
      {:ok, bytes} -> "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
      _ -> nil
    end
  end

  # -- helpers ------------------------------------------------------------------------

  defp divergence(reason, broken_term, identity, detail),
    do: %{
      "reason" => reason,
      "broken_term" => broken_term,
      "identity" => identity,
      "detail" => detail
    }

  defp typed(standing, reason, broken_term, step, detail),
    do: %{
      "standing" => standing,
      "reason" => reason,
      "broken_term" => broken_term,
      "step" => step,
      "detail" => detail
    }

  defp brief(%{"reason" => reason}, _out), do: reason
  defp brief(%{} = json, _out), do: json
  defp brief(_nil, out), do: String.slice(out, -600, 600)

  defp last_json(out) do
    out
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      line = String.trim(line)

      if String.starts_with?(line, "{") do
        case Jason.decode(line) do
          {:ok, %{} = decoded} -> decoded
          _ -> nil
        end
      end
    end)
  end
end
