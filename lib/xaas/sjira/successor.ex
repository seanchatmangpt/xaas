defmodule Xaas.Sjira.Successor do
  @moduledoc """
  Successor intake (GC-26.9.23 gate GC23-12, Semantic Self-Hosting; PRD
  section 12, ARD sections 5.5, 9 and 24 M9; lane V23-H).

  A new bounded improvement enters as prose, never as a hand-authored
  backlog. After the first mile has compiled the successor prose
  (`scripts/sjira/prose_spans.py emit` over the recorded extraction, then
  ggen_igniter `mix semantic_jira.compile_prose` into
  `<dir>/compiled/{propositions,orders}.ttl`), `intake/1` runs the SAME
  closed-loop entry the no-LLM drive (`Xaas.Ultracode.SemanticDrive`) uses on
  the compiled orders, with no model anywhere on the path:

      no-LLM guard (F3)
      -> work graph: scripts/successor_work_graph.exs in the ggen_igniter
         checkout (the pack's bootstrap/work_orders.rq projection of
         <dir>/goal.ttl + <dir>/compiled/orders.ttl)          work.json
      -> mix semantic_jira.frontier (empty ledger)             frontier.json
      -> the first eligible order
      -> mix semantic_jira.descriptor --provider recipe        descriptor.json
      -> Xaas.Sa2a.Route.tuple(:order, row) + Route.resolve/1  resolution.json

  Every graph-side step is a real `mix` OS process in the ggen_igniter
  checkout (`SemanticDrive.graph_side/3`, under `SemanticDrive.graph_toolchain/2`
  and a private `MIX_BUILD_PATH`: an APFS clone of the checkout's
  `_build/<mix_env>` unless `:ggen_build_path` is given, so the judged
  checkout is never written).

  ## Typed successor items

  `classify/1` turns a work-order row into a successor item, never an error:

    * `Route.resolve/1` refuses `:unregistered_capability` for a canonical
      capability no registry entry serves -> `UNSUPPORTED(provider_capability)`
      (the capability is named, its provider is not registered; ARD section 9
      provider selection has nothing to select);
    * the compiler's placeholder `construct:unassigned` (no capability hint
      was admitted) -> `UNKNOWN` (`capability_unassigned`);
    * a registered capability -> `UNKNOWN` with `"route": "KNOWN"` and the
      provider (resolvable, not executed: the successor is not accepted work).

  The item's tuple digest is `Route.digest/1` of `Route.tuple(:order, row)`
  and must equal the row's `tuple_digest` (the pack's
  `Bootstrap.Graph.tuple_digest/1`, the stop court's contract); a difference
  is `REFUSED(tuple_digest_mismatch)` (broken term `admission_vacuous`). A row
  whose tuple the route cannot admit is `REFUSED(tuple_refused)`.

  ## Outputs

  `work.json`, `frontier.json`, `descriptor.json`, `resolution.json` in
  `:out_dir`: canonical JSON (keys sorted recursively, no timestamp, no
  absolute path), so two runs over the same inputs are byte-identical and a
  court can recompute them (`check/1`). `resolution.json` names the first
  eligible order's item (`"first"`) and classifies every eligible order
  (`"items"`).

  Nothing here admits prose, grants authority, executes a recipe or accepts
  the successor: operator acceptance of the prose is a separate edge the
  GC23-12 court reports.

  Options: `:dir` (required; holds `goal.ttl` and `compiled/orders.ttl`),
  `:ggen_igniter_dir` (required), `:out_dir` (default `<dir>/intake`),
  `:ggen_build_path`, `:mix_env` (`"test"`), `:timeout_s` (900), `:env`
  (the environment the no-LLM guard judges, default `System.get_env()`),
  `:script` (default `<cwd>/scripts/successor_work_graph.exs`), `:provider`
  (`"recipe"`), `:verifier_suite` (`"ggen-sync-check"`), `:aliases`
  (repository -> execution alias; default the repository's name).
  """

  alias Xaas.Sa2a.Route
  alias Xaas.Ultracode.{SemanticDrive, Verifier}

  @outputs ~w(work.json frontier.json descriptor.json resolution.json)
  @schema "xaas/successor-intake/v1"
  @provider "recipe"
  @verifier_suite "ggen-sync-check"
  @unassigned "construct:unassigned"

  @type typed :: %{required(String.t()) => term()}

  @doc "The files `intake/1` writes, in pipeline order."
  @spec outputs() :: [String.t()]
  def outputs, do: @outputs

  @doc """
  Runs the intake and writes `outputs/0` into `:out_dir`. Returns
  `{:ok, summary}` or `{:refused, typed}` (`"standing"`, `"reason"`,
  `"broken_term"`, `"hop"`, `"detail"`); `BUILD_BROKEN` when the graph side
  has no usable toolchain.
  """
  @spec intake(keyword()) :: {:ok, map()} | {:refused, typed()}
  def intake(opts) do
    with :ok <- SemanticDrive.no_llm_guard(Keyword.get(opts, :env, System.get_env())),
         {:ok, ctx} <- context(opts) do
      try do
        with {:ok, documents, summary} <- pipeline(ctx) do
          File.mkdir_p!(ctx.out_dir)

          for {name, document} <- documents,
              do: File.write!(Path.join(ctx.out_dir, name), encode(document))

          {:ok, summary}
        end
      after
        File.rm_rf(ctx.scratch)
      end
    end
  end

  @doc """
  Recomputes the intake into a private directory and compares it byte for
  byte with the committed `:out_dir`. `{:ok, summary}` when every output
  recomputes identically; `REFUSED(output_drift)` (broken term
  `R_missing_replay`) naming the differing files otherwise.
  """
  @spec check(keyword()) :: {:ok, map()} | {:refused, typed()}
  def check(opts) do
    committed = out_dir(opts)
    fresh = Path.join(System.tmp_dir!(), "successor-check-#{System.unique_integer([:positive])}")

    try do
      with {:ok, summary} <- intake(Keyword.put(opts, :out_dir, fresh)) do
        drifted =
          Enum.reject(@outputs, fn name ->
            File.read(Path.join(committed, name)) == File.read(Path.join(fresh, name))
          end)

        if drifted == [] do
          {:ok, Map.put(summary, "check", "outputs recompute byte-identically")}
        else
          {:refused,
           typed("REFUSED(output_drift)", "output_drift", "R_missing_replay", "check", %{
             "files" => drifted
           })}
        end
      end
    after
      File.rm_rf(fresh)
    end
  end

  @doc """
  Classifies one work-order row as a typed successor item (see the
  moduledoc). `{:ok, item}` or `{:refused, typed}` when the row's tuple is
  not admissible or its digest differs from the row's recorded
  `tuple_digest`.
  """
  @spec classify(map()) :: {:ok, map()} | {:refused, typed()}
  def classify(%{} = row) do
    case Route.tuple(:order, row) do
      {:ok, tuple} ->
        digest = Route.digest(tuple)

        if row["tuple_digest"] in [nil, digest] do
          {:ok, item(row, tuple, digest, Route.resolve(tuple))}
        else
          {:refused,
           typed(
             "REFUSED(tuple_digest_mismatch)",
             "tuple_digest_mismatch",
             "admission_vacuous",
             "route",
             %{
               "order" => row["identity"],
               "row_tuple_digest" => row["tuple_digest"],
               "route_tuple_digest" => digest
             }
           )}
        end

      {:refused, reason} ->
        {:refused,
         typed("REFUSED(tuple_refused)", "tuple_refused", "admission_vacuous", "route", %{
           "order" => row["identity"],
           "reason" => inspect(reason)
         })}
    end
  end

  defp item(row, tuple, digest, resolution) do
    capability = tuple["capability"]

    base = %{
      "order" => row["identity"],
      "iri" => row["iri"],
      "checkpoint_of" => row["checkpoint_of"],
      "capability" => capability,
      "provider" => capability |> String.split(":", parts: 2) |> hd(),
      "tuple_digest" => digest,
      "classification" => "Successor",
      "resolver" => "Xaas.Sa2a.Route.resolve/1"
    }

    case resolution do
      {:ok, {provider, recipe_id}} ->
        Map.merge(base, %{
          "resolve" => "ok",
          "route" => "KNOWN",
          "standing" => "UNKNOWN",
          "reason" => "provider_registered",
          "resolved" => %{"provider" => provider, "recipe_id" => recipe_id}
        })

      {:refused, :unregistered_capability} when capability == @unassigned ->
        Map.merge(base, %{
          "resolve" => "refused:unregistered_capability",
          "route" => "UNKNOWN",
          "standing" => "UNKNOWN",
          "reason" => "capability_unassigned"
        })

      {:refused, :unregistered_capability} ->
        Map.merge(base, %{
          "resolve" => "refused:unregistered_capability",
          "route" => "UNSUPPORTED",
          "standing" => "UNSUPPORTED(provider_capability)",
          "reason" => "provider_capability",
          "registered_capabilities" => registered_capabilities()
        })
    end
  end

  @doc "Capability ids the `:ultracode_construction_recipes` registry names, sorted."
  @spec registered_capabilities() :: [String.t()]
  def registered_capabilities do
    case Application.get_env(:xaas, :ultracode_construction_recipes, %{}) do
      %{} = map ->
        map |> Map.keys() |> Enum.map(&to_string/1)

      list when is_list(list) ->
        Enum.flat_map(list, fn
          {key, _value} -> [to_string(key)]
          %{} = entry -> [entry[:capability_id] || entry["capability_id"]]
          _other -> []
        end)

      _other ->
        []
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  # -- pipeline -----------------------------------------------------------------

  defp pipeline(ctx) do
    with {:ok, work} <- work_graph(ctx),
         {:ok, frontier} <- frontier(ctx),
         {:ok, first} <- first_eligible(frontier),
         {:ok, row} <- row(work, first),
         {:ok, descriptor} <- descriptor(ctx, row),
         {:ok, first_item} <- classify(row),
         {:ok, items} <- classify_eligible(work, frontier) do
      resolution = %{
        "schema" => @schema,
        "checkpoint" => work["checkpoint"],
        "pipeline" => [
          "scripts/successor_work_graph.exs (semantic-jira-pack bootstrap/work_orders.rq)",
          "mix semantic_jira.frontier",
          "mix semantic_jira.descriptor --provider #{ctx.provider}",
          "Xaas.Sa2a.Route.tuple/2 + Xaas.Sa2a.Route.resolve/1"
        ],
        "inputs" => %{
          "work_graph_sha256" => sha256(encode(work)),
          "frontier_sha256" => sha256(encode(frontier)),
          "descriptor_sha256" => sha256(encode(descriptor))
        },
        "descriptor" => %{
          "order" => row["identity"],
          "provider" => descriptor["provider"],
          "verifier_suite" => descriptor["verifier_suite"],
          "verifier_suite_registered" => Verifier.registered?(descriptor["verifier_suite"]),
          "execution_repo_alias" => descriptor["execution_repo_alias"]
        },
        "first" => first_item,
        "items" => items
      }

      summary = %{
        "standing" => first_item["standing"],
        "checkpoint" => work["checkpoint"],
        "work_orders" => length(work["work_orders"]),
        "eligible" => length(frontier["eligible"]),
        "first" => first_item["order"],
        "capability" => first_item["capability"],
        "reason" => first_item["reason"],
        "items" => Enum.frequencies_by(items, & &1["standing"])
      }

      {:ok,
       [
         {"work.json", work},
         {"frontier.json", frontier},
         {"descriptor.json", descriptor},
         {"resolution.json", resolution}
       ], summary}
    end
  end

  defp work_graph(ctx) do
    out = Path.join(ctx.scratch, "work.json")
    args = ["--no-start", ctx.script, ctx.goal, ctx.orders, out]

    case SemanticDrive.graph_side(ctx, "run", args) do
      {0, %{"ok" => true}, _out} ->
        read_json(out, "work_graph_unreadable", "work_graph")

      {code, json, out} ->
        {:refused,
         typed("REFUSED(work_graph_refused)", "work_graph_refused", "mu_on_O", "work_graph", %{
           "exit" => code,
           "reason" => brief(json, out)
         })}
    end
  end

  defp frontier(ctx) do
    args = ["--work-orders", Path.join(ctx.scratch, "work.json"), "--ledger", ctx.ledger]

    case SemanticDrive.graph_side(ctx, "semantic_jira.frontier", args) do
      {0, %{"status" => "ok"} = frontier, _out} ->
        {:ok, frontier}

      {code, json, out} ->
        {:refused,
         typed("REFUSED(frontier_refused)", "frontier_refused", "mu_on_O", "frontier", %{
           "exit" => code,
           "reason" => brief(json, out)
         })}
    end
  end

  defp first_eligible(%{"eligible" => [first | _]}), do: {:ok, first["identity"]}

  defp first_eligible(frontier) do
    {:refused,
     typed("BLOCKED:empty_frontier", "empty_frontier", "mu_on_O", "frontier", %{
       "blocked" => frontier["blocked"]
     })}
  end

  defp row(work, identity) do
    case Enum.find(work["work_orders"], &(&1["identity"] == identity)) do
      nil ->
        {:refused,
         typed(
           "REFUSED(order_not_in_work_graph)",
           "order_not_in_work_graph",
           "mu_on_O",
           "frontier",
           %{
             "order" => identity
           }
         )}

      row ->
        {:ok, row}
    end
  end

  defp descriptor(ctx, row) do
    out = Path.join(ctx.scratch, "descriptor.json")
    exec_alias = Map.get(ctx.aliases, row["repository"]) || repository_name(row["repository"])

    args = [
      "--work-orders",
      Path.join(ctx.scratch, "work.json"),
      "--ledger",
      ctx.ledger,
      "--identity",
      row["identity"],
      "--alias",
      "#{row["repository"]}=#{exec_alias}",
      "--verifier-suite",
      ctx.verifier_suite,
      "--provider",
      ctx.provider,
      "--out",
      out
    ]

    case SemanticDrive.graph_side(ctx, "semantic_jira.descriptor", args) do
      {0, _json, _out} ->
        with {:ok, descriptor} <- read_json(out, "descriptor_unreadable", "descriptor") do
          if descriptor["provider"] == ctx.provider do
            {:ok, descriptor}
          else
            {:refused,
             typed(
               "REFUSED(descriptor_provider_mismatch)",
               "descriptor_provider_mismatch",
               "mu_on_O",
               "descriptor",
               %{"provider" => descriptor["provider"]}
             )}
          end
        end

      {code, json, out} ->
        {:refused,
         typed("REFUSED(descriptor_refused)", "descriptor_refused", "mu_on_O", "descriptor", %{
           "exit" => code,
           "reason" => brief(json, out)
         })}
    end
  end

  defp classify_eligible(work, frontier) do
    frontier["eligible"]
    |> Enum.map(& &1["identity"])
    |> Enum.reduce_while({:ok, []}, fn identity, {:ok, acc} ->
      with {:ok, row} <- row(work, identity),
           {:ok, item} <- classify(row) do
        {:cont, {:ok, [item | acc]}}
      else
        refused -> {:halt, refused}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      refused -> refused
    end
  end

  # -- context --------------------------------------------------------------------

  defp context(opts) do
    dir = opts |> Keyword.fetch!(:dir) |> Path.expand()
    ggen_dir = opts |> Keyword.fetch!(:ggen_igniter_dir) |> Path.expand()
    mix_env = Keyword.get(opts, :mix_env, "test")
    script = opts |> Keyword.get(:script, "scripts/successor_work_graph.exs") |> Path.expand()
    goal = Path.join(dir, "goal.ttl")
    orders = Path.join([dir, "compiled", "orders.ttl"])

    missing =
      Enum.reject(
        [
          {"goal", goal},
          {"orders", orders},
          {"script", script},
          {"ggen_igniter", Path.join(ggen_dir, "mix.exs")}
        ],
        fn {_role, path} -> File.regular?(path) end
      )

    if missing == [] do
      scratch =
        Path.join(System.tmp_dir!(), "successor-intake-#{System.unique_integer([:positive])}")

      File.mkdir_p!(scratch)
      ledger = Path.join(scratch, "ledger.ndjson")
      File.write!(ledger, "")

      with {:ok, build_path} <- build_path(opts, ggen_dir, mix_env, scratch),
           {:ok, toolchain} <- toolchain(ggen_dir, build_path, scratch) do
        {:ok,
         %{
           dir: dir,
           out_dir: out_dir(opts),
           goal: goal,
           orders: orders,
           script: script,
           ledger: ledger,
           scratch: scratch,
           ggen_dir: ggen_dir,
           mix_env: mix_env,
           ggen_build_path: build_path,
           toolchain: toolchain,
           timeout_s: Keyword.get(opts, :timeout_s, 900),
           provider: Keyword.get(opts, :provider, @provider),
           verifier_suite: Keyword.get(opts, :verifier_suite, @verifier_suite),
           aliases: Keyword.get(opts, :aliases, %{})
         }}
      end
    else
      {:refused,
       typed("REFUSED(input_missing)", "input_missing", "mu_on_O", "context", %{
         "missing" => Enum.map(missing, fn {role, path} -> %{"role" => role, "path" => path} end)
       })}
    end
  end

  defp out_dir(opts) do
    case Keyword.get(opts, :out_dir) do
      nil -> opts |> Keyword.fetch!(:dir) |> Path.expand() |> Path.join("intake")
      dir -> Path.expand(dir)
    end
  end

  # A private MIX_BUILD_PATH: the caller's, else an APFS clone (cp -c; plain
  # copy as fallback) of the judged checkout's _build/<env>.
  defp build_path(opts, ggen_dir, mix_env, scratch) do
    case Keyword.get(opts, :ggen_build_path) do
      nil ->
        source = Path.join([ggen_dir, "_build", mix_env])
        target = Path.join([scratch, "build", mix_env])
        File.mkdir_p!(Path.dirname(target))

        cond do
          not File.dir?(source) ->
            {:ok, target}

          clone(["-cRp", source, target]) or clone(["-Rp", source, target]) ->
            {:ok, target}

          true ->
            File.rm_rf(scratch)

            {:refused,
             typed("BUILD_BROKEN", "build_clone_failed", "mu_unlawful", "context", %{
               "source" => source
             })}
        end

      path ->
        {:ok, Path.expand(path)}
    end
  end

  defp clone(args) do
    File.rm_rf(List.last(args))
    match?({_, 0}, System.cmd("cp", args, stderr_to_stdout: true))
  end

  defp toolchain(ggen_dir, build_path, scratch) do
    case SemanticDrive.graph_toolchain(ggen_dir, build_path) do
      {:ok, toolchain} ->
        {:ok, toolchain}

      {:refused, typed} ->
        File.rm_rf(scratch)
        {:refused, typed}
    end
  end

  # -- helpers --------------------------------------------------------------------

  @doc "Canonical JSON: keys sorted recursively, pretty, trailing newline."
  @spec encode(term()) :: String.t()
  def encode(term), do: Jason.encode!(canonical(term), pretty: true) <> "\n"

  defp canonical(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(other), do: other

  defp read_json(path, reason, hop) do
    with {:ok, bytes} <- File.read(path),
         {:ok, decoded} <- Jason.decode(bytes) do
      {:ok, decoded}
    else
      error ->
        {:refused,
         typed("REFUSED(#{reason})", reason, "R_missing_consequence", hop, %{
           "file" => Path.basename(path),
           "error" => inspect(error)
         })}
    end
  end

  defp repository_name(repository) when is_binary(repository),
    do: repository |> String.split("/") |> List.last()

  defp repository_name(_other), do: "unassigned"

  defp sha256(bytes), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp brief(%{"reason" => reason}, _out), do: reason
  defp brief(%{} = json, _out), do: json
  defp brief(_nil, out), do: String.slice(out, -600, 600)

  defp typed(standing, reason, broken_term, hop, detail) do
    %{
      "standing" => standing,
      "reason" => reason,
      "broken_term" => broken_term,
      "hop" => hop,
      "detail" => detail
    }
  end
end
