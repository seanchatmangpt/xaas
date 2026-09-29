defmodule Xaas.Ultracode.SemanticJiraBridge do
  @moduledoc """
  The seam between the canonical Semantic Jira work graph (`ggen_igniter`,
  `GgenIgniter.SemanticJira.*`) and the Ultracode execution fabric
  (`Xaas.Ultracode.*`), called in-process: the graph decides WHAT is
  admitted, eligible and promoted; the fabric decides whether the work was
  DONE. Neither side interprets the other's internals, and nothing here grants
  authority (every projection carries `authority: NONE`).

  ## The loop this module closes

      candidate WorkOrder
        -> admit_candidate/2      kernel admission (+ SHACL when shapes given)
        -> frontier/2             SemanticJira.frontier_from_events/3 over the log
        -> descriptor/4           SemanticJira.Descriptor.build/4, carried into the
                                  XaaS execution input SemanticWork.admit/1 accepts
        -> SemanticWork.materialize/2, worker, Lease.close/4     [fabric, unchanged]
        -> SemanticReceipt.export/1                              [fabric, unchanged]
        -> reconciler_receipt/2   export -> the receipt Reconciler.reconcile/4 admits
        -> admit/5                Reconciler.reconcile/4 appends to TransitionLog
                                  and returns the NEW frontier
        -> state/2                replayable from the log alone

  ## What is refused, and how (typed `{:error, {:refused_bridge, reason}}`)

    * a tampered export: `:receipt_digest_mismatch` / `:invalid_receipt_digest`;
    * an export the fabric never sealed (forged, even with a recomputed digest):
      `:export_not_sealed_by_fabric`, checked against the sealed Postgres row;
    * a stale or mismatched definition: `:definition_mismatch` (the reconciler's
      own check of the receipt's definition digest against the work order as it
      is NOW); a stale snapshot alone stays admissible, as upstream specifies;
    * an unadmitted work order: `{:unadmitted, reason}` (kernel),
      `{:shacl, violations}`, `{:not_on_frontier, reason}` (unmet dependencies,
      standing already moved), `:unknown_work_order`;
    * a promotion the calculus refuses (courts, evidence, acceptance,
      falsifiers, ceiling, receipts, subject): `{:promotion_refused, [checks]}`
      -- the log does not move and the work order stays on the frontier;
    * a malformed export (a digest-valid export whose `fabric_verifier`, `steps`
      or court receipt has the wrong shape): `{:malformed_export, path}`, never
      an exception;
    * a log the bridge cannot trust: `{:log_untrusted, detail}` (an event whose
      `event_digest` does not re-derive from its own content, an unreadable event
      file, a standing chain that skips a step). Nothing is eligible over such a
      log and nothing is appended to it;
    * an admission that could not be serialized: `{:log_lock, :perl_unavailable |
      :lock_timeout | {:lock_failed, exit_status}}` (the OS lock of the log, see below);
    * an append the log did not honour: `{:log_claim_orphaned, receipt_digest}`
      (a writer died between claiming the event digest and writing the event, so
      the log answers `already recorded` with no event; `reap_orphaned_claims/1`
      clears it) and `{:receipt_not_recorded, ...}` (the log answered with an
      event that cites a different receipt than the one submitted).

  ## Evidence provenance

  Acceptance / falsifier / court verdicts come ONLY from the fabric-produced
  court receipt inside the export (`Xaas.Ultracode.CourtReceipt`), only when
  the fabric verifier passed and the receipt is bound to the sealed head and to a
  step the fabric ran. The worker never supplies them. A required court counts
  as witnessed when the fabric's own step for it passed at the sealed head.
  Fabric-only evidence tops out at the `"repository-local"` ceiling.

  What makes a court receipt fabric-produced is enforced upstream of this
  module, not read off the receipt: `Xaas.Ultracode.Verifier` drops a suite
  script's printed JSON line that carries the fabric-only `"binding"` key and
  pins the files that decide a verdict (mapped test files and the receipt
  step's file operands) to their base-SHA bytes, and
  `Xaas.Ultracode.SemanticReceipt.export/1` exports a court receipt only for a
  Run that has a court map, bound to that Run's suite, sealed head and a step
  it ran. Residual: a `mix_trace` suite maps test DESCRIPTIONS, not files, so
  only its argv file operands are pinned.

  ## The log is a trust root

  The transition log directory is read as data written by the reconciler. Every
  read through this module first checks that each event's `event_digest`
  re-derives from the event's own content (`TransitionLog.event_digest/1`, which
  commits to the receipt the event cites; logs written before that rule verify
  under `TransitionLog.legacy_event_digest/1`) and that each work order's
  standing chain is unbroken. This detects a tampered or hand-written event; it
  cannot detect a forger who can write the directory and recomputes digests. The
  check-then-append admission runs under `Xaas.Ultracode.LogLock`, an OS-level
  lock, so admissions from separate OS processes are serialized too.

  ## Hand-written residue

  This module is hand-written: there is no ggen pack that manufactures
  XaaS-side Ultracode glue, so it is recorded as
  `UNSUPPORTED(generator-capability)` for the receipt-mapping and
  descriptor-composition functions (`reconciler_receipt/2`, `descriptor/4`).
  Everything that can be a call into the kernel is one: admission, digests
  of graph objects, frontier, projection, reconciliation, log I/O, descriptor
  identity, A2A task projection.
  """

  alias GgenIgniter.SemanticJira
  alias GgenIgniter.SemanticJira.{Descriptor, Reconciler, Shacl, TransitionLog}
  alias Xaas.Ultracode.{LogLock, SemanticReceipt, SemanticWork}

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @dcterms_identifier "http://purl.org/dc/terms/identifier"

  @work_order_prefix "urn:semantic-jira:work-order:"
  @checkpoint_prefix "urn:semantic-jira:checkpoint:"
  @receipt_prefix "urn:semantic-jira:receipt:"
  @zero_digest "sha256:" <> String.duplicate("0", 64)
  @fabric_ceiling "repository-local"

  @sha ~r/\A[0-9a-f]{40}\z/
  @digest ~r/\Asha256:[0-9a-f]{64}\z/

  @bridge_keys ~w(identity definition_digest snapshot_digest repository base_sha subject)

  @outcomes %{
    "alive" => "ALIVE",
    "partial_alive" => "PARTIAL_ALIVE",
    "build_broken" => "BUILD_BROKEN",
    "blocked" => "BLOCKED"
  }

  @type work_order :: map()
  @type refusal :: {:error, {:refused_bridge, term()}}

  # ------------------------------------------------------------------
  # Admission of a candidate
  # ------------------------------------------------------------------

  @doc """
  Kernel-admits a candidate WorkOrder (`SemanticJira.admit_work_order/1`) and,
  when `:shapes` (an `RDF.Graph`) is given, SHACL-admits its
  `candidate_graph/1` against them with the real `SemanticJira.Shacl` court.
  """
  @spec admit_candidate(work_order(), keyword()) :: {:ok, map()} | refusal()
  def admit_candidate(work_order, opts \\ []) do
    with {:ok, admitted} <- kernel(work_order),
         :ok <- shacl(work_order, Keyword.get(opts, :shapes)) do
      {:ok, admitted}
    end
  end

  @doc """
  The RDF individual of a WorkOrder as the SHACL court sees it: the fields the
  candidate shape constrains (`dcterms:identifier`, `sj:repository`,
  `sj:baseSha`, `sj:standing`). A field the work order lacks yields no triple,
  so a missing field is a `sh:minCount` violation rather than a default.
  """
  @spec candidate_graph(work_order()) :: RDF.Graph.t()
  def candidate_graph(work_order) do
    wo = stringify(work_order)
    subject = RDF.iri(@work_order_prefix <> to_string(wo["identity"]))

    fields = [
      {RDF.iri(@dcterms_identifier), wo["identity"]},
      {RDF.iri(@sj <> "repository"), wo["repository"]},
      {RDF.iri(@sj <> "baseSha"), wo["base_sha"]},
      {RDF.iri(@sj <> "standing"), wo["standing"]}
    ]

    triples =
      for {predicate, value} <- fields, not is_nil(value) do
        {subject, predicate, RDF.literal(value)}
      end

    RDF.Graph.new([{subject, RDF.type(), RDF.iri(@sj <> "WorkOrder")} | triples])
  end

  # ------------------------------------------------------------------
  # Frontier and replayable state
  # ------------------------------------------------------------------

  @doc """
  The frontier over the projection of the transition log in `log_dir`. Over a log
  that fails verification (see "The log is a trust root") nothing is eligible and
  every work order is blocked with reason `"log_untrusted"`.
  """
  @spec frontier([work_order()], Path.t()) :: %{eligible: [map()], blocked: [map()]}
  def frontier(work_orders, log_dir) when is_list(work_orders) do
    case verified_events(log_dir) do
      {:ok, events} -> SemanticJira.frontier_from_events(work_orders, events)
      {:error, _refusal} -> %{eligible: [], blocked: untrusted_blocked(work_orders)}
    end
  end

  @doc """
  Everything the log determines, as plain JSON-safe data: standings, eligible
  identities, blocked entries, the events and the ledger tail. Equal `state/2`
  of two copies of one log is the replay criterion.
  """
  @spec state([work_order()], Path.t()) :: map()
  def state(work_orders, log_dir) do
    case verified_events(log_dir) do
      {:ok, events} ->
        trusted_state(work_orders, events)

      {:error, {:refused_bridge, {:log_untrusted, detail}}} ->
        untrusted_state(work_orders, detail)
    end
  end

  defp trusted_state(work_orders, events) do
    {projected, _evidence} = SemanticJira.project(work_orders, events)
    front = SemanticJira.frontier_from_events(work_orders, events)

    %{
      "standings" => Map.new(projected, &{&1["identity"], &1["standing"]}),
      "eligible" => Enum.map(front.eligible, & &1["identity"]),
      "blocked" => Enum.map(front.blocked, &Map.take(&1, ~w(identity reason))),
      "events" =>
        Enum.map(
          events,
          &Map.take(&1, ~w(seq identity from to receipt_digest event_digest transition_digest))
        ),
      "ledger_tail" => ledger_tail(events)
    }
  end

  # A log that does not verify determines nothing: no standing moved, nothing is
  # eligible, the events are not reported. `log_untrusted` names why.
  defp untrusted_state(work_orders, reason) do
    %{
      "standings" =>
        Map.new(work_orders, &{stringify(&1)["identity"], stringify(&1)["standing"]}),
      "eligible" => [],
      "blocked" => untrusted_blocked(work_orders),
      "events" => [],
      "ledger_tail" => @zero_digest,
      "log_untrusted" => json_safe(reason)
    }
  end

  defp untrusted_blocked(work_orders),
    do:
      Enum.map(
        work_orders,
        &%{"identity" => stringify(&1)["identity"], "reason" => "log_untrusted"}
      )

  # ------------------------------------------------------------------
  # Descriptor emission
  # ------------------------------------------------------------------

  @doc """
  Emits the execution descriptor of ONE frontier-eligible work order.

  Returns `{:ok, %{descriptor: v1, execution: input}}`:

    * `descriptor` is `SemanticJira.Descriptor.build/4`'s
      `semantic-jira/execution-descriptor/v1` (carrying `definition_digest`,
      `snapshot_digest`, `graph_digest`, `base_sha`, authority `NONE`);
    * `execution` is the map `Xaas.Ultracode.SemanticWork.admit/1` /
      `materialize/2` consume (already admitted here), whose opaque `"bridge"`
      echoes the descriptor identity and comes back verbatim in the sealed
      export.

  Options: `:execution_repo_alias` and `:verifier_suite` (required, never
  invented), `:graph_digest` (required `sha256:` digest of the canonical
  ontology graph), `:source_digest`, `:provider` (default `"zcode"`),
  `:worker_identity`, `:verifier_identity`, `:execution_policy` (default
  `"autonomic_wave_attempt"`), `:court_map` (see `Xaas.Ultracode.CourtReceipt`),
  `:shapes` (SHACL-admit the work order first), `:attempt` (a retry marker,
  so a re-run of the same ledger tail gets its own checkpoint and worktree),
  `:iri_prefix`.
  """
  @spec descriptor([work_order()], Path.t(), String.t(), keyword()) ::
          {:ok, %{descriptor: map(), execution: map()}} | refusal()
  def descriptor(work_orders, log_dir, identity, opts)
      when is_list(work_orders) and is_binary(identity) do
    prefix = Keyword.get(opts, :iri_prefix, @work_order_prefix)

    with {:ok, events} <- verified_events(log_dir),
         {:ok, exec_alias} <- required_option(opts, :execution_repo_alias),
         {:ok, suite} <- required_option(opts, :verifier_suite),
         {:ok, graph_digest} <- digest_option(opts, :graph_digest),
         {:ok, raw} <- find(work_orders, identity),
         {:ok, admitted} <- admit_candidate(raw, shapes: Keyword.get(opts, :shapes)),
         {:ok, v1} <-
           build_descriptor(work_orders, events, identity, graph_digest, suite, opts),
         {:ok, court_map} <- court_map(Keyword.get(opts, :court_map), admitted),
         {:ok, dependencies} <- dependencies(admitted, events, prefix),
         execution =
           execution(admitted, v1, %{
             tail: ledger_tail(events),
             exec_alias: exec_alias,
             suite: suite,
             dependencies: dependencies,
             court_map: court_map,
             prefix: prefix,
             opts: opts
           }),
         :ok <- work_admit(execution) do
      {:ok, %{descriptor: v1, execution: execution}}
    end
  end

  @doc """
  The A2A task projection of an emitted descriptor
  (`SemanticJira.Descriptor.to_a2a_task/3`): refuses when the descriptor's
  graph identity disagrees with the work order it claims to describe; the
  descriptor's `definition_digest` / `snapshot_digest` / `base_sha` /
  `graph_digest` land verbatim in the task metadata.
  """
  @spec a2a_task(map(), work_order(), keyword()) :: {:ok, map()} | refusal()
  def a2a_task(descriptor, work_order, opts \\ []) do
    case Descriptor.to_a2a_task(descriptor, work_order, opts) do
      {:ok, task} -> {:ok, task}
      {:error, {:refused_descriptor, reason}} -> refuse({:a2a, reason})
      {:error, reason} -> refuse({:a2a, reason})
    end
  end

  # ------------------------------------------------------------------
  # Receipt mapping and admission
  # ------------------------------------------------------------------

  @doc """
  Maps one sealed `Xaas.Ultracode.SemanticReceipt.export/1` onto the receipt
  `SemanticJira.Reconciler.reconcile/4` consumes.

  Pure: standing is never inferred from the outcome. Refuses (typed) a
  non-map, a bridge that is not the descriptor's, a digest that is not the
  export's own (tamper), a digest-valid export of the wrong shape
  (`{:malformed_export, path}`), a non-40-hex head, an unsupported outcome, and
  an ALIVE claim without a verified head and a passing fabric verifier.
  """
  @spec reconciler_receipt(map(), work_order()) :: {:ok, map()} | refusal()
  def reconciler_receipt(export, work_order) when is_map(export) and is_map(work_order) do
    export = stringify(export)

    with {:ok, admitted} <- kernel(work_order),
         {:ok, bridge} <- bridge_of(export, admitted),
         :ok <- digest_ok(export),
         :ok <- shape_ok(export),
         :ok <- ensure(sha?(export["final_head"]), :invalid_final_head),
         {:ok, target} <- target(export["outcome"]),
         :ok <- ensure(is_boolean(export["head_verified"]), :head_verified_not_boolean),
         :ok <- alive_guards(export, target) do
      {:ok, mapped_receipt(export, admitted, bridge, target)}
    end
  end

  def reconciler_receipt(_export, _work_order), do: refuse(:not_a_map)

  @doc """
  Admits one export for `identity` into the log at `log_dir`.

  On admit the `Reconciler` appends the standing transition and this returns
  `{:ok, %{event:, disposition: :appended | :already_recorded, receipt:,
  frontier:}}` where `frontier` is the NEW frontier
  (`SemanticJira.frontier_from_events/3`). Replaying the same export is
  idempotent. Any refusal leaves the log untouched.

  Options: `:fabric_check` (default `true`): require the export to equal what
  the fabric sealed for its epoch, so a forged export with a recomputed digest
  is refused. Disable only for archived exports whose Run rows are gone.
  """
  @spec admit([work_order()], String.t(), map(), Path.t(), keyword()) ::
          {:ok, map()} | refusal()
  def admit(work_orders, identity, export, log_dir, opts \\ []) when is_list(work_orders) do
    with {:ok, raw} <- find(work_orders, identity),
         {:ok, receipt} <- reconciler_receipt(export, raw),
         :ok <- fabric_check(export, opts) do
      serialized(log_dir, fn -> commit(work_orders, identity, raw, receipt, log_dir) end)
    end
  end

  @doc """
  Removes the digest claims of `log_dir` that no event backs: what a writer killed
  between claiming an event digest and writing the event file leaves behind (and
  what makes `admit/5` refuse `{:log_claim_orphaned, _}` for that receipt for good).

  Runs under the log's lock, so no bridge admission is mid-append; call it only
  when no OTHER writer is appending to `log_dir` (a writer that claimed a digest
  moments ago and has not yet written its event would lose its claim). Returns
  `{:ok, removed_claim_file_names}`.
  """
  @spec reap_orphaned_claims(Path.t()) :: {:ok, [String.t()]} | refusal()
  def reap_orphaned_claims(log_dir) do
    serialized(log_dir, fn ->
      backed =
        log_dir
        |> TransitionLog.read()
        |> MapSet.new(&("digest-" <> String.slice(&1["event_digest"], 7, 64) <> ".claim"))

      orphans =
        case File.ls(log_dir) do
          {:ok, names} ->
            names
            |> Enum.filter(
              &(String.starts_with?(&1, "digest-") and String.ends_with?(&1, ".claim"))
            )
            |> Enum.reject(&MapSet.member?(backed, &1))
            |> Enum.sort()

          {:error, _} ->
            []
        end

      Enum.each(orphans, &File.rm!(Path.join(log_dir, &1)))
      {:ok, orphans}
    end)
  end

  defp commit(work_orders, identity, raw, receipt, log_dir) do
    with {:ok, events} <- verified_events(log_dir),
         :ok <- on_frontier_or_recorded(work_orders, identity, receipt, events),
         {:ok, event, disposition} <- reconcile(raw, receipt, log_dir) do
      {:ok,
       %{
         event: event,
         disposition: disposition,
         receipt: receipt,
         frontier: frontier(work_orders, log_dir)
       }}
    end
  end

  @doc """
  `admit/5` over the receipt the fabric sealed for `epoch_id`, read straight
  from `Xaas.Ultracode.SemanticReceipt.export/1` (the sealed Postgres row is the
  trust root, so no fabric re-check is needed).
  """
  @spec admit_epoch([work_order()], String.t(), String.t(), Path.t(), keyword()) ::
          {:ok, map()} | refusal()
  def admit_epoch(work_orders, identity, epoch_id, log_dir, opts \\ []) do
    case SemanticReceipt.export(epoch_id) do
      {:ok, export} ->
        admit(work_orders, identity, export, log_dir, Keyword.put(opts, :fabric_check, false))

      {:error, reason} ->
        refuse({:no_sealed_receipt, reason})
    end
  end

  # ------------------------------------------------------------------
  # Descriptor internals
  # ------------------------------------------------------------------

  defp build_descriptor(work_orders, events, identity, graph_digest, suite, opts) do
    provider = Keyword.get(opts, :provider, "zcode")

    attrs = %{
      "graph_digest" => graph_digest,
      "source_digest" => Keyword.get(opts, :source_digest) || SemanticJira.digest(work_orders),
      "provider" => provider,
      "worker_identity" => Keyword.get(opts, :worker_identity, "worker:" <> provider),
      "verifier_identity" =>
        Keyword.get(opts, :verifier_identity, "xaas-fabric-verifier:" <> suite)
    }

    case Descriptor.build(work_orders, identity, attrs, events: events) do
      {:ok, v1} -> {:ok, v1}
      {:error, {:refused_descriptor, :not_found}} -> refuse(:unknown_work_order)
      {:error, {:refused_descriptor, reason}} -> refuse(reason)
      {:error, reason} -> refuse({:descriptor, reason})
    end
  end

  defp execution(admitted, v1, ctx) do
    %{
      "work_order_iri" => ctx.prefix <> admitted["identity"],
      "checkpoint_iri" => @checkpoint_prefix <> ctx.tail <> attempt_suffix(ctx.opts[:attempt]),
      "graph_digest" => v1["graph_digest"],
      "repository_identity" => v1["repository"],
      "execution_repo_alias" => ctx.exec_alias,
      "base_sha" => v1["base_sha"],
      "goal" => goal(admitted),
      "provider" => v1["provider"],
      "verifier_suite" => ctx.suite,
      "execution_policy" =>
        to_string(Keyword.get(ctx.opts, :execution_policy, "autonomic_wave_attempt")),
      "dependencies" => ctx.dependencies,
      "bridge" => bridge(admitted, v1, ctx.tail)
    }
    |> put_unless_nil("court_map", ctx.court_map)
  end

  defp attempt_suffix(nil), do: ""
  defp attempt_suffix(n) when is_integer(n) and n > 1, do: ":attempt-#{n}"
  defp attempt_suffix(_), do: ""

  defp bridge(admitted, v1, tail) do
    %{
      "identity" => admitted["identity"],
      "definition_digest" => v1["definition_digest"],
      "snapshot_digest" => v1["snapshot_digest"],
      "graph_digest" => v1["graph_digest"],
      "ledger_tail" => tail,
      "repository" => admitted["repository"],
      "base_sha" => admitted["base_sha"],
      "subject" => admitted["subject"],
      "evidence_ceiling" => admitted["evidence_ceiling"],
      "replay_identity" => admitted["replay_identity"],
      "requires" => requires(admitted)
    }
  end

  defp requires(admitted) do
    %{
      "courts" => admitted["required_courts"],
      "acceptance" => admitted["acceptance"],
      "falsifiers" => admitted["falsifiers"],
      "evidence" => admitted["required_evidence"]
    }
  end

  defp goal(admitted) do
    [
      "#{admitted["identity"]}: #{admitted["title"]}",
      "",
      admitted["description"],
      "",
      "Acceptance:" | Enum.map(admitted["acceptance"], &"- #{&1}")
    ]
    |> Kernel.++(["", "Falsifiers:" | Enum.map(admitted["falsifiers"], &"- #{&1}")])
    |> Kernel.++(scope_lines(admitted["path_scope"]))
    |> Enum.join("\n")
  end

  defp scope_lines([]), do: []
  defp scope_lines(scope), do: ["", "Path scope:" | Enum.map(scope, &"- #{&1}")]

  # Typed upstream receipt edges from the log: the latest ALIVE event of each
  # upstream. Frontier eligibility already implies they exist; this refuses,
  # rather than invents, if the log and the graph disagree.
  defp dependencies(admitted, events, prefix) do
    admitted["dependencies"]
    |> Enum.map(&stringify/1)
    |> Enum.uniq_by(& &1["upstream"])
    |> Enum.reduce_while({:ok, []}, fn dep, {:ok, acc} ->
      case dependency(dep, events, prefix) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp dependency(dep, events, prefix) do
    upstream = dep["upstream"]
    required = dep["required_standing"]

    alive =
      events
      |> Enum.map(&stringify/1)
      |> Enum.filter(&(&1["identity"] == upstream and &1["to"] == "ALIVE"))
      |> List.last()

    cond do
      required not in [nil, "ALIVE"] ->
        refuse({:unsupported_required_standing, upstream, required})

      is_nil(alive) ->
        refuse({:dependency_not_alive, upstream})

      true ->
        {:ok,
         %{
           "work_order_iri" => prefix <> upstream,
           "required_standing" => "ALIVE",
           "observed_standing" => "ALIVE",
           "receipt_iri" => @receipt_prefix <> alive["receipt_digest"],
           "receipt_digest" => alive["receipt_digest"]
         }}
    end
  end

  # The court map is upstream data; every IRI it binds must belong to THIS work
  # order (foreign IRIs are refused, never trimmed), then the fabric's own
  # `CourtReceipt.admit/1` (run inside `SemanticWork.admit/1`) checks its shape.
  defp court_map(nil, _admitted), do: {:ok, nil}

  defp court_map(%{} = raw, admitted) do
    map = stringify(raw)

    with :ok <- belongs(Map.keys(map["acceptance"] || %{}), admitted["acceptance"], "acceptance"),
         :ok <- belongs(Map.keys(map["falsifiers"] || %{}), admitted["falsifiers"], "falsifiers"),
         :ok <- belongs(map["courts"] || [], admitted["required_courts"], "courts") do
      {:ok, map}
    end
  end

  defp court_map(_other, _admitted), do: refuse({:court_map, :not_a_map})

  defp belongs(iris, allowed, kind) do
    case Enum.reject(iris, &(&1 in allowed)) do
      [] -> :ok
      foreign -> refuse({:court_map, {:foreign_iri, kind, foreign}})
    end
  end

  defp work_admit(execution) do
    case SemanticWork.admit(execution) do
      {:ok, _admitted} -> :ok
      {:error, reason} -> refuse({:not_xaas_admissible, reason})
    end
  end

  # ------------------------------------------------------------------
  # Receipt internals
  # ------------------------------------------------------------------

  defp bridge_of(export, admitted) do
    bridge = export["bridge"]

    cond do
      not is_map(bridge) ->
        refuse({:bridge_invalid, ["bridge"]})

      (missing = Enum.reject(@bridge_keys, &Map.has_key?(bridge, &1))) != [] ->
        refuse({:bridge_invalid, missing})

      bridge["identity"] != admitted["identity"] ->
        refuse(:bridge_identity_mismatch)

      true ->
        {:ok, bridge}
    end
  end

  defp digest_ok(export) do
    if is_binary(export["receipt_digest"]) and Regex.match?(@digest, export["receipt_digest"]) do
      case export_digest(export) do
        {:ok, digest} -> ensure(digest == export["receipt_digest"], :receipt_digest_mismatch)
        :error -> refuse(:export_not_json)
      end
    else
      refuse(:invalid_receipt_digest)
    end
  end

  # An export is JSON by contract; a term JSON cannot carry has no digest.
  defp export_digest(export) do
    {:ok, SemanticReceipt.receipt_digest(export)}
  rescue
    _error in [Jason.EncodeError, Protocol.UndefinedError] -> :error
  end

  # A digest-valid export can still be the wrong shape (a forger recomputes the
  # digest). Every container the mapping walks must be the container it expects,
  # so a wrong type is a typed refusal here instead of an exception downstream.
  defp shape_ok(export) do
    verifier = export["fabric_verifier"]

    cond do
      not is_map(verifier) ->
        malformed(["fabric_verifier"])

      not (is_nil(verifier["status"]) or is_binary(verifier["status"])) ->
        malformed(["fabric_verifier", "status"])

      not (is_nil(verifier["steps"]) or
               (is_list(verifier["steps"]) and Enum.all?(verifier["steps"], &is_map/1))) ->
        malformed(["fabric_verifier", "steps"])

      true ->
        court_shape(verifier["court_receipt"])
    end
  end

  defp court_shape(nil), do: :ok

  defp court_shape(%{} = court) do
    path = ["fabric_verifier", "court_receipt"]

    maps = ~w(binding acceptance_results falsifier_results court_results)
    bad = Enum.find(maps, &(not (is_nil(court[&1]) or is_map(court[&1]))))

    cond do
      bad != nil ->
        malformed(path ++ [bad])

      not (is_nil(court["court_results"]) or
               Enum.all?(Map.values(court["court_results"]), &is_map/1)) ->
        malformed(path ++ ["court_results"])

      not (is_nil(court["evidence_types"]) or is_list(court["evidence_types"])) ->
        malformed(path ++ ["evidence_types"])

      true ->
        :ok
    end
  end

  defp court_shape(_other), do: malformed(["fabric_verifier", "court_receipt"])

  defp malformed(path), do: refuse({:malformed_export, path})

  defp target(outcome) do
    case Map.fetch(@outcomes, outcome) do
      {:ok, target} -> {:ok, target}
      :error -> refuse({:unsupported_outcome, outcome})
    end
  end

  defp alive_guards(export, "ALIVE") do
    with :ok <- ensure(export["head_verified"] == true, :alive_without_head_verification) do
      ensure(verifier_status(export) == "pass", :alive_without_verifier_pass)
    end
  end

  defp alive_guards(_export, _target), do: :ok

  defp mapped_receipt(export, admitted, bridge, target) do
    passed = verifier_status(export) == "pass"
    court = court_receipt(export)
    credible = credible?(court, export)
    courts = court_results(export, court, admitted["required_courts"], passed)

    %{
      "definition_digest" => bridge["definition_digest"],
      "snapshot_digest" => bridge["snapshot_digest"],
      "target" => target,
      "candidate_sha" => export["final_head"],
      "evidence" => %{
        "subject" => bridge["subject"],
        "repository" => bridge["repository"],
        "base_sha" => bridge["base_sha"],
        "court_results" => courts,
        "evidence_types" => evidence_types(export, court, passed, admitted, courts),
        "acceptance_results" =>
          Map.new(
            admitted["acceptance"],
            &{&1, passed and credible and get_in(court, ["acceptance_results", &1]) == true}
          ),
        "falsifier_results" =>
          Map.new(admitted["falsifiers"], &{&1, falsifier_verdict(court, &1, passed, credible)}),
        "receipt_classes" => if(passed, do: ["verification"], else: []),
        "evidence_ceiling" => @fabric_ceiling,
        "observed_execution" => passed and export["outcome"] == "alive",
        "inherited_standing" => false
      },
      "xaas" => Map.take(export, ~w(epoch_id run_id receipt_id receipt_digest))
    }
  end

  defp verifier_status(export), do: get_in(export, ["fabric_verifier", "status"])

  defp court_receipt(export) do
    case get_in(export, ["fabric_verifier", "court_receipt"]) do
      %{} = court -> court
      _ -> %{}
    end
  end

  # A produced court receipt names the head it judged and the step that judged
  # it: credit its verdicts only when that is the sealed head and a step of this
  # export that passed. A legacy adapter receipt has no binding.
  defp credible?(court, export) do
    case court["binding"] do
      nil ->
        true

      %{"head" => head, "step_id" => step_id} ->
        head == export["final_head"] and step_passed?(export, step_id)

      _ ->
        false
    end
  end

  defp step_passed?(export, step_id) do
    export
    |> get_in(["fabric_verifier", "steps"])
    |> List.wrap()
    |> Enum.any?(&(&1["id"] == step_id and &1["status"] == "pass"))
  end

  # A required court is witnessed by the fabric's own step: a step whose id IS
  # the court IRI passed, or the produced court receipt binds the court to a
  # passing step of THIS export at the sealed head.
  defp court_results(export, court, required_courts, passed) do
    steps = get_in(export, ["fabric_verifier", "steps"]) || []

    Map.new(required_courts, fn iri ->
      step_passed = Enum.any?(steps, &(is_map(&1) and &1["id"] == iri and &1["status"] == "pass"))
      {iri, %{"passed" => passed and (step_passed or bound_court?(court, iri, steps, export))}}
    end)
  end

  defp bound_court?(court, iri, steps, export) do
    case get_in(court, ["court_results", iri]) do
      %{"passed" => true, "step_id" => step_id, "head" => head} when is_binary(step_id) ->
        head == export["final_head"] and
          Enum.any?(steps, &(is_map(&1) and &1["id"] == step_id and &1["status"] == "pass"))

      _ ->
        false
    end
  end

  # Witnessing EVERY required court is what elevates the fabric's execution and
  # sealed receipt into the work order's own evidence classes.
  defp evidence_types(export, court, passed, admitted, courts) do
    declared = strings(court["evidence_types"])

    witnessed =
      if courts != %{} and Enum.all?(Map.values(courts), &(&1["passed"] == true)),
        do: admitted["required_evidence"],
        else: []

    derived =
      if(passed, do: ["verification"], else: []) ++
        if passed and export["head_verified"] == true, do: ["exact_head_verification"], else: []

    Enum.uniq(declared ++ witnessed ++ derived) |> Enum.sort()
  end

  defp falsifier_verdict(court, falsifier, passed, credible) do
    observed = get_in(court, ["falsifier_results", falsifier])

    cond do
      not (passed and credible) -> "unobserved"
      observed in ["survived", true] -> "survived"
      observed in ["killed", "failed", false] -> "killed"
      true -> "unobserved"
    end
  end

  defp fabric_check(export, opts) do
    cond do
      not Keyword.get(opts, :fabric_check, true) ->
        :ok

      not is_binary(export["epoch_id"]) ->
        refuse({:malformed_export, ["epoch_id"]})

      true ->
        case SemanticReceipt.export(export["epoch_id"]) do
          {:ok, sealed} ->
            ensure(sealed == stringify(export), :export_not_sealed_by_fabric)

          {:error, reason} ->
            refuse({:no_sealed_receipt, reason})
        end
    end
  end

  # Only work the frontier currently lists may take a NEW transition; the exact
  # replay of a receipt already in the log is idempotent and passes through.
  defp on_frontier_or_recorded(work_orders, identity, receipt, events) do
    digest = SemanticJira.digest(receipt)

    if Enum.any?(events, &(&1["receipt_digest"] == digest)) do
      :ok
    else
      front = SemanticJira.frontier_from_events(work_orders, events)

      cond do
        Enum.any?(front.eligible, &(&1["identity"] == identity)) ->
          :ok

        blocked = Enum.find(front.blocked, &(&1["identity"] == identity)) ->
          refuse({:not_on_frontier, blocked["reason"]})

        true ->
          refuse(:unknown_work_order)
      end
    end
  end

  # The log is safe under concurrent writers, but the ADMISSION decision is
  # check-then-append: two different receipts racing for one work order would
  # both pass the frontier check and both append. `:global.trans` orders the
  # admissions of one node; `LogLock` (an flock held by a helper process) orders
  # them across OS processes, and is released by the kernel if its holder dies.
  defp serialized(log_dir, fun) do
    result =
      :global.trans(
        {{__MODULE__, Path.expand(log_dir)}, self()},
        fn -> LogLock.with_lock(log_dir, fun) end,
        [node()],
        :infinity
      )

    case result do
      {:ok, inner} -> inner
      {:error, reason} -> refuse({:log_lock, reason})
    end
  end

  # What the log answers is checked against what was asked: a nil event is a
  # claimed-but-never-written digest (a writer died mid-append), and an event
  # that cites another receipt is another admission's transition, not this one.
  defp reconcile(work_order, receipt, log_dir) do
    case Reconciler.reconcile(work_order, receipt, log_dir) do
      {:ok, event, disposition} -> acknowledged(event, disposition, receipt)
      {:error, {:refused, reason}} -> refuse(reason)
      {:error, other} -> refuse({:reconciler, json_safe(other)})
    end
  end

  @doc false
  # Pure: what `Reconciler.reconcile/4` answered, checked against the `receipt`
  # that was submitted. Public only so its refusals can be exercised on their own.
  @spec acknowledged(map() | nil, atom(), map()) :: {:ok, map(), atom()} | refusal()
  def acknowledged(nil, _disposition, receipt),
    do: refuse({:log_claim_orphaned, SemanticJira.digest(receipt)})

  def acknowledged(%{} = event, disposition, receipt) do
    submitted = SemanticJira.digest(receipt)

    cond do
      event["receipt_digest"] != submitted ->
        refuse(
          {:receipt_not_recorded,
           %{"submitted" => submitted, "recorded" => event["receipt_digest"]}}
        )

      not derives?(event) ->
        refuse(
          {:log_untrusted, %{"seq" => event["seq"], "event_digest" => event["event_digest"]}}
        )

      true ->
        {:ok, event, disposition}
    end
  end

  # ------------------------------------------------------------------
  # Log trust
  # ------------------------------------------------------------------

  # The events of `log_dir`, only if the log verifies: every event re-derives its
  # `event_digest` from its own content, and each work order's standing chain is
  # unbroken (an event's `from` is the previous event's `to`). A log that does
  # not verify is not read as data: nothing over it is eligible, promoted or
  # described.
  defp verified_events(log_dir) do
    events = TransitionLog.read(log_dir)

    with :ok <- events_derive(events),
         :ok <- events_chain(events) do
      {:ok, events}
    else
      {:error, detail} -> refuse({:log_untrusted, detail})
    end
  rescue
    error in [Jason.DecodeError, File.Error] ->
      refuse({:log_untrusted, %{"unreadable" => Exception.message(error)}})
  end

  defp events_derive(events) do
    case Enum.find(events, &(not derives?(&1))) do
      nil -> :ok
      %{} = bad -> {:error, %{"seq" => bad["seq"], "event_digest" => bad["event_digest"]}}
      _not_an_event -> {:error, %{"unreadable" => "not an event"}}
    end
  end

  # Current rule first; logs written before `event_digest` committed to the cited
  # receipt verify under the legacy rule.
  defp derives?(%{"event_digest" => digest} = event) when is_binary(digest) do
    digest in [TransitionLog.event_digest(event), TransitionLog.legacy_event_digest(event)]
  end

  defp derives?(_event), do: false

  defp events_chain(events) do
    events
    |> Enum.reduce_while(%{}, fn event, last ->
      identity = event["identity"]

      if Map.has_key?(last, identity) and last[identity] != event["from"] do
        {:halt, {:error, %{"discontinuous" => identity, "seq" => event["seq"]}}}
      else
        {:cont, Map.put(last, identity, event["to"])}
      end
    end)
    |> case do
      {:error, _detail} = error -> error
      _chain -> :ok
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp json_safe(value) when is_map(value) and not is_struct(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), json_safe(item)} end)

  defp json_safe(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_safe()
  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)

  defp json_safe(value) when is_boolean(value) or is_nil(value) or is_number(value),
    do: value

  defp json_safe(value) when is_binary(value), do: value
  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value), do: inspect(value)

  defp kernel(work_order) do
    case SemanticJira.admit_work_order(work_order) do
      {:ok, admitted} -> {:ok, admitted}
      {:error, {:refused_work_order, reason}} -> refuse({:unadmitted, reason})
      {:error, reason} -> refuse({:unadmitted, reason})
    end
  end

  defp shacl(_work_order, nil), do: :ok

  defp shacl(work_order, %RDF.Graph{} = shapes) do
    case Shacl.validate(candidate_graph(work_order), shapes) do
      %Shacl{conforms: true} -> :ok
      %Shacl{violations: violations} -> refuse({:shacl, violations})
    end
  end

  defp find(work_orders, identity) do
    case Enum.find(work_orders, &(stringify(&1)["identity"] == identity)) do
      nil -> refuse(:unknown_work_order)
      work_order -> {:ok, work_order}
    end
  end

  defp required_option(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> refuse({:missing_option, key})
    end
  end

  defp digest_option(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) ->
        if Regex.match?(@digest, value), do: {:ok, value}, else: refuse({:invalid_option, key})

      _ ->
        refuse({:missing_option, key})
    end
  end

  defp ledger_tail([]), do: @zero_digest
  defp ledger_tail(events), do: events |> List.last() |> Map.fetch!("event_digest")

  defp sha?(value), do: is_binary(value) and Regex.match?(@sha, value)

  defp ensure(true, _reason), do: :ok
  defp ensure(_, reason), do: refuse(reason)

  defp refuse(reason), do: {:error, {:refused_bridge, reason}}

  defp put_unless_nil(map, _key, nil), do: map
  defp put_unless_nil(map, key, value), do: Map.put(map, key, value)

  defp strings(list) when is_list(list), do: Enum.filter(list, &is_binary/1)
  defp strings(_), do: []

  defp stringify(value) when is_map(value) and not is_struct(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), stringify(item)} end)

  defp stringify(value) when is_list(value), do: Enum.map(value, &stringify/1)
  defp stringify(value), do: value
end
