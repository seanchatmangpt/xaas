defmodule Xaas.Ultracode.SemanticDrive do
  @moduledoc """
  The first no-LLM KNOWN episode, end to end (GC-26.9.23 gates GC23-4..GC23-8;
  PRD PR-008..PR-012; ARD sections 8, 10, 13, 14, 18).

  `drive/1` takes ONE sJira work order of a work graph through the closed
  loop, with no model, no model credential and no model binary anywhere on
  the path:

      no-LLM guard
      -> mix semantic_jira.frontier                   (sJira: order eligible)
      -> sJira tuple of the work-graph row            hop 1  "sjira"
      -> capability resolution (Xaas.Sa2a.Route)      recipe provider only
      -> SA2A task (GgenIgniter.SemanticA2A)          hop 2  "sa2a"
      -> mix semantic_jira.descriptor --provider recipe
      -> XaaS epoch contract + Route.conserve/3       hop 3  "xaas"
      -> SemanticWork.materialize (binding :graph, pinned to the SA2A
         admitted snapshot digest)
      -> RecipeWorker (lease -> recipe:mix-format -> fenced commit ->
         Lease.close under the fabric court)          hop 4  "provider"
      -> SemanticReceipt export (sealed)              hop 5  "receipt"
      -> independent re-verification: the registered court suite on a
         FRESH worktree at the produced head (court receipt), then the
         revert falsifier (the same court on the recipe commit reverted
         must fail)
      -> Xaas.Receipt.RProjection (.r.json, fleet R schema)
      -> mix semantic_jira.xaas_receipt -> mix semantic_jira.reconcile
      -> mix semantic_jira.frontier                   (order left, dependent entered)

  Every graph-side step is a real `mix semantic_jira.*` (or `mix run` of
  the SA2A projection script) OS process in the ggen_igniter checkout,
  under the toolchain its `.tool-versions` pins (`RecipeWorker.toolchain/1`),
  stdin `/dev/null`, output to a file, a hard perl-alarm deadline.

  ## Tuple digests (ARD section 8)

  At each of the five hops the carried semantic tuple is normalized to the
  `Xaas.Sa2a.Route` contract tuple and digested with `Route.digest/1`; the
  drive refuses with `REFUSED(tuple_digest_mismatch)` (broken term
  `admission_vacuous`) the moment one hop's digest differs from the sJira
  digest. `verify_hops/1` replays that law over a recorded `hops.json`:
  each hop's digest must recompute from its recorded tuple AND equal every
  other hop's digest. That law is internal consistency only: a `hops.json`
  forged consistently at every hop satisfies it. `verify_hops/2` anchors
  hop 0 to the admitted order: `anchor/1` re-derives the sJira-hop tuple
  and request digests from the committed work graph through the graph
  side's own `mix semantic_jira.descriptor` (the admitted snapshot digest is
  the graph_digest), and every recorded hop must equal that anchor.

  ## Typed outcomes

  Nothing fails generically: every refusal is `{:refused, typed}` with
  `"standing"` (`REFUSED(<reason>)`, `BLOCKED:<reason>` or `BUILD_BROKEN`),
  `"reason"`, `"broken_term"` (the Chatman failure taxonomy), `"hop"` and
  `"detail"`. On success `{:ok, summary}` and the artifacts are written to
  `:out_dir`: `hops.json`, `frontier_before.json`, `frontier_after.json`,
  `sa2a_task.json`, `descriptor.json`, `contract.json`, `receipt.json`,
  `receipt.r.json`, `verification.json`, `reconciler_receipt.json`,
  `ocel.json` (court vocabulary), `ocel2.json` (OCEL 2.0 standard JSON) and
  `drive.json`. A refusal writes only `refused.json`.

  Options: `:ggen_igniter_dir` (required), `:work_graph` (required),
  `:ledger` (required), `:order` (required, work-order identity),
  `:out_dir` (required), `:provider` (`"recipe"`), `:repo_alias`
  (`"ggen_igniter"`, must be registered in `:ultracode_repos`),
  `:repo_path` (the subject repository, for the R projection's
  consequence; default the alias's registered path), `:suite`
  (`"ggen-igniter-format"`, must be registered), `:env` (the environment
  the no-LLM guard judges, default `System.get_env()`), `:mix_env`
  (`"test"`), `:ggen_build_path` (a private `MIX_BUILD_PATH` for the graph
  side, default the checkout's own), `:ggen_timeout_s` (900), `:pin_ref`
  (a branch name that keeps the produced head reachable after the epoch
  worktree is removed), `:sa2a_script`, `:scratch`, `:route` (the routing
  provenance of the order's capability, `Xaas.Ultracode.MachineExperience`,
  lane V23-M: `%{"source" => "requires_capability" | "exploration" |
  "machine_experience", "capability" => ..., ...}`; when given, the resolve
  step refuses `REFUSED(route_capability_mismatch)` unless the route names
  the tuple's capability, and records the route on `CapabilityResolved`: a
  `machine_experience` route relates the event to its `MachineExperience`
  object by IRI, an `exploration` route to the candidate's proposer).
  """

  alias Xaas.Receipt.RProjection
  alias Xaas.Sa2a.Route
  alias Xaas.Ultracode.{Epoch, Receipt, RecipeWorker, Run, SemanticReceipt, SemanticWork}
  alias Xaas.Ultracode.{Verifier, Worktrees}
  alias Xaas.Ultracode.SemanticDrive.Ocel

  @hops ~w(sjira sa2a xaas provider receipt)
  @request_fields ~w(work_order subject postcondition capability evidence_horizon authority_ceiling
                     consequence_class exclusions graph_digest)
  @hops_schema "xaas/semantic-drive-hops/v1"
  @drive_schema "xaas/semantic-drive/v1"
  @provider "recipe"
  @executor "recipe-worker"
  @suite "ggen-igniter-format"
  @repo_alias "ggen_igniter"
  @checkpoint "https://ggen-igniter.dev/sjira/v26.9.23#GC-26.9.23"

  @llm_prefixes ~w(ANTHROPIC_ CLAUDE_ OPENAI_ ZAI_ Z_AI_ GLM_ ZCODE_)
  @llm_names ~w(CLAUDECODE)
  @llm_binaries ~w(zcode claude)

  @steps ~w(guard frontier_before order resolve sa2a descriptor contract materialize actuate
            seal verify project reconcile frontier_after)a

  @git_identity [
    {"GIT_AUTHOR_NAME", "xaas-semantic-drive"},
    {"GIT_AUTHOR_EMAIL", "semantic-drive@xaas.invalid"},
    {"GIT_COMMITTER_NAME", "xaas-semantic-drive"},
    {"GIT_COMMITTER_EMAIL", "semantic-drive@xaas.invalid"}
  ]

  @doc "The recorded hops, in route order (ARD section 8)."
  @spec hops() :: [String.t()]
  def hops, do: @hops

  @doc "The drive's steps, in order (one OCEL-observed closed-loop pass)."
  @spec steps() :: [atom()]
  def steps, do: @steps

  @doc """
  Runs one graph-side `mix` task (or `mix run <script>`) the way the drive
  does: in `ctx.ggen_dir`, under `ctx.toolchain` (`graph_toolchain/2`) with
  `MIX_ENV` = `ctx.mix_env` and `MIX_BUILD_PATH` = `ctx.ggen_build_path`,
  stdin `/dev/null`, output to a file under `ctx.scratch`, a hard
  `ctx.timeout_s` deadline, every model-credential variable unset. Returns
  `{exit, last JSON line of the output (or nil), output}`.
  """
  @spec graph_side(map(), String.t(), [String.t()]) :: {integer(), map() | nil, String.t()}
  def graph_side(ctx, task, args), do: ggen(ctx, task, args)

  @doc "The environment-variable prefixes (and exact names) the no-LLM guard refuses."
  @spec llm_variables() :: %{prefixes: [String.t()], names: [String.t()]}
  def llm_variables, do: %{prefixes: @llm_prefixes, names: @llm_names}

  # ---------------------------------------------------------------------------
  # the no-LLM guard (F3)
  # ---------------------------------------------------------------------------

  @doc """
  The no-LLM guard: `:ok`, or `REFUSED(llm_credential_present)` (broken
  term `mu_on_O`) when `env` names any variable with a prefix in
  `llm_variables/0` (or `CLAUDECODE`), or when an executable named `zcode`
  or `claude` sits in any `PATH` directory. Only variable NAMES and binary
  paths are reported, never values.
  """
  @spec no_llm_guard(map()) :: :ok | {:refused, map()}
  def no_llm_guard(env \\ System.get_env()) when is_map(env) do
    variables = env |> Map.keys() |> Enum.filter(&llm_variable?/1) |> Enum.sort()
    binaries = llm_binaries(Map.get(env, "PATH") || "")

    if variables == [] and binaries == [] do
      :ok
    else
      {:refused,
       typed("REFUSED(llm_credential_present)", "llm_credential_present", "mu_on_O", "guard", %{
         "variables" => variables,
         "binaries" => binaries
       })}
    end
  end

  defp llm_variable?(name),
    do: name in @llm_names or Enum.any?(@llm_prefixes, &String.starts_with?(name, &1))

  defp llm_binaries(path) do
    for dir <- String.split(path, ":", trim: true),
        binary <- @llm_binaries,
        file = Path.join(dir, binary),
        executable?(file),
        do: file
  end

  defp executable?(file) do
    case File.stat(file) do
      {:ok, %File.Stat{type: :regular, mode: mode}} -> Bitwise.band(mode, 0o111) != 0
      _ -> false
    end
  end

  # ---------------------------------------------------------------------------
  # hops.json replay (F2)
  # ---------------------------------------------------------------------------

  @doc """
  The ARD section 8 `SemanticExecutionRequest` fields every hop carries:
  work_order, subject, postcondition, capability, evidence_horizon,
  authority_ceiling, consequence_class, exclusions, graph_digest.
  """
  @spec request_fields() :: [String.t()]
  def request_fields, do: @request_fields

  @doc """
  The `SemanticExecutionRequest` digest (ARD section 8): `"sha256:" <>
  lowercase hex` over the canonical JSON of exactly `request_fields/0`
  (sorted keys, compact separators, UTF-8 unescaped, `exclusions` sorted) --
  the same canonicalization as `Xaas.Sa2a.Route.digest/1`, i.e. Python's
  `json.dumps(r, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`.
  """
  @spec request_digest(map()) :: String.t()
  def request_digest(%{} = request) do
    encoded =
      @request_fields
      |> Enum.map(fn
        "exclusions" = field -> {field, request |> Map.fetch!(field) |> Enum.sort()}
        field -> {field, Map.fetch!(request, field)}
      end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Jason.OrderedObject.new()
      |> Jason.encode!()

    "sha256:" <> (:crypto.hash(:sha256, encoded) |> Base.encode16(case: :lower))
  end

  @doc """
  Replays the digest law over a recorded hops document: exactly the hops
  `hops/0`, in order; at every hop the `tuple` carries exactly the
  `Xaas.Sa2a.Route` contract fields and its `digest` recomputes
  (`Route.digest/1`), and the `request` carries exactly `request_fields/0`
  and its `request_digest` recomputes (`request_digest/1`); every hop's
  digests equal the first hop's. `{:ok, %{"tuple_digest", "request_digest"}}`
  or `REFUSED(tuple_digest_mismatch)` / `REFUSED(hops_incomplete)` (both
  `admission_vacuous`) naming the hop, the carrier and the first differing
  field.
  """
  @spec verify_hops(map()) :: {:ok, map()} | {:refused, map()}
  def verify_hops(%{"hops" => hops}) when is_list(hops) do
    with :ok <- hop_names(Enum.map(hops, &(is_map(&1) && &1["hop"]))),
         {:ok, tuple_digest} <- agree(hops, "tuple", "digest", Route.fields(), &Route.digest/1),
         {:ok, request_digest} <-
           agree(hops, "request", "request_digest", @request_fields, &request_digest/1) do
      {:ok, %{"tuple_digest" => tuple_digest, "request_digest" => request_digest}}
    end
  end

  def verify_hops(_other),
    do:
      {:refused,
       typed("REFUSED(hops_incomplete)", "hops_incomplete", "admission_vacuous", "replay", %{})}

  @doc """
  `verify_hops/1` AND the hop-0 anchor (ARD section 8: the digest is checked
  sJira -> SA2A -> XaaS -> provider -> receipt, starting from the admitted
  order, not from whatever the recording says hop 0 carried). `anchor` is
  `anchor/1` / `anchor_from/2` output: every recorded hop's tuple digest must
  equal the anchor's `tuple_digest` and every request digest its
  `request_digest`, else `REFUSED(tuple_digest_mismatch)`
  (`admission_vacuous`, hop `sjira`, detail `"anchor" =>
  "admitted_work_graph"` with the carrier and the first differing field).
  A hops document forged consistently at every hop passes `verify_hops/1`
  and is refused here. `{:ok, %{"tuple_digest", "request_digest",
  "anchor"}}` on success.
  """
  @spec verify_hops(map(), map()) :: {:ok, map()} | {:refused, map()}
  def verify_hops(
        doc,
        %{"tuple_digest" => tuple_digest, "request_digest" => request_digest} = anchor
      )
      when is_binary(tuple_digest) and is_binary(request_digest) do
    with {:ok, digests} <- verify_hops(doc),
         :ok <- anchored(doc, "tuple", digests["tuple_digest"], anchor, Route.fields()),
         :ok <- anchored(doc, "request", digests["request_digest"], anchor, @request_fields) do
      {:ok,
       Map.put(
         digests,
         "anchor",
         Map.take(anchor, ~w(work_order tuple_digest request_digest graph_digest source))
       )}
    end
  end

  def verify_hops(_doc, _anchor),
    do:
      {:refused,
       typed("REFUSED(hops_unanchored)", "hops_unanchored", "admission_vacuous", "sjira", %{
         "reason" => "no anchor derived from the admitted work graph"
       })}

  defp anchored(%{"hops" => [first | _]}, key, recorded, anchor, fields) do
    {digest_key, expected} =
      if key == "tuple",
        do: {"tuple_digest", anchor["tuple_digest"]},
        else: {"request_digest", anchor["request_digest"]}

    if recorded == expected do
      :ok
    else
      mismatch("sjira", %{
        "anchor" => "admitted_work_graph",
        "carrier" => key,
        "digest" => digest_key,
        "expected" => expected,
        "observed" => recorded,
        "field" => Enum.find(fields, &(anchor[key][&1] != first[key][&1]))
      })
    end
  end

  @doc """
  The hop-0 anchor of `row` (one work-graph row) admitted under
  `graph_digest` (the graph side's admitted snapshot digest of that row):
  the `Xaas.Sa2a.Route` tuple of the row and the ARD section 8
  `SemanticExecutionRequest` (`work_order` = the row's identity,
  `evidence_horizon` = the row's, `graph_digest`), each with its digest --
  exactly what the drive records at the sJira hop. Pure; `anchor/1` runs the
  graph side for `graph_digest`. `REFUSED(tuple_incomplete)` /
  `REFUSED(tuple_digest_mismatch)` when the row cannot carry a full tuple.
  """
  @spec anchor_from(map(), String.t()) :: {:ok, map()} | {:refused, map()}
  def anchor_from(%{} = row, graph_digest) do
    with {:ok, tuple} <- hop_tuple(:order, row, "sjira"),
         {:ok, request} <-
           well_formed(
             request(row["identity"], tuple, row["evidence_horizon"], graph_digest),
             @request_fields,
             "sjira",
             "request"
           ) do
      {:ok,
       %{
         "work_order" => row["identity"],
         "tuple" => tuple,
         "tuple_digest" => Route.digest(tuple),
         "request" => request,
         "request_digest" => request_digest(request),
         "graph_digest" => graph_digest
       }}
    end
  end

  @doc """
  Derives the hop-0 anchor of order `:order` from the committed work graph
  `:work_graph` through the graph side (`:ggen_igniter_dir`): one real
  `mix semantic_jira.descriptor` OS process (the drive's own descriptor
  path: `--work-orders <work graph> --ledger <a fresh empty ledger>
  --identity <order> --alias <row repository>=<:repo_alias>
  --verifier-suite <:suite> --provider <:provider>`, plus the graph's court
  map for the order), run exactly like the drive's graph side
  (`graph_side/3`: `graph_toolchain/2`, `MIX_BUILD_PATH` =
  `:ggen_build_path`, stdin `/dev/null`, a hard deadline, every
  model-credential variable unset). The empty ledger is the pre-drive state
  (`Episode.prepare/1` writes a fresh ledger). The descriptor's bridge must
  name the order (identity, subject, base_sha, evidence_ceiling of the row)
  and carry an admitted `source_snapshot_digest`, which becomes the
  anchor's `graph_digest` (`anchor_from/2`).

  Options: `:ggen_igniter_dir`, `:work_graph`, `:order` (required);
  `:ggen_build_path` (default `<dir>/_build/<mix_env>`; pass a private clone
  so the judged checkout's build is never written), `:mix_env` (`"test"`),
  `:ggen_timeout_s` (900), `:repo_alias` (`"ggen_igniter"`), `:suite`
  (`"ggen-igniter-format"`), `:provider` (`"recipe"`), `:scratch`.

  Refusals: `BUILD_BROKEN` (`graph_side_build_broken`, `mu_unlawful`) when
  the graph side does not compile under the resolved toolchain (the anchor
  cannot be witnessed), `REFUSED(descriptor_refused)` (`mu_on_O`),
  `REFUSED(anchor_descriptor_mismatch)` (`admission_vacuous`) when the
  descriptor does not name the row, plus the work-graph refusals of the
  drive (`work_graph_unreadable`, `work_graph_invalid`,
  `order_not_in_work_graph`).
  """
  @spec anchor(keyword()) :: {:ok, map()} | {:refused, map()}
  def anchor(opts) do
    dir = Keyword.fetch!(opts, :ggen_igniter_dir)
    work_graph = Keyword.fetch!(opts, :work_graph)
    order = Keyword.fetch!(opts, :order)
    mix_env = Keyword.get(opts, :mix_env, "test")
    build = Keyword.get(opts, :ggen_build_path) || Path.join([dir, "_build", mix_env])
    own_scratch = is_nil(opts[:scratch])
    scratch = opts[:scratch] || make_scratch()

    try do
      with {:ok, bytes} <- read_bytes(work_graph),
           {:ok, graph} <- read_json(work_graph, "work_graph_unreadable", "sjira"),
           {:ok, rows} <- work_orders(graph),
           {:ok, row} <- find_order(rows, order),
           {:ok, toolchain} <- graph_toolchain(dir, build) do
        ctx = %{
          ggen_dir: dir,
          scratch: scratch,
          mix_env: mix_env,
          toolchain: toolchain,
          ggen_build_path: build,
          timeout_s: Keyword.get(opts, :ggen_timeout_s, 900)
        }

        source = %{
          "work_graph" => work_graph,
          "work_graph_sha256" =>
            "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)),
          "process" => "mix semantic_jira.descriptor (empty ledger)",
          "ggen_igniter_dir" => dir,
          "ggen_igniter_sha" => git_head(dir),
          "toolchain" => Map.take(toolchain, ~w(source elixir erlang mix build_compiler))
        }

        with {:ok, descriptor} <- anchor_descriptor(ctx, work_graph, graph, row, opts),
             {:ok, graph_digest} <- anchor_bridge(descriptor, row, opts),
             {:ok, anchor} <- anchor_from(row, graph_digest) do
          {:ok, Map.put(anchor, "source", source)}
        end
      end
    after
      if own_scratch, do: File.rm_rf(scratch)
    end
  end

  defp read_bytes(path) do
    case File.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, reason} ->
        {:refused,
         typed("REFUSED(work_graph_unreadable)", "work_graph_unreadable", "mu_on_O", "sjira", %{
           "path" => path,
           "error" => inspect(reason)
         })}
    end
  end

  defp anchor_descriptor(ctx, work_graph, graph, row, opts) do
    order = row["identity"]
    ledger = Path.join(ctx.scratch, "anchor-ledger.ndjson")
    out = Path.join(ctx.scratch, "anchor-descriptor.json")
    File.write!(ledger, "")

    court_map_args =
      case get_in(graph, ["court_maps", order]) do
        %{} = map ->
          path = Path.join(ctx.scratch, "anchor-court-map.json")
          File.write!(path, Jason.encode!(map))
          ["--court-map", path]

        _ ->
          []
      end

    args =
      [
        "--work-orders",
        work_graph,
        "--ledger",
        ledger,
        "--identity",
        order,
        "--alias",
        "#{row["repository"]}=#{Keyword.get(opts, :repo_alias, @repo_alias)}",
        "--verifier-suite",
        Keyword.get(opts, :suite, @suite),
        "--provider",
        Keyword.get(opts, :provider, @provider),
        "--out",
        out
      ] ++ court_map_args

    case ggen(ctx, "semantic_jira.descriptor", args) do
      {0, _json, _out} ->
        read_json(out, "descriptor_unreadable", "sjira")

      {code, json, text} ->
        if build_broken?(code, text) do
          {:refused,
           typed("BUILD_BROKEN", "graph_side_build_broken", "mu_unlawful", "sjira", %{
             "exit" => code,
             "toolchain" => Map.take(ctx.toolchain, ~w(source elixir mix build_compiler)),
             "reason" => brief(json, text)
           })}
        else
          {:refused,
           typed("REFUSED(descriptor_refused)", "descriptor_refused", "mu_on_O", "sjira", %{
             "exit" => code,
             "reason" => brief(json, text)
           })}
        end
    end
  end

  defp anchor_bridge(descriptor, row, opts) do
    bridge = descriptor["bridge"] || %{}
    digest = bridge["source_snapshot_digest"]

    expected = %{
      "identity" => row["identity"],
      "subject" => row["subject"],
      "base_sha" => row["base_sha"],
      "evidence_ceiling" => row["evidence_ceiling"]
    }

    differs =
      Enum.find(Map.keys(expected) |> Enum.sort(), &(bridge[&1] != expected[&1])) ||
        if(descriptor["provider"] != Keyword.get(opts, :provider, @provider), do: "provider")

    cond do
      differs ->
        {:refused,
         typed(
           "REFUSED(anchor_descriptor_mismatch)",
           "anchor_descriptor_mismatch",
           "admission_vacuous",
           "sjira",
           %{"field" => differs, "order" => row["identity"]}
         )}

      not (is_binary(digest) and Regex.match?(~r/\Asha256:[0-9a-f]{64}\z/, digest)) ->
        {:refused,
         typed(
           "REFUSED(anchor_descriptor_mismatch)",
           "anchor_descriptor_mismatch",
           "admission_vacuous",
           "sjira",
           %{"field" => "source_snapshot_digest", "order" => row["identity"]}
         )}

      true ->
        {:ok, digest}
    end
  end

  defp hop_names(names) do
    if names == @hops,
      do: :ok,
      else:
        {:refused,
         typed("REFUSED(hops_incomplete)", "hops_incomplete", "admission_vacuous", "replay", %{
           "expected" => @hops,
           "observed" => names
         })}
  end

  defp agree(hops, key, digest_key, fields, digest_fun) do
    with {:ok, rows} <- recompute(hops, key, digest_key, fields, digest_fun) do
      [{_hop, first, first_value} | _] = rows

      case Enum.find(rows, fn {_hop, digest, _value} -> digest != first end) do
        nil ->
          {:ok, first}

        {hop, digest, value} ->
          mismatch(hop, %{
            "carrier" => key,
            "expected" => first,
            "observed" => digest,
            "field" => Enum.find(fields, &(first_value[&1] != value[&1]))
          })
      end
    end
  end

  defp recompute(hops, key, digest_key, fields, digest_fun) do
    Enum.reduce_while(hops, {:ok, []}, fn hop, {:ok, acc} ->
      with {:ok, value} <- well_formed(hop[key], fields, hop["hop"], key),
           recomputed = digest_fun.(value),
           :ok <- recorded(hop, digest_key, recomputed) do
        {:cont, {:ok, acc ++ [{hop["hop"], recomputed, value}]}}
      else
        {:refused, typed} -> {:halt, {:refused, typed}}
      end
    end)
  end

  defp well_formed(%{} = value, fields, hop, key) do
    keys = value |> Map.keys() |> Enum.sort()
    blank = Enum.find(fields -- ["exclusions"], &(not nonempty?(value[&1])))

    cond do
      keys != Enum.sort(fields) ->
        mismatch(hop, %{
          "carrier" => key,
          "field" => List.first((fields -- keys) ++ (keys -- fields)),
          "keys" => keys
        })

      not (is_list(value["exclusions"]) and Enum.all?(value["exclusions"], &is_binary/1)) ->
        mismatch(hop, %{"carrier" => key, "field" => "exclusions"})

      blank ->
        mismatch(hop, %{"carrier" => key, "field" => blank})

      true ->
        {:ok, value}
    end
  end

  defp well_formed(_other, _fields, hop, key),
    do: mismatch(hop, %{"carrier" => key, "field" => key})

  defp recorded(hop, digest_key, recomputed) do
    if hop[digest_key] == recomputed,
      do: :ok,
      else:
        mismatch(hop["hop"], %{
          "digest" => digest_key,
          "recorded" => hop[digest_key],
          "recomputed" => recomputed
        })
  end

  defp mismatch(hop, detail) do
    {:refused,
     typed(
       "REFUSED(tuple_digest_mismatch)",
       "tuple_digest_mismatch",
       "admission_vacuous",
       hop,
       detail
     )}
  end

  defp nonempty?(value), do: is_binary(value) and String.trim(value) != ""

  # ---------------------------------------------------------------------------
  # conservation of the three representations (sJira row, SA2A task, XaaS
  # epoch contract)
  # ---------------------------------------------------------------------------

  @doc """
  `Route.conserve/3` as a typed drive refusal: `{:ok, digest}` when the
  sJira work-order row, the SA2A task and the XaaS epoch contract normalize
  to one tuple, else `REFUSED(tuple_digest_mismatch)` (`admission_vacuous`)
  naming the first differing field and every hop digest that could be
  computed, or the hop-typed refusal `Route` returned.
  """
  @spec conserve(map(), map(), map()) :: {:ok, String.t()} | {:refused, map()}
  def conserve(order, task, contract) do
    case Route.conserve(order, task, contract) do
      :ok ->
        {:ok, tuple} = Route.tuple(:epoch, contract)
        {:ok, Route.digest(tuple)}

      {:refused, %{broken_term: "admission_vacuous", field: field}} ->
        digests =
          for {hop, rep, kind} <- [
                {"sjira", order, :order},
                {"sa2a", task, :task},
                {"xaas", contract, :epoch}
              ],
              into: %{} do
            case Route.tuple(kind, rep) do
              {:ok, tuple} -> {hop, Route.digest(tuple)}
              {:refused, reason} -> {hop, inspect(reason)}
            end
          end

        {:refused,
         typed(
           "REFUSED(tuple_digest_mismatch)",
           "tuple_digest_mismatch",
           "admission_vacuous",
           "xaas",
           %{
             "field" => field,
             "digests" => digests
           }
         )}

      {:refused, %{broken_term: term} = refusal} ->
        {:refused,
         typed("REFUSED(#{term})", term, "mu_on_O", to_string(Map.get(refusal, :hop, "xaas")), %{
           "route" => inspect(refusal)
         })}
    end
  end

  # ---------------------------------------------------------------------------
  # drive
  # ---------------------------------------------------------------------------

  @doc "Drives one work order through the closed loop (see the moduledoc)."
  @spec drive(keyword()) :: {:ok, map()} | {:refused, map()}
  def drive(opts) do
    with {:ok, ctx} <- context(opts) do
      result =
        Enum.reduce_while(@steps, {:ok, ctx}, fn step, {:ok, ctx} ->
          case run_step(step, ctx) do
            {:ok, ctx} -> {:cont, {:ok, ctx}}
            {:refused, typed, ctx} -> {:halt, {:refused, typed, ctx}}
          end
        end)

      conclude(result)
    end
  end

  defp run_step(step, ctx) do
    case step(step, ctx) do
      {:ok, %{} = ctx} -> {:ok, ctx}
      {:refused, typed} -> {:refused, typed, ctx}
      {:refused, typed, ctx} -> {:refused, typed, ctx}
    end
  rescue
    error ->
      {:refused,
       typed(
         "REFUSED(drive_step_crashed)",
         "drive_step_crashed",
         "mu_unlawful",
         to_string(step),
         %{
           "error" => Exception.message(error)
         }
       ), ctx}
  end

  defp context(opts) do
    ggen_dir = Keyword.fetch!(opts, :ggen_igniter_dir)
    scratch = Keyword.get(opts, :scratch) || make_scratch()
    repo_alias = Keyword.get(opts, :repo_alias, @repo_alias)
    suite = Keyword.get(opts, :suite, @suite)

    base = %{
      ggen_dir: ggen_dir,
      work_graph: Keyword.fetch!(opts, :work_graph),
      ledger: Keyword.fetch!(opts, :ledger),
      order_id: Keyword.fetch!(opts, :order),
      out_dir: Keyword.fetch!(opts, :out_dir),
      provider: Keyword.get(opts, :provider, @provider),
      repo_alias: repo_alias,
      suite: suite,
      env: Keyword.get(opts, :env) || System.get_env(),
      mix_env: Keyword.get(opts, :mix_env, "test"),
      ggen_build_path: Keyword.get(opts, :ggen_build_path),
      timeout_s: Keyword.get(opts, :ggen_timeout_s, 900),
      pin_ref: Keyword.get(opts, :pin_ref),
      route: Keyword.get(opts, :route),
      sa2a_script:
        Keyword.get(opts, :sa2a_script) ||
          Path.join(File.cwd!(), "scripts/sa2a_route_task.exs"),
      scratch: scratch,
      started_at: now(),
      hops: [],
      events: [],
      objects: %{},
      artifacts: %{},
      cleanup: []
    }

    with :ok <-
           context_check(File.regular?(Path.join(ggen_dir, "mix.exs")), "ggen_igniter_missing", %{
             "dir" => ggen_dir
           }),
         :ok <-
           context_check(File.regular?(base.sa2a_script), "sa2a_script_missing", %{
             "script" => base.sa2a_script
           }),
         {:ok, entry} <- registered_repo(repo_alias),
         :ok <-
           context_check(Verifier.registered?(suite), "verifier_suite_unregistered", %{
             "suite" => suite
           }),
         {:ok, toolchain} <-
           graph_toolchain(
             ggen_dir,
             base.ggen_build_path || Path.join([ggen_dir, "_build", base.mix_env])
           ) do
      {:ok,
       Map.merge(base, %{
         repo_path: Keyword.get(opts, :repo_path) || entry.path,
         toolchain: toolchain,
         ggen_sha: git_head(ggen_dir)
       })}
    end
  end

  defp context_check(true, _reason, _detail), do: :ok

  defp context_check(false, reason, detail),
    do: {:refused, typed("REFUSED(#{reason})", reason, "mu_on_O", "context", detail)}

  defp registered_repo(repo_alias) do
    case Worktrees.registry_entry(repo_alias) do
      {:ok, entry} ->
        {:ok, entry}

      {:error, reason} ->
        {:refused,
         typed(
           "REFUSED(repo_alias_unregistered)",
           "repo_alias_unregistered",
           "mu_on_O",
           "context",
           %{
             "alias" => repo_alias,
             "reason" => inspect(reason)
           }
         )}
    end
  end

  @doc """
  The toolchain that runs the graph side: the ggen_igniter checkout `dir`
  whose compiled build is `build_path` (`MIX_BUILD_PATH` semantics: the build
  directory itself, e.g. `<dir>/_build/test` or a private APFS clone of it).

  Resolution order:

    1. **the compiler of the build under judgement.** Mix records it in
       `<build_path>/lib/<app>/.mix/compile.elixir_scm` as
       `{elixir_version, otp_release}`. When the running node's ERTS has that
       OTP release and an Elixir of exactly that version is installed -- the
       running node's own, else `<asdf>/installs/elixir/<vsn>-otp-<otp>`, else
       `<asdf>/installs/elixir/<vsn>` -- that Elixir runs the graph side: Mix
       finds the build current, recompiles nothing and writes nothing
       (`"source" => "build_manifest"`). A checkout compiled by a different
       Elixir than its `.tool-versions` pin (observed: ggen_igniter-int
       `_build/test` by 1.19.5/OTP 28 while the pin is 1.18.4-otp-27) is
       judged as built, instead of being rebuilt from scratch under the pin
       (which recompiles every dependency and the rustler NIF, and needs a
       Rust toolchain the no-LLM court PATH does not carry).
    2. otherwise the checkout's `.tool-versions` pin, resolved like the
       recipe provider's (`RecipeWorker.toolchain/1`); Mix then compiles
       into `build_path`.

  The ERTS is the one the build was compiled on: the running node's when
  its OTP release is the manifest's, else an `<asdf>/installs/erlang/<v>`
  install of that OTP release (the checkout's `.tool-versions` erlang pin
  first, then the rest in order); only when none exists is it the running
  node's. Pairing an Elixir with a different ERTS than the build's forces a
  full dependency rebuild whose rebar-compiled beams an older ERTS cannot
  read (observed: ggen_igniter-int `_build/test` rebuilt under its
  1.18.4-otp-27 pin, judged from an OTP 28 xaas node, rebuilt every
  dependency and failed on yaml_elixir). The identity records which source
  won, the manifest read, the compiler it names and the ERTS used.
  `<asdf>` = `config :xaas, :ultracode_asdf_data_dir`, else
  `$ASDF_DATA_DIR`, else `~/.asdf`.
  """
  @spec graph_toolchain(String.t(), String.t()) :: {:ok, map()} | {:refused, map()}
  def graph_toolchain(dir, build_path) when is_binary(dir) and is_binary(build_path) do
    manifest = build_manifest(dir, build_path)
    {erts_bin, otp, erts_source} = build_erts(dir, manifest)

    erts = %{
      "erl" => Path.join(erts_bin, "erl"),
      "erlang" => otp,
      "erts" => erts_source
    }

    case built_toolchain(manifest, otp) do
      {:ok, elixir, mix} ->
        {:ok,
         Map.merge(erts, %{
           "source" => "build_manifest",
           "elixir" => elixir,
           "mix" => mix,
           "path" => graph_path(mix, erts_bin),
           "build_manifest" => manifest.path,
           "build_compiler" => manifest.compiler
         })}

      {:unavailable, why} ->
        pinned_toolchain(dir, erts, erts_bin, manifest, why)
    end
  end

  defp pinned_toolchain(dir, erts, erts_bin, manifest, why) do
    case RecipeWorker.toolchain(dir) do
      {:ok, %{"mix" => mix} = identity} ->
        {:ok,
         identity
         |> Map.merge(erts)
         |> Map.merge(%{
           "path" => graph_path(mix, erts_bin),
           "build_manifest" => manifest.path,
           "build_compiler" => manifest.compiler,
           "build_manifest_unused" => why
         })}

      {:error, {:toolchain_unresolved, reason}} ->
        {:refused,
         typed("BUILD_BROKEN", "toolchain_unresolved", "mu_unlawful", "context", %{
           "why" => reason
         })}
    end
  end

  defp graph_path(mix, erts_bin),
    do: [Path.dirname(mix), erts_bin, "/usr/bin", "/bin"] |> Enum.uniq() |> Enum.join(":")

  # The ERTS the build under judgement was compiled on (see graph_toolchain/2):
  # {bin dir, OTP release, identity}. Falls back to the running node's.
  defp build_erts(dir, manifest) do
    node_bin = Path.join(to_string(:code.root_dir()), "bin")
    node_otp = to_string(:erlang.system_info(:otp_release))
    node = {node_bin, node_otp, "running node (#{node_bin})"}

    case manifest.compiler do
      %{"otp" => otp} when otp != node_otp ->
        root = Path.join([asdf_data_dir(), "installs", "erlang"])

        pinned =
          case File.read(Path.join(dir, ".tool-versions")) do
            {:ok, body} ->
              for line <- String.split(body, "\n"),
                  [tool, vsn | _] <- [String.split(line)],
                  tool == "erlang",
                  do: Path.join(root, vsn)

            _ ->
              []
          end

        (pinned ++ Enum.sort(Path.wildcard(Path.join(root, "*"))))
        |> Enum.find(fn install ->
          File.dir?(Path.join([install, "releases", otp])) and
            executable?(Path.join([install, "bin", "erl"]))
        end)
        |> case do
          nil -> node
          install -> {Path.join(install, "bin"), otp, "build_manifest OTP #{otp} (#{install})"}
        end

      _ ->
        node
    end
  end

  defp build_manifest(dir, build_path) do
    app =
      case File.read(Path.join(dir, "mix.exs")) do
        {:ok, body} ->
          case Regex.run(~r/\bapp:\s*:([a-z][a-z0-9_]*)/, body) do
            [_, app] -> app
            _ -> nil
          end

        _ ->
          nil
      end

    path = app && Path.join([build_path, "lib", app, ".mix", "compile.elixir_scm"])

    compiler =
      with path when is_binary(path) <- path,
           {:ok, bytes} <- File.read(path),
           {_vsn, {elixir, otp}, _scm} when is_binary(elixir) and is_list(otp) <-
             safe_term(bytes) do
        %{"elixir" => elixir, "otp" => to_string(otp)}
      else
        _ -> nil
      end

    %{path: path, compiler: compiler}
  end

  defp safe_term(bytes) do
    :erlang.binary_to_term(bytes, [:safe])
  rescue
    ArgumentError -> nil
  end

  defp built_toolchain(%{compiler: nil, path: path}, _otp),
    do: {:unavailable, "no readable build manifest at #{inspect(path)}"}

  defp built_toolchain(%{compiler: %{"otp" => built}}, otp) when built != otp,
    do:
      {:unavailable,
       "the build was compiled on OTP #{built}; no ERTS of that release is installed, the running ERTS is OTP #{otp}"}

  defp built_toolchain(%{compiler: %{"elixir" => elixir}}, otp) do
    own = Path.expand("../../bin/mix", to_string(:code.lib_dir(:elixir)))
    asdf = Path.join([asdf_data_dir(), "installs", "elixir"])

    # The manifest names the Elixir version and the ERTS it ran on, not the
    # OTP an install was built for: any `<vsn>-otp-<n>` install on this
    # ERTS reproduces it (the exact-OTP one first, then the rest in order).
    candidates =
      if(System.version() == elixir and otp == to_string(:erlang.system_info(:otp_release)),
        do: [own],
        else: []
      ) ++
        [
          Path.join([asdf, "#{elixir}-otp-#{otp}", "bin", "mix"]),
          Path.join([asdf, elixir, "bin", "mix"])
        ] ++ Enum.sort(Path.wildcard(Path.join([asdf, "#{elixir}-otp-*", "bin", "mix"])))

    case Enum.find(candidates, &executable?/1) do
      nil -> {:unavailable, "no Elixir #{elixir} install among #{inspect(candidates)}"}
      mix -> {:ok, elixir, mix}
    end
  end

  defp asdf_data_dir do
    Application.get_env(:xaas, :ultracode_asdf_data_dir) || System.get_env("ASDF_DATA_DIR") ||
      Path.expand("~/.asdf")
  end

  # -- steps --------------------------------------------------------------------

  defp step(:guard, ctx) do
    with :ok <- no_llm_guard(ctx.env), do: {:ok, Map.put(ctx, :guard, "passed")}
  end

  defp step(:frontier_before, ctx) do
    with {:ok, frontier} <- frontier(ctx) do
      ctx =
        ctx |> Map.put(:frontier_before, frontier) |> artifact("frontier_before.json", frontier)

      cond do
        Enum.any?(frontier["eligible"], &(&1["identity"] == ctx.order_id)) ->
          {:ok, ctx}

        blocked = Enum.find(frontier["blocked"], &(&1["identity"] == ctx.order_id)) ->
          {:refused,
           typed("BLOCKED:not_on_frontier", "not_on_frontier", "mu_on_O", "sjira", %{
             "order" => ctx.order_id,
             "blocked" => blocked
           }), ctx}

        true ->
          {:refused,
           typed(
             "REFUSED(order_not_in_work_graph)",
             "order_not_in_work_graph",
             "mu_on_O",
             "sjira",
             %{
               "order" => ctx.order_id
             }
           ), ctx}
      end
    end
  end

  defp step(:order, ctx) do
    with {:ok, graph} <- read_json(ctx.work_graph, "work_graph_unreadable", "sjira"),
         {:ok, rows} <- work_orders(graph),
         {:ok, row} <- find_order(rows, ctx.order_id),
         {:ok, tuple} <- hop_tuple(:order, row, "sjira") do
      dependents =
        rows
        |> Enum.filter(fn r ->
          Enum.any?(r["dependencies"] || [], &(&1["upstream"] == ctx.order_id))
        end)
        |> Enum.map(& &1["identity"])

      # graph_digest of the sJira hop: the admitted snapshot digest the
      # frontier process computed for this row (`work_order_digest`).
      admitted = Enum.find(ctx.frontier_before["eligible"], &(&1["identity"] == ctx.order_id))

      ctx
      |> Map.merge(%{
        order: row,
        rows: rows,
        dependents: dependents,
        court_map: get_in(graph, ["court_maps", ctx.order_id])
      })
      |> order_objects(row, rows)
      |> event("WorkOrderCreated", %{"source" => "work_graph", "standing" => row["standing"]}, [
        {wo(ctx.order_id), "work-order"},
        {"checkpoint:GC-26.9.23", "checkpoint"},
        {"subject:" <> row["subject"], "subject"},
        {"repository:" <> row["repository"], "repository"},
        {"commit:" <> row["base_sha"], "base"}
      ])
      |> record_hop(
        "sjira",
        "sJira work-graph row #{ctx.order_id} (#{Path.basename(ctx.work_graph)}); graph_digest = frontier work_order_digest",
        tuple,
        request(row["identity"], tuple, row["evidence_horizon"], admitted["work_order_digest"])
      )
    end
  end

  defp step(:resolve, ctx) do
    tuple = hop_of(ctx, "sjira")["tuple"]

    with {:ok, {provider, recipe_id}} <- resolve(tuple),
         :ok <- deterministic_provider(provider, ctx.provider),
         {:ok, recipe} <- registered_recipe(tuple["capability"]),
         :ok <- route_capability(ctx.route, tuple["capability"]) do
      capability = tuple["capability"]
      {route_attributes, route_relationships, ctx} = route_provenance(ctx, ctx.route)

      ctx =
        ctx
        |> Map.merge(%{capability: capability, recipe_id: recipe_id})
        |> object("capability:" <> capability, "Capability", %{
          "capability_id" => capability,
          "recipe_id" => recipe_id,
          "argv_sha256" => RecipeWorker.argv_digest(recipe)
        })
        |> object("provider:" <> @executor, "Provider", %{
          "provider" => provider,
          "executor" => @executor,
          "deterministic" => true
        })
        |> event(
          "CapabilityResolved",
          Map.merge(%{"capability" => capability, "provider" => provider}, route_attributes),
          [
            {wo(ctx.order_id), "work-order"},
            {"capability:" <> capability, "capability"},
            {"provider:" <> @executor, "provider"}
          ] ++ route_relationships
        )

      {:ok, ctx}
    end
  end

  defp step(:sa2a, ctx) do
    order_file = Path.join(ctx.scratch, "order.json")
    task_file = Path.join(ctx.scratch, "sa2a_task.json")
    File.write!(order_file, Jason.encode!(ctx.order))

    case ggen(ctx, "run", ["--no-start", ctx.sa2a_script, order_file, task_file]) do
      {0, %{"ok" => true, "work_order_digest" => snapshot}, _out} ->
        with {:ok, task} <- read_json(task_file, "sa2a_task_unreadable", "sa2a"),
             :ok <- same_snapshot(task, snapshot),
             {:ok, tuple} <- hop_tuple(:task, task, "sa2a") do
          carrier = task_carrier(task)

          ctx
          |> Map.merge(%{task: task, snapshot_digest: snapshot})
          |> artifact("sa2a_task.json", task)
          |> record_hop(
            "sa2a",
            "GgenIgniter.SemanticA2A.task_from_work_order/2 (sa2a_task.json)",
            tuple,
            request(
              get_in(carrier, ["tuple", "workOrder"]),
              tuple,
              get_in(carrier, ["tuple", "evidenceHorizon"]),
              carrier["workOrderDigest"]
            )
          )
        end

      {code, json, out} ->
        {:refused,
         typed(
           "REFUSED(sa2a_projection_refused)",
           "sa2a_projection_refused",
           "mu_on_O",
           "sa2a",
           %{
             "exit" => code,
             "reason" => brief(json, out)
           }
         )}
    end
  end

  defp step(:descriptor, ctx) do
    out = Path.join(ctx.scratch, "descriptor.json")

    court_map_args =
      case ctx.court_map do
        %{} = map ->
          path = Path.join(ctx.scratch, "court_map.json")
          File.write!(path, Jason.encode!(map))
          ["--court-map", path]

        _ ->
          []
      end

    args =
      [
        "--work-orders",
        ctx.work_graph,
        "--ledger",
        ctx.ledger,
        "--identity",
        ctx.order_id,
        "--alias",
        "#{ctx.order["repository"]}=#{ctx.repo_alias}",
        "--verifier-suite",
        ctx.suite,
        "--provider",
        ctx.provider,
        "--out",
        out
      ] ++ court_map_args

    case ggen(ctx, "semantic_jira.descriptor", args) do
      {0, _json, _out} ->
        with {:ok, descriptor} <- read_json(out, "descriptor_unreadable", "sjira") do
          if descriptor["provider"] == ctx.provider do
            {:ok,
             ctx |> Map.put(:descriptor, descriptor) |> artifact("descriptor.json", descriptor)}
          else
            {:refused,
             typed(
               "REFUSED(descriptor_provider_mismatch)",
               "descriptor_provider_mismatch",
               "mu_on_O",
               "sjira",
               %{
                 "provider" => descriptor["provider"]
               }
             )}
          end
        end

      {code, json, text} ->
        {:refused,
         typed("REFUSED(descriptor_refused)", "descriptor_refused", "mu_on_O", "sjira", %{
           "exit" => code,
           "reason" => brief(json, text)
         })}
    end
  end

  defp step(:contract, ctx) do
    {:ok, task_tuple} = Route.tuple(:task, ctx.task)
    horizon = get_in(task_carrier(ctx.task), ["tuple", "evidenceHorizon"])

    # The sJira descriptor carries the admitted execution facts and its own
    # `subject` / `evidence_ceiling`; the rest of the tuple rides the SA2A
    # task (the descriptor emitter has no tuple projection). The descriptor's
    # own fields win, so a disagreement between the two graph-side processes
    # is a conservation refusal below, never silently merged.
    carried = %{
      "subject" => task_tuple["subject"],
      "postcondition" => task_tuple["postcondition"],
      "requires_capability" => task_tuple["capability"],
      "evidence_ceiling" => task_tuple["evidence_ceiling"],
      "authority_ceiling" => task_tuple["authority_ceiling"],
      "consequence_class" => task_tuple["consequence_class"],
      "exclusions" => task_tuple["exclusions"],
      "evidence_horizon" => horizon
    }

    contract =
      ctx.descriptor
      |> Map.put("capability", task_tuple["capability"])
      |> Map.put("bridge", Map.merge(carried, ctx.descriptor["bridge"] || %{}))

    with {:ok, _digest} <- conserve(ctx.order, ctx.task, contract),
         {:ok, tuple} <- hop_tuple(:epoch, contract, "xaas") do
      bridge = contract["bridge"]

      ctx
      |> Map.put(:contract, contract)
      |> artifact("contract.json", contract)
      |> record_hop(
        "xaas",
        "XaaS epoch contract admitted by SemanticWork.admit/2 (contract.json)",
        tuple,
        request(
          bridge["identity"],
          tuple,
          bridge["evidence_horizon"],
          bridge["source_snapshot_digest"]
        )
      )
    end
  end

  defp step(:materialize, ctx) do
    case SemanticWork.materialize(ctx.contract,
           binding: :graph,
           expected_snapshot_digest: ctx.snapshot_digest
         ) do
      {:ok, %{run: run, epoch: epoch, worktree: worktree}} ->
        {:ok,
         Map.merge(ctx, %{
           run: run,
           epoch: epoch,
           worktree: worktree,
           cleanup: ctx.cleanup ++ [worktree]
         })}

      {:error, reason} ->
        {:refused,
         typed("REFUSED(materialize_refused)", "materialize_refused", "mu_on_O", "xaas", %{
           "reason" => inspect(reason)
         })}
    end
  end

  defp step(:actuate, ctx) do
    started = now()
    lease = "lease:epoch:" <> ctx.epoch.id

    ctx =
      event(
        ctx,
        "ActuationStarted",
        %{"epoch_id" => ctx.epoch.id, "provider" => ctx.provider},
        [
          {wo(ctx.order_id), "work-order"},
          {"provider:" <> @executor, "provider"},
          {"capability:" <> ctx.capability, "capability"},
          {"commit:" <> ctx.order["base_sha"], "base"}
        ],
        started
      )

    worker = RecipeWorker.run(ctx.epoch, %{provider: ctx.provider})
    epoch = Ash.get!(Epoch, ctx.epoch.id, action: :read_unscoped, authorize?: false)
    run = Ash.get!(Run, ctx.run.id, action: :read_unscoped, authorize?: false)
    closing = closing_receipt(epoch.id)

    ctx =
      if epoch.claimed_at do
        ctx
        |> object(lease, "Lease", %{
          "epoch_id" => epoch.id,
          "leased_to" => epoch.leased_to,
          "provider" => run.provider
        })
        |> event(
          "LeaseAcquired",
          %{"leased_to" => epoch.leased_to, "epoch_id" => epoch.id},
          [
            {lease, "lease"},
            {wo(ctx.order_id), "work-order"},
            {"provider:" <> @executor, "provider"}
          ],
          epoch.claimed_at
        )
      else
        ctx
      end

    ctx = Map.merge(ctx, %{epoch: epoch, run: run, closing: closing, lease: lease})
    actuation_outcome(worker, epoch, closing, ctx)
  end

  defp step(:seal, ctx) do
    case SemanticReceipt.export(ctx.epoch.id) do
      {:ok, export} ->
        head = export["final_head"]
        receipt_obj = "receipt:" <> export["receipt_id"]

        bridge = export["bridge"] || %{}

        with {:ok, tuple} <- hop_tuple(:order, bridge, "receipt"),
             {:ok, ctx} <-
               ctx
               |> Map.merge(%{export: export, head: head})
               |> artifact("receipt.json", export)
               |> record_hop(
                 "receipt",
                 "sealed XaaS receipt bridge (SemanticReceipt.export/1, receipt.json)",
                 tuple,
                 request(
                   bridge["identity"],
                   tuple,
                   bridge["evidence_horizon"],
                   bridge["source_snapshot_digest"]
                 )
               ),
             :ok <- pin(ctx, head) do
          ctx =
            ctx
            |> object(receipt_obj, "Receipt", %{
              "receipt_id" => export["receipt_id"],
              "receipt_digest" => export["receipt_digest"],
              "outcome" => export["outcome"],
              "head_verified" => export["head_verified"]
            })
            |> event(
              "ReceiptSealed",
              %{"receipt_digest" => export["receipt_digest"], "outcome" => export["outcome"]},
              [
                {receipt_obj, "receipt"},
                {wo(ctx.order_id), "work-order"},
                {"commit:" <> head, "head"},
                {ctx.lease, "lease"}
              ]
            )

          {:ok, ctx}
        end

      {:error, reason} ->
        {:refused,
         typed(
           "REFUSED(receipt_unsealed)",
           "receipt_unsealed",
           "R_missing_identity",
           "receipt",
           %{
             "reason" => inspect(reason)
           }
         )}
    end
  end

  defp step(:verify, ctx) do
    name = "drive-verify-" <> hex20(ctx.epoch.id <> ctx.head)

    case Worktrees.provision(ctx.repo_alias, ctx.head, name) do
      {:ok, path} ->
        try do
          verify_in(ctx, path)
        after
          Worktrees.cleanup(ctx.repo_alias, path)
        end

      {:error, reason} ->
        {:refused,
         typed(
           "REFUSED(verification_worktree_refused)",
           "verification_worktree_refused",
           "R_missing_consequence",
           "verify",
           %{
             "reason" => inspect(reason)
           }
         )}
    end
  end

  defp step(:project, ctx) do
    native = Path.join(ctx.scratch, "receipt.json")
    File.write!(native, Jason.encode!(ctx.export, pretty: true) <> "\n")

    case RProjection.write(native,
           repo: ctx.repo_path,
           actor: ctx.epoch.leased_to,
           durable_location: durable(ctx, "receipt.json")
         ) do
      {:ok, _path, %{"standing" => %{"value" => "ALIVE"}} = r} ->
        {:ok, artifact(ctx, "receipt.r.json", r)}

      {:ok, _path, r} ->
        standing = r["standing"]

        {:refused,
         typed(
           standing["value"],
           "r_projection_not_alive",
           standing["broken_term"] || "R_missing_standing",
           "receipt",
           %{
             "standing" => standing
           }
         )}

      {:error, reason} ->
        {:refused,
         typed(
           "REFUSED(r_projection_refused)",
           "r_projection_refused",
           "R_missing_standing",
           "receipt",
           %{
             "reason" => inspect(reason)
           }
         )}
    end
  end

  defp step(:reconcile, ctx) do
    contract_file = Path.join(ctx.scratch, "contract.json")
    receipt_file = Path.join(ctx.scratch, "receipt.json")
    reconciler_file = Path.join(ctx.scratch, "reconciler_receipt.json")
    File.write!(contract_file, Jason.encode!(ctx.contract))

    with {:mapped, {0, _json, _out}} <-
           {:mapped,
            ggen(ctx, "semantic_jira.xaas_receipt", [
              "--bridge",
              contract_file,
              "--xaas-receipt",
              receipt_file,
              "--out",
              reconciler_file
            ])},
         {:ok, reconciler} <- read_json(reconciler_file, "semantic_receipt_unreadable", "receipt"),
         {:reconciled, {0, %{"status" => status, "event" => event}, _out}}
         when status in ["applied", "already_applied"] <-
           {:reconciled,
            ggen(ctx, "semantic_jira.reconcile", [
              "--work-orders",
              ctx.work_graph,
              "--ledger",
              ctx.ledger,
              "--receipt",
              reconciler_file
            ])} do
      ctx =
        ctx
        |> Map.merge(%{reconciler: reconciler, transition: event, reconcile_status: status})
        |> artifact("reconciler_receipt.json", reconciler)
        |> event(
          "StandingChanged",
          %{
            "from" => event["from"],
            "to" => event["to"],
            "event_digest" => event["event_digest"],
            "status" => status
          },
          [
            {wo(ctx.order_id), "work-order"},
            {"receipt:" <> ctx.export["receipt_id"], "receipt"},
            {"checkpoint:GC-26.9.23", "checkpoint"}
          ]
        )

      {:ok, ctx}
    else
      {:mapped, {code, json, out}} ->
        {:refused,
         typed(
           "REFUSED(semantic_receipt_refused)",
           "semantic_receipt_refused",
           "R_not_fed_back",
           "reconcile",
           %{
             "exit" => code,
             "reason" => brief(json, out)
           }
         )}

      {:reconciled, {code, json, out}} ->
        {:refused,
         typed(
           "REFUSED(reconcile_refused)",
           "reconcile_refused",
           "R_not_fed_back",
           "reconcile",
           %{
             "exit" => code,
             "reason" => brief(json, out)
           }
         )}

      {:refused, typed} ->
        {:refused, typed}
    end
  end

  defp step(:frontier_after, ctx) do
    with {:ok, after_frontier} <- frontier(ctx) do
      before_eligible = ids(ctx.frontier_before["eligible"])
      after_eligible = ids(after_frontier["eligible"])
      entered = after_eligible -- before_eligible
      left = before_eligible -- after_eligible
      standing = get_in(after_frontier, ["standings", ctx.order_id])

      ctx =
        ctx
        |> Map.merge(%{frontier_after: after_frontier, entered: entered, left: left})
        |> artifact("frontier_after.json", after_frontier)

      cond do
        ctx.order_id in after_eligible or standing != "ALIVE" ->
          {:refused,
           typed(
             "REFUSED(frontier_not_closed)",
             "frontier_not_closed",
             "R_not_fed_back",
             "frontier",
             %{
               "order" => ctx.order_id,
               "standing" => standing,
               "eligible" => after_eligible
             }
           ), ctx}

        true ->
          relationships =
            Enum.map(left, &{wo(&1), "left"}) ++
              Enum.map(entered, &{wo(&1), "entered"}) ++
              [{"checkpoint:GC-26.9.23", "checkpoint"}]

          {:ok,
           event(
             ctx,
             "FrontierChanged",
             %{
               "eligible_before" => before_eligible,
               "eligible_after" => after_eligible,
               "left" => left,
               "entered" => entered,
               "ledger_tail" => after_frontier["ledger_tail"]
             },
             relationships
           )}
      end
    end
  end

  # -- actuation outcome ------------------------------------------------------

  defp actuation_outcome(
         :ok,
         %Epoch{state: :completed} = epoch,
         %Receipt{outcome: :alive} = closing,
         ctx
       ) do
    ctx =
      ctx
      |> object(
        "commit:" <> epoch.final_head,
        "Commit",
        %{
          "sha" => epoch.final_head,
          "author" => @executor,
          "parent" => ctx.order["base_sha"]
        },
        [
          {"commit:" <> ctx.order["base_sha"], "parent"},
          {"repository:" <> ctx.order["repository"], "repository"}
        ]
      )
      |> event(
        "ActuationCompleted",
        %{
          "final_head" => epoch.final_head,
          "argv_sha256" => closing.evidence["argv_sha256"],
          "steps" => Enum.map(closing.evidence["steps"] || [], &"#{&1["id"]}:#{&1["exit"]}")
        },
        [
          {wo(ctx.order_id), "work-order"},
          {"provider:" <> @executor, "provider"},
          {ctx.lease, "lease"},
          {"commit:" <> epoch.final_head, "head"}
        ],
        epoch.completed_at || now()
      )
      |> event(
        "VerificationCompleted",
        %{
          "court" => "fabric",
          "suite" => get_in(closing.evidence, ["fabric_verifier", "suite"]),
          "status" => get_in(closing.evidence, ["fabric_verifier", "status"]),
          "head" => epoch.final_head
        },
        [{wo(ctx.order_id), "work-order"}, {"commit:" <> epoch.final_head, "head"}],
        closing.sealed_at || now()
      )

    provider_hop(ctx, closing)
  end

  defp actuation_outcome(
         :ok,
         %Epoch{state: :completed},
         %Receipt{outcome: outcome} = closing,
         _ctx
       ) do
    {:refused,
     typed("BUILD_BROKEN", "fabric_court_#{outcome}", "mu_unlawful", "provider", %{
       "fabric_verifier" => closing.evidence["fabric_verifier"]
     })}
  end

  # A recipe that changed nothing produced no consequence (F4: the order
  # stays non-ALIVE); every other provider refusal is a manufacture the
  # fabric refused.
  defp actuation_outcome(:ok, %Epoch{state: :failed}, %Receipt{} = closing, _ctx) do
    reason = closing.evidence["refusal_reason"] || "refused"
    term = if reason == "no_delta", do: "R_missing_consequence", else: "mu_unlawful"

    {:refused,
     typed("REFUSED(#{reason})", reason, term, "provider", %{
       "steps" => closing.evidence["steps"],
       "executor" => closing.evidence["executor"]
     })}
  end

  defp actuation_outcome({:error, :unregistered_recipe}, _epoch, _closing, _ctx) do
    {:refused,
     typed(
       "REFUSED(unregistered_capability)",
       "unregistered_capability",
       "mu_on_O",
       "provider",
       %{}
     )}
  end

  defp actuation_outcome(result, epoch, closing, _ctx) do
    {:refused,
     typed("REFUSED(recipe_worker_error)", "recipe_worker_error", "mu_unlawful", "provider", %{
       "worker" => inspect(result),
       "epoch_state" => to_string(epoch.state),
       "closing" => closing && to_string(closing.outcome)
     })}
  end

  # The provider hop: the bridge the fabric persisted on the Run, with the
  # capability the worker actually executed (sealed closing evidence), by the
  # executor that actually held the lease.
  defp provider_hop(ctx, closing) do
    executed = closing.evidence["recipe"]
    executor = ctx.epoch.leased_to

    cond do
      executor != @executor or closing.evidence["executor"] != @executor ->
        {:refused,
         typed(
           "REFUSED(executor_not_deterministic)",
           "executor_not_deterministic",
           "mu_on_O",
           "provider",
           %{
             "leased_to" => executor,
             "evidence_executor" => closing.evidence["executor"]
           }
         )}

      true ->
        bridge = ctx.run.semantic_bridge || %{}
        carrier = Map.put(bridge, "requires_capability", executed)

        with {:ok, tuple} <- hop_tuple(:order, carrier, "provider") do
          record_hop(
            ctx,
            "provider",
            "Run.semantic_bridge + executed recipe (sealed evidence), executor #{executor}",
            tuple,
            request(
              bridge["identity"],
              tuple,
              bridge["evidence_horizon"],
              bridge["source_snapshot_digest"]
            ),
            %{"executor" => executor, "run_capability_id" => ctx.run.capability_id}
          )
        end
    end
  end

  # -- independent verification + revert falsifier ------------------------------

  defp verify_in(ctx, path) do
    court_map = ctx.run.court_map
    base_ctx = %{run_id: ctx.run.id, executor: "xaas-semantic-drive", court_map: court_map}

    {:ok, independent} =
      Verifier.run(
        ctx.suite,
        Map.merge(base_ctx, %{
          worktree: path,
          head: ctx.head,
          epoch_id: "drive-verify:" <> ctx.epoch.id
        })
      )

    verified_at = now()

    with :ok <- independent_pass(independent),
         {:ok, reverted} <- revert(path, ctx.head) do
      {:ok, falsifier} =
        Verifier.run(
          ctx.suite,
          Map.merge(base_ctx, %{
            worktree: path,
            head: reverted,
            epoch_id: "drive-falsify:" <> ctx.epoch.id
          })
        )

      falsified_at = now()

      case falsifier["status"] do
        "fail" ->
          verification = %{
            "schema" => "xaas/semantic-drive-verification/v1",
            "head" => ctx.head,
            "worktree" => "fresh detached worktree at the receipt head (removed after)",
            "independent" => independent,
            "revert_falsifier" => %{
              "reverted_commit" => ctx.head,
              "reverted_head" => reverted,
              "verdict" => "killed",
              "court" => falsifier
            }
          }

          ctx =
            ctx
            |> artifact("verification.json", verification)
            |> event(
              "VerificationCompleted",
              %{
                "court" => "independent",
                "suite" => ctx.suite,
                "status" => independent["status"],
                "head" => ctx.head
              },
              [{wo(ctx.order_id), "work-order"}, {"commit:" <> ctx.head, "head"}],
              verified_at
            )
            |> event(
              "VerificationCompleted",
              %{
                "court" => "revert-falsifier",
                "suite" => ctx.suite,
                "status" => falsifier["status"],
                "head" => reverted,
                "verdict" => "killed"
              },
              [{wo(ctx.order_id), "work-order"}, {"commit:" <> ctx.head, "reverted"}],
              falsified_at
            )

          {:ok, ctx}

        other ->
          {:refused,
           typed(
             "REFUSED(falsifier_vacuous)",
             "falsifier_vacuous",
             "admission_vacuous",
             "verify",
             %{
               "status" => other,
               "reverted_head" => reverted
             }
           )}
      end
    end
  end

  defp independent_pass(
         %{"status" => "pass", "court_receipt" => %{"acceptance_results" => acceptance}} = result
       )
       when map_size(acceptance) > 0 do
    if Enum.all?(Map.values(acceptance), &(&1 == true)),
      do: :ok,
      else: postcondition_unverified(result)
  end

  defp independent_pass(result), do: postcondition_unverified(result)

  defp postcondition_unverified(result) do
    {:refused,
     typed(
       "REFUSED(postcondition_unverified)",
       "postcondition_unverified",
       "R_missing_consequence",
       "verify",
       %{
         "status" => result["status"],
         "reason" => result["reason"]
       }
     )}
  end

  defp revert(path, head) do
    with {_, 0} <-
           git(path, [
             "-c",
             "core.hooksPath=/dev/null",
             "-c",
             "commit.gpgsign=false",
             "revert",
             "--no-edit",
             head
           ]),
         {out, 0} <- git(path, ["rev-parse", "HEAD"]) do
      {:ok, String.trim(out)}
    else
      {out, code} ->
        {:refused,
         typed(
           "REFUSED(revert_falsifier_unrunnable)",
           "revert_falsifier_unrunnable",
           "admission_vacuous",
           "verify",
           %{
             "git" => "#{code}: #{String.slice(out, -300, 300)}"
           }
         )}
    end
  end

  # -- conclusion -----------------------------------------------------------------

  defp conclude({:ok, ctx}) do
    File.mkdir_p!(ctx.out_dir)
    {:ok, digests} = verify_hops(hops_document(ctx))
    observations = {ctx.events, ctx.objects}
    court = Ocel.court_form(observations)
    standard = Ocel.standard_form(observations)

    summary = %{
      "schema" => @drive_schema,
      "standing" => "ALIVE",
      "order" => ctx.order_id,
      "dependents" => ctx.dependents,
      "checkpoint" => @checkpoint,
      "subject" => %{
        "repository" => ctx.order["repository"],
        "repo" => ctx.repo_path,
        "base_sha" => ctx.order["base_sha"],
        "head" => ctx.head,
        "pinned" => ctx.pin_ref
      },
      "provider" => %{
        "provider" => ctx.provider,
        "executor" => ctx.epoch.leased_to,
        "capability" => ctx.capability
      },
      "tuple_digest" => digests["tuple_digest"],
      "request_digest" => digests["request_digest"],
      "hops" => @hops,
      "transition" => ctx.transition,
      "frontier" => %{"left" => ctx.left, "entered" => ctx.entered},
      "ocel" => %{
        "reached" => Ocel.reached(ctx.events),
        "not_reached" => Ocel.event_classes() -- Ocel.reached(ctx.events),
        "events" => length(ctx.events),
        "objects" => map_size(ctx.objects),
        "equivalent" => Ocel.equivalent?(court, standard)
      },
      "no_llm_guard" => ctx.guard,
      "graph_side" => %{
        "ggen_igniter_dir" => ctx.ggen_dir,
        "ggen_igniter_sha" => ctx.ggen_sha,
        "toolchain" =>
          Map.take(ctx.toolchain, ~w(source elixir erlang erts mix build_manifest build_compiler))
      },
      "started_at" => DateTime.to_iso8601(ctx.started_at),
      "finished_at" => DateTime.to_iso8601(now())
    }

    summary = if ctx.route, do: Map.put(summary, "route", ctx.route), else: summary

    ctx =
      ctx
      |> artifact("hops.json", hops_document(ctx))
      |> artifact("ocel.json", court)
      |> artifact("ocel2.json", standard)
      |> artifact("drive.json", summary)

    Enum.each(ctx.artifacts, fn {name, value} ->
      File.write!(Path.join(ctx.out_dir, name), Jason.encode!(value, pretty: true) <> "\n")
    end)

    cleanup(ctx)
    {:ok, Map.put(summary, "artifacts", ctx.artifacts |> Map.keys() |> Enum.sort())}
  end

  defp conclude({:refused, typed, ctx}) do
    File.mkdir_p!(ctx.out_dir)

    refusal = %{
      "schema" => @drive_schema,
      "outcome" => typed,
      "order" => ctx.order_id,
      "hops" => ctx.hops,
      "ocel_reached" => Ocel.reached(ctx.events),
      "frontier_before" => Map.get(ctx, :frontier_before)
    }

    File.write!(
      Path.join(ctx.out_dir, "refused.json"),
      Jason.encode!(refusal, pretty: true) <> "\n"
    )

    cleanup(ctx)
    {:refused, typed}
  end

  defp hops_document(ctx) do
    %{
      "schema" => @hops_schema,
      "work_order" => ctx.order_id,
      "fields" => Route.fields(),
      "request_fields" => @request_fields,
      "digest_contract" =>
        "tuple: Xaas.Sa2a.Route.digest/1; request: SemanticDrive.request_digest/1 (ARD section 8 SemanticExecutionRequest); both sha256 over canonical JSON (sorted keys, compact separators, UTF-8 unescaped, exclusions sorted)",
      "hops" => ctx.hops
    }
  end

  defp cleanup(ctx) do
    Enum.each(ctx.cleanup, fn path -> Worktrees.cleanup(ctx.repo_alias, path) end)
    File.rm_rf(ctx.scratch)
  end

  # -- helpers --------------------------------------------------------------------

  defp frontier(ctx) do
    case ggen(ctx, "semantic_jira.frontier", [
           "--work-orders",
           ctx.work_graph,
           "--ledger",
           ctx.ledger
         ]) do
      {0, %{"status" => "ok"} = frontier, _out} ->
        {:ok, frontier}

      {code, json, out} ->
        if build_broken?(code, out) do
          # The graph side never ran: its checkout does not compile under
          # the resolved toolchain (e.g. a rustler NIF rebuild with no cargo
          # on the graph-side PATH). An environment verdict, not a frontier.
          {:refused,
           typed("BUILD_BROKEN", "graph_side_build_broken", "mu_unlawful", "sjira", %{
             "exit" => code,
             "toolchain" => Map.take(ctx.toolchain, ~w(source elixir mix build_compiler)),
             "reason" => brief(json, out)
           })}
        else
          {:refused,
           typed(
             "REFUSED(frontier_refused)",
             "frontier_refused",
             "R_missing_standing",
             "sjira",
             %{
               "exit" => code,
               "reason" => brief(json, out)
             }
           )}
        end
    end
  end

  defp build_broken?(0, _out), do: false

  defp build_broken?(_code, out),
    do: String.contains?(out, ["== Compilation error", "could not compile dependency"])

  defp resolve(tuple) do
    case Route.resolve(tuple) do
      {:ok, resolved} ->
        {:ok, resolved}

      {:refused, :unregistered_capability} ->
        {:refused,
         typed(
           "REFUSED(unregistered_capability)",
           "unregistered_capability",
           "mu_on_O",
           "resolve",
           %{
             "capability" => tuple["capability"]
           }
         )}
    end
  end

  # The routing provenance (lane V23-M) must name exactly the capability the
  # tuple carries: a route that says one capability while the order executes
  # another would make the route evidence say nothing about what executed.
  defp route_capability(nil, _capability), do: :ok
  defp route_capability(%{"capability" => capability}, capability), do: :ok

  defp route_capability(route, capability) do
    {:refused,
     typed(
       "REFUSED(route_capability_mismatch)",
       "route_capability_mismatch",
       "admission_vacuous",
       "resolve",
       %{"route" => route, "capability" => capability}
     )}
  end

  defp route_provenance(ctx, nil), do: {%{}, [], ctx}

  defp route_provenance(ctx, %{"source" => "machine_experience"} = route) do
    iri = Map.fetch!(route, "machine_experience")
    id = "machine-experience:" <> iri

    ctx =
      object(ctx, id, "MachineExperience", %{
        "iri" => iri,
        "experience_digest" => route["experience_digest"],
        "admission" => route["admission"],
        "problem_class" => route["problem_class"]
      })

    {%{"route_source" => "machine_experience", "machine_experience" => iri},
     [{id, "machine-experience"}], ctx}
  end

  defp route_provenance(ctx, %{"source" => "exploration"} = route) do
    producer = Map.fetch!(route, "producer")
    id = "provider:" <> producer

    ctx =
      object(ctx, id, "Provider", %{
        "provider" => producer,
        "provider_class" => route["producer_class"],
        "deterministic" => false,
        "role" => "exploration candidate proposer"
      })

    {%{
       "route_source" => "exploration",
       "exploration_digest" => route["exploration_digest"],
       "candidate_producer" => producer
     }, [{id, "proposer"}], ctx}
  end

  defp route_provenance(ctx, %{"source" => source}),
    do: {%{"route_source" => source}, [], ctx}

  defp deterministic_provider(provider, provider), do: :ok

  defp deterministic_provider(resolved, wanted) do
    {:refused,
     typed("REFUSED(provider_mismatch)", "provider_mismatch", "mu_on_O", "resolve", %{
       "resolved" => resolved,
       "requested" => wanted
     })}
  end

  defp registered_recipe(capability) do
    case RecipeWorker.recipe(capability) do
      {:ok, recipe} ->
        {:ok, recipe}

      {:error, reason} ->
        {:refused,
         typed(
           "REFUSED(unregistered_capability)",
           "unregistered_capability",
           "mu_on_O",
           "resolve",
           %{
             "capability" => capability,
             "reason" => inspect(reason)
           }
         )}
    end
  end

  defp same_snapshot(task, snapshot) do
    if task["contextId"] == snapshot,
      do: :ok,
      else:
        {:refused,
         typed(
           "REFUSED(tuple_digest_mismatch)",
           "tuple_digest_mismatch",
           "admission_vacuous",
           "sa2a",
           %{
             "context_id" => task["contextId"],
             "work_order_digest" => snapshot
           }
         )}
  end

  defp hop_tuple(kind, representation, hop) do
    case Route.tuple(kind, representation) do
      {:ok, tuple} ->
        {:ok, tuple}

      {:refused, reason} ->
        {:refused,
         typed("REFUSED(tuple_incomplete)", "tuple_incomplete", "admission_vacuous", hop, %{
           "reason" => inspect(reason)
         })}
    end
  end

  # Records one hop -- its Route contract tuple and its ARD section 8
  # SemanticExecutionRequest, each with its digest -- and refuses the moment
  # the request is incomplete or either digest differs from the sJira hop's.
  defp record_hop(ctx, name, carrier, tuple, request, extra \\ %{}) do
    case well_formed(request, @request_fields, name, "request") do
      {:ok, request} ->
        entry =
          Map.merge(extra, %{
            "hop" => name,
            "carrier" => carrier,
            "tuple" => tuple,
            "digest" => Route.digest(tuple),
            "request" => request,
            "request_digest" => request_digest(request)
          })

        ctx = Map.put(ctx, :hops, ctx.hops ++ [entry])
        expected = hop_of(ctx, "sjira")

        cond do
          entry["digest"] != expected["digest"] ->
            hop_mismatch(ctx, name, "tuple", expected, entry, Route.fields())

          entry["request_digest"] != expected["request_digest"] ->
            hop_mismatch(ctx, name, "request", expected, entry, @request_fields)

          true ->
            {:ok, ctx}
        end

      {:refused, typed} ->
        {:refused, typed, ctx}
    end
  end

  defp hop_mismatch(ctx, name, key, expected, observed, fields) do
    digest_key = if key == "tuple", do: "digest", else: "request_digest"

    {:refused,
     typed(
       "REFUSED(tuple_digest_mismatch)",
       "tuple_digest_mismatch",
       "admission_vacuous",
       name,
       %{
         "carrier" => key,
         "expected" => expected[digest_key],
         "observed" => observed[digest_key],
         "field" => Enum.find(fields, &(expected[key][&1] != observed[key][&1]))
       }
     ), ctx}
  end

  defp hop_of(ctx, name), do: Enum.find(ctx.hops, &(&1["hop"] == name))

  defp request(work_order, tuple, horizon, graph_digest) do
    %{
      "work_order" => work_order,
      "subject" => tuple["subject"],
      "postcondition" => tuple["postcondition"],
      "capability" => tuple["capability"],
      "evidence_horizon" => horizon,
      "authority_ceiling" => tuple["authority_ceiling"],
      "consequence_class" => tuple["consequence_class"],
      "exclusions" => tuple["exclusions"],
      "graph_digest" => graph_digest
    }
  end

  # The route-tuple data part of an SA2A task (the carrier Route reads).
  defp task_carrier(task) do
    task
    |> Map.get("input", [])
    |> List.wrap()
    |> Enum.find_value(%{}, fn
      %{"kind" => "data", "data" => %{"schema" => schema} = data} ->
        if schema == Route.route_schema(), do: data

      _ ->
        nil
    end)
  end

  defp pin(%{pin_ref: nil}, _head), do: :ok

  defp pin(ctx, head) do
    ref = "refs/heads/" <> ctx.pin_ref

    case git(ctx.repo_path, ["rev-parse", "--verify", "-q", ref]) do
      {existing, 0} ->
        if String.trim(existing) == head,
          do: :ok,
          else: pin_refused(ref, "exists at #{String.trim(existing)}")

      _absent ->
        case git(ctx.repo_path, [
               "update-ref",
               "-m",
               "xaas semantic drive receipt head",
               ref,
               head,
               String.duplicate("0", 40)
             ]) do
          {_, 0} -> :ok
          {out, code} -> pin_refused(ref, "#{code}: #{out}")
        end
    end
  end

  defp pin_refused(ref, why) do
    {:refused,
     typed("REFUSED(pin_refused)", "pin_refused", "R_missing_replay", "receipt", %{
       "ref" => ref,
       "why" => why
     })}
  end

  defp order_objects(ctx, row, rows) do
    ctx =
      ctx
      |> object("checkpoint:GC-26.9.23", "GoalCheckpoint", %{"iri" => @checkpoint})
      |> object("repository:" <> row["repository"], "Repository", %{
        "identity" => row["repository"],
        "path" => ctx.repo_path
      })
      |> object(
        "commit:" <> row["base_sha"],
        "Commit",
        %{"sha" => row["base_sha"], "role" => "episode subject"},
        [
          {"repository:" <> row["repository"], "repository"}
        ]
      )
      |> object(
        "subject:" <> row["subject"],
        "Subject",
        %{"subject" => row["subject"], "base_sha" => row["base_sha"]},
        [
          {"commit:" <> row["base_sha"], "base"},
          {"repository:" <> row["repository"], "repository"}
        ]
      )

    Enum.reduce(rows, ctx, fn r, acc ->
      deps = Enum.map(r["dependencies"] || [], &{wo(&1["upstream"]), &1["type"] || "dependency"})

      object(
        acc,
        wo(r["identity"]),
        "WorkOrder",
        %{
          "identity" => r["identity"],
          "standing" => r["standing"],
          "capability" => r["requires_capability"]
        },
        [{"checkpoint:GC-26.9.23", "checkpoint"} | deps]
      )
    end)
  end

  defp object(ctx, id, type, attributes, relationships \\ []) do
    objects =
      Map.update(
        ctx.objects,
        id,
        %{type: type, attributes: attributes, relationships: relationships},
        fn existing ->
          %{
            existing
            | attributes: Map.merge(existing.attributes, attributes),
              relationships: Enum.uniq(existing.relationships ++ relationships)
          }
        end
      )

    %{ctx | objects: objects}
  end

  defp event(ctx, type, attributes, relationships, time \\ nil) do
    entry = %{
      type: type,
      time: time || now(),
      attributes: attributes,
      relationships: relationships
    }

    %{ctx | events: ctx.events ++ [entry]}
  end

  defp artifact(ctx, name, value), do: %{ctx | artifacts: Map.put(ctx.artifacts, name, value)}

  defp work_orders(list) when is_list(list), do: {:ok, list}
  defp work_orders(%{"work_orders" => list}) when is_list(list), do: {:ok, list}

  defp work_orders(_other),
    do:
      {:refused,
       typed("REFUSED(work_graph_invalid)", "work_graph_invalid", "mu_on_O", "sjira", %{})}

  defp find_order(rows, id) do
    case Enum.find(rows, &(is_map(&1) and &1["identity"] == id)) do
      nil ->
        {:refused,
         typed(
           "REFUSED(order_not_in_work_graph)",
           "order_not_in_work_graph",
           "mu_on_O",
           "sjira",
           %{"order" => id}
         )}

      row ->
        {:ok, row}
    end
  end

  defp read_json(path, reason, hop) do
    with {:ok, body} <- File.read(path),
         {:ok, decoded} <- Jason.decode(body) do
      {:ok, decoded}
    else
      error ->
        {:refused,
         typed("REFUSED(#{reason})", reason, "mu_on_O", hop, %{
           "path" => path,
           "error" => inspect(error)
         })}
    end
  end

  defp closing_receipt(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
    |> Enum.find(
      &(Map.has_key?(&1.evidence, "head_verified") or Map.has_key?(&1.evidence, "refusal_reason"))
    )
  end

  defp ids(entries), do: Enum.map(entries || [], & &1["identity"])

  defp wo(identity), do: "workorder:" <> identity

  defp durable(ctx, name) do
    path = Path.join(ctx.out_dir, name)
    relative = Path.relative_to(Path.expand(path), File.cwd!())
    if Path.type(relative) == :relative, do: relative, else: path
  end

  defp typed(standing, reason, broken_term, hop, detail) do
    %{
      "standing" => standing,
      "reason" => reason,
      "broken_term" => broken_term,
      "hop" => hop,
      "detail" => detail
    }
  end

  defp brief(%{"reason" => reason}, _out), do: reason
  defp brief(%{} = json, _out), do: json
  defp brief(_nil, out), do: String.slice(out, -600, 600)

  defp hex20(value),
    do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower) |> binary_part(0, 20)

  defp now, do: DateTime.utc_now()

  defp make_scratch do
    dir = Path.join(System.tmp_dir!(), "xaas-drive-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp git_head(dir) do
    case git(dir, ["rev-parse", "HEAD"]) do
      {out, 0} -> String.trim(out)
      _ -> nil
    end
  end

  defp git(dir, args) do
    System.cmd("git", ["-C", dir | args],
      env: @git_identity ++ llm_unset(),
      stderr_to_stdout: true
    )
  end

  # Every child process of the drive runs with the model-credential variables
  # of the calling environment UNSET, whatever that environment holds: no
  # credential reaches the graph side or git even when the guard was handed a
  # narrower environment than the process's own.
  defp llm_unset do
    for {name, _value} <- System.get_env(), llm_variable?(name), do: {name, nil}
  end

  # The graph side is its own project with its own toolchain pin: run it
  # through the toolchain its `.tool-versions` resolves to (absolute install
  # paths, no asdf shim), from its own directory, stdin /dev/null, output to
  # a file, under a hard perl-alarm deadline (exit 142).
  defp ggen(ctx, task, args) do
    out_file = Path.join(ctx.scratch, "ggen-#{System.unique_integer([:positive])}.out")
    script = ~S(out="$1"; shift; exec "$@" >"$out" 2>&1 </dev/null)

    env =
      [
        {"MIX_ENV", ctx.mix_env},
        {"PATH", ctx.toolchain["path"]},
        {"ASDF_ELIXIR_VERSION", nil},
        {"ASDF_ERLANG_VERSION", nil},
        {"MIX_BUILD_PATH", ctx.ggen_build_path}
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
        cd: ctx.ggen_dir,
        env: env
      )

    out = File.read!(out_file)
    File.rm(out_file)
    {code, last_json(out), out}
  end

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
