defmodule Xaas.Ultracode.OcelEgress do
  @moduledoc """
  OCEL 2.0 egress for Ultracode: derives a standards-conformant
  object-centric event log (one JSON document per `Run`) from the
  persisted Ultracode state, for the operator's process-mining
  validation path ("the operator validates Ultracode's results through
  OCEL v2").

  The emitted document is plain OCEL 2.0 JSON -- exactly the four
  top-level keys `ocel:objectTypes`, `ocel:eventTypes`, `ocel:events`,
  `ocel:objects` -- no private dialect, no envelope. This is
  deliberately NOT the `Xaas.Telemetry.OcelForwarder` ex4pm envelope
  (`schema`/`producer`/`sequence`/`events`); see
  `docs/claude/diataxis/explanation/ocel-egress-forwarder.md` for that
  separate, network-facing path. The two share egress intent only.

  ## Hook point: DERIVATION, not a live callback

  Run state is fully persisted (`Run`/`Epoch`/`Receipt` are real
  AshPostgres resources), so the log is DERIVED from persisted rows at
  export time. Three reasons, in order of weight:

    1. `Lease`'s claim/close/refuse writes deliberately bypass Ash's
       changeset pipeline (`atomic_row_update/2` is a raw
       `Xaas.Repo.update_all` -- its own doc records that the resource
       carries no notifiers/`after_action` hooks to lose by doing so).
       A telemetry/notifier callback would silently MISS the most
       important events of the provider-pull flow; a derivation cannot.
    2. The loop core stays untouched (zero new call sites inside
       `Lease`/`NextEpoch`/`Autonomic`).
    3. A derivation is deterministic and re-runnable: the same rows
       always produce byte-identical output (see determinism guarantees
       below), which is what a validating court wants.

  Entry points:

    * `derive_run/1` -- build the document map for one Run (struct or id).
    * `derive_all/0` -- every Run, oldest first.
    * `write_document/2` -- encode + write one document to a path.
    * `export_run/2` / `export_all/1` -- derive + write, used by
      `mix xaas.ultracode.export_ocel` (default output dir
      `priv/ocel/ultracode`, matching the existing `priv/ocel/`
      convention used by `Xaas.Telemetry.OcelAshEmitter`).

  ## Object model (what the code actually persists)

    * `Run` -- `Xaas.Ultracode.Run` row (id = the row's UUID).
    * `Epoch` -- `Xaas.Ultracode.Epoch` row; object-to-object
      relationship to its Run.
    * `Worker` -- the lease holder (`Epoch.leased_to`, a free-form
      provider worker identity -- `Lease` owns no resource of its own,
      so the worker is derived from the lease fields). One object per
      distinct `leased_to` value, with relationships to each Epoch it
      leased.
    * `Receipt` -- `Xaas.Ultracode.Receipt` row; relationship to its
      Epoch.
    * `Worktree` -- `Epoch.worktree` (a filesystem path as object id).
      No resource exists for worktrees (`Xaas.Ultracode.Worktrees` is a
      module, not a schema), so this object type is derived from the
      path attribute alone.
    * `Repo` -- the execution repository alias (`Run.execution_repo_alias`
      today; a per-Epoch alias if sibling waves add one), CONDITIONALLY:
      a run whose rows carry no alias emits no `Repo` object and does not
      declare the type at all (see "Multi-repo legibility" below).

  `Epoch.lease_token` is deliberately NOT exported anywhere in the log:
  it is a live capability, and an audit log is not a capability store.

  ## Multi-repo legibility (the `Repo` object type)

  A multi-repo campaign must be legible per repository: every epoch and
  receipt names the repo it executed against, and the results-validation
  law (`Xaas.Ultracode.RunValidation`'s `:per_repo_capacity` option) can
  then judge capacity PER REPO. The egress contributes:

    * one `Repo` object per distinct alias (object id = the alias string,
      the same operator-local `Worktrees` lookup key);
    * an `execution_repo_alias` attribute on the `Run` object (the row's
      own fact) and on each `Epoch` object that carries its OWN alias;
    * a `repo`-qualified relationship (qualifier = type lowercased, the
      one deterministic rule) on the Run's events, and on every
      Epoch/Receipt event -- each epoch binds the repo it actually ran
      against: its own alias when it has one, otherwise the Run's.

  The alias fact is resolved through ONE seam, `own_alias/1` below: a
  struct that has a non-nil `execution_repo_alias` exposes it; a struct
  without the key (today's `Epoch`) resolves to nil, so the single-repo
  path is unchanged. COUPLING: if the sibling waves (registry/planner)
  land the per-Epoch alias under a different name, THIS function is the
  one place to extend.

  Declaration is conditional by law: `Repo` is declared in
  `ocel:objectTypes` exactly when at least one `Repo` object is emitted.
  Every other type stays ALWAYS-declared (the original rule), but an
  unconditional sixth declaration would change every legacy single-repo
  log's byte shape -- breaking the pinned legacy skeleton and every
  archived single-repo log's stability for a fact those logs do not
  carry. Declared-iff-emitted for `Repo` keeps both shapes spec-exact
  (the court only requires emitted types to be declared, never the
  converse) and byte-stable per shape.

  ## Event model (mapping table: law -> code)

  Every emitted event's time is a REAL persisted timestamp -- never a
  reconstructed or defaulted one. An event whose moment is not persisted
  is declared (below) but not emitted, rather than fabricated:

    | event type            | emitted when                     | time source                          |
    |-----------------------|----------------------------------|--------------------------------------|
    | `run_started`         | `Run.started_at` present         | `Run.started_at` (`:start` action)   |
    | `run_completed`       | `Run.state == :completed`        | `Run.terminal_at` (a)                |
    | `run_failed`          | `Run.state == :failed`           | `Run.terminal_at` (a)                |
    | `run_abandoned`       | `Run.state == :abandoned`        | `Run.terminal_at` (a)                |
    | `epoch_scheduled`     | every Epoch                      | `Epoch.expected_at` || `inserted_at` |
    | `epoch_started`       | `Epoch.started_at` present       | `Epoch.started_at` (`:start` action) |
    | `epoch_claimed`       | `Epoch.claimed_at` present       | `Epoch.claimed_at` (c)               |
    | `worker_heartbeat`    | `Epoch.last_heartbeat_at` present | `Epoch.last_heartbeat_at` (d)       |
    | `epoch_completed`     | `Epoch.state == :completed`      | `Epoch.completed_at` (`:complete`)   |
    | `epoch_missed`        | `Epoch.state == :missed`         | `Epoch.terminal_at` (a)              |
    | `epoch_failed`        | `Epoch.state == :failed`         | `Epoch.terminal_at` (a)              |
    | `receipt_closed`      | every sealed Receipt EXCEPT the heartbeat class (b2) | `Receipt.sealed_at` (`:seal`)        |
    | `heartbeat_recorded`  | `Receipt.outcome == :heartbeat`  | `Receipt.sealed_at` (`EpochReactor`) |
    | `verification_passed` | evidence `fabric_verifier.status == "pass"` | `Receipt.sealed_at` (b)   |
    | `verification_failed` | evidence `fabric_verifier.status == "fail"` | `Receipt.sealed_at` (b)   |
    | `refused`             | `Receipt.outcome == :refused`    | `Receipt.sealed_at` (`Lease.refuse/3`)|

    (a) Terminal-transition moments ARE stored in dedicated columns:
    `Run.terminal_at` (written by the `:transition_state`/`:stop` actions
    through `Xaas.Ultracode.Changes.SetTerminalAt`) and `Epoch.terminal_at`
    (written by `:mark_missed`/`:mark_failed` and `Lease.refuse/3`'s
    atomic `state: :failed` write). This replaced an earlier disclosed
    approximation that used the row's `updated_at`. A terminal row whose
    column is still NULL (rows predating the column, or a hypothetical
    writer that bypassed the transitions) emits NO event -- the fallback
    is nothing, never a fabricated or defaulted time.
    (b) The fabric verifier runs inside `Lease.close/4` immediately
    before the receipt is sealed, so the receipt's own `sealed_at` is
    the persisted moment of that verification.
    (c) `Lease.claim_next/3`'s atomic bind persists `claimed_at` in the
    SAME single `UPDATE ... WHERE ... RETURNING *` that binds
    `lease_token`/`leased_to`/`lease_expires_at` (atomicity preserved).
    A re-claim of an expired lease overwrites the column, so the emitted
    event carries the LATEST claim's moment.
    (d) `Lease.renew/1`'s atomic write persists `last_heartbeat_at`
    alongside the extended TTL. Column-level persistence keeps only the
    LATEST heartbeat per epoch, so N renewals collapse into ONE emitted
    event carrying the latest moment -- a disclosed collapse of history,
    not a loss of the newest fact.
    (b2) Receipt-vocabulary law: `:heartbeat` is the typed NON-STANDING
    tick class (`Xaas.Ultracode.Receipt`'s moduledoc). A heartbeat
    receipt is a real persisted fact, so it is emitted -- as its own
    `heartbeat_recorded` event type, carrying only `outcome`, `subject`
    and `action_taken` -- and NEVER as a `receipt_closed` or with a
    verification/refused sibling: manufacturing standing events from
    tick/liveness records is exactly what the class law forbids.

  Deliberately NOT in the vocabulary at all: `wave_scheduled` -- the
  `:autonomic_wave` AshOban schedule is a repo-level loop (it is not a
  fact about any `Run` row), so there is no per-Run wave fact to model.
  The per-Run scheduling fact this code actually has is an Epoch being
  created `:expected`, modeled as `epoch_scheduled`.

  ## Determinism

  * Event list is sorted by `{time, id}`; object list is sorted by a
    fixed type rank then id; relationship lists are sorted by
    `objectId`; object ids are the domain's own identifiers (row UUIDs,
    the `leased_to` string, the worktree path), never generated at
    export time.
  * Event ids are deterministic functions of the source row
    (`"<type>:<row-uuid>"`), so re-deriving the same rows yields the
    same ids.
  * Encoding uses Elixir's built-in `JSON` (verified on this repo's
    pinned toolchain, elixir 1.20.2-otp-28: map keys encode in sorted
    order and repeated encodes of one value are byte-identical). No
    timestamps-of-derivation, no map-iteration-order dependence, zero
    new dependencies.
  """

  alias Xaas.Ultracode.{Epoch, Receipt, Run}

  require Ash.Query

  # Fixed declaration order (deterministic document skeleton). All five
  # base object types and all sixteen event types are ALWAYS declared,
  # even when a given run's log contains zero instances of one -- declared
  # vocabulary is the code's real event surface, emitted instances are
  # only the facts persistence can prove (see the moduledoc mapping
  # table). The ONE exception is `Repo`: declared iff emitted (a legacy
  # single-repo log must keep its exact five-type shape -- see the
  # moduledoc's "Multi-repo legibility" section).
  @object_types ["Run", "Epoch", "Worker", "Receipt", "Worktree"]
  @repo_type "Repo"

  @event_types [
    "run_started",
    "epoch_scheduled",
    "epoch_started",
    "epoch_claimed",
    "worker_heartbeat",
    "epoch_completed",
    "epoch_missed",
    "epoch_failed",
    "receipt_closed",
    "heartbeat_recorded",
    "verification_passed",
    "verification_failed",
    "refused",
    "run_completed",
    "run_failed",
    "run_abandoned"
  ]

  # Object list ordering rank -- Run before its Epochs before the
  # Workers that leased them before the Receipts that closed them.
  @object_type_rank %{
    "Run" => 0,
    "Epoch" => 1,
    "Worker" => 2,
    "Receipt" => 3,
    "Worktree" => 4,
    "Repo" => 5
  }

  @default_out_dir "priv/ocel/ultracode"

  # Qualifier rule: the qualifier of ANY relationship (event-to-object
  # or object-to-object) is the referenced object's type, lowercased.
  # One deterministic rule, trivially checkable by a validator.

  # --------------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------------

  @doc """
  Derives the OCEL 2.0 document map for one Run (an `%Xaas.Ultracode.Run{}`
  struct or a Run id string). Loads the Run's Epochs and their sealed
  Receipts through the lawful `:read_unscoped` / `:for_epoch` actions.
  """
  @spec derive_run(Run.t() | String.t()) :: {:ok, map()} | {:error, :run_not_found}
  def derive_run(%Run{} = run) do
    {:ok, epochs} = load_epochs(run.id)
    receipts_by_epoch = Map.new(epochs, fn epoch -> {epoch.id, load_receipts!(epoch.id)} end)
    {:ok, build_document(run, epochs, receipts_by_epoch)}
  end

  def derive_run(run_id) when is_binary(run_id) do
    case Ash.read_one(run_query(run_id)) do
      {:ok, %Run{} = run} -> derive_run(run)
      {:ok, nil} -> {:error, :run_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Derives documents for every Run, oldest first (`derive_run/1` semantics
  per row).
  """
  @spec derive_all() :: {:ok, [map()]}
  def derive_all do
    {:ok, runs} =
      Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.sort(inserted_at: :asc, id: :asc)
      |> Ash.read()

    {:ok, Enum.map(runs, fn run -> elem(derive_run(run), 1) end)}
  end

  @doc """
  Pure core: builds the OCEL 2.0 document from already-loaded rows. No IO,
  no clock, no DB -- the function the golden structure tests pin exactly.
  `receipts_by_epoch` maps `epoch.id` to that epoch's sealed Receipts.
  """
  @spec build_document(Run.t(), [Epoch.t()], %{String.t() => [Receipt.t()]}) :: map()
  def build_document(%Run{} = run, epochs, receipts_by_epoch)
      when is_list(epochs) and is_map(receipts_by_epoch) do
    epochs = Enum.sort_by(epochs, &{&1.cycle, &1.id})
    run_alias = own_alias(run)
    repo_alias? = run_alias != nil or Enum.any?(epochs, &(own_alias(&1) != nil))

    declared_object_types =
      if repo_alias?, do: @object_types ++ [@repo_type], else: @object_types

    %{
      "ocel:objectTypes" => Enum.map(declared_object_types, fn name -> %{"name" => name} end),
      "ocel:eventTypes" => Enum.map(@event_types, fn name -> %{"name" => name} end),
      "ocel:events" =>
        (run_events(run) ++
           epoch_events(run, epochs) ++ receipt_events(run, epochs, receipts_by_epoch))
        |> Enum.sort_by(&{&1["time"], &1["id"]}),
      "ocel:objects" =>
        (run_objects(run) ++
           epoch_objects(run, epochs) ++
           worker_objects(epochs) ++
           receipt_objects(epochs, receipts_by_epoch) ++
           worktree_objects(epochs) ++ repo_objects(run, run_alias, epochs))
        |> Enum.sort_by(&{@object_type_rank[&1["type"]], &1["id"]})
    }
  end

  @doc """
  Encodes a document deterministically (built-in `JSON`, sorted keys,
  trailing newline) and writes it to `path`.
  """
  @spec write_document(map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def write_document(document, path) when is_map(document) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, JSON.encode!(document) <> "\n") do
      {:ok, path}
    end
  end

  @doc """
  Derives one Run's log and writes it to
  `Path.join(out_dir, "<run_id>.ocel.json")`.
  """
  @spec export_run(Run.t() | String.t(), Path.t()) ::
          {:ok, Path.t()} | {:error, :run_not_found | term()}
  def export_run(run_or_id, out_dir \\ @default_out_dir)

  def export_run(%Run{} = run, out_dir), do: do_export(run, run.id, out_dir)

  def export_run(run_id, out_dir) when is_binary(run_id), do: do_export(run_id, run_id, out_dir)

  defp do_export(run_or_id, file_stem, out_dir) do
    with {:ok, document} <- derive_run(run_or_id),
         {:ok, path} <- write_document(document, Path.join(out_dir, "#{file_stem}.ocel.json")) do
      {:ok, path}
    end
  end

  @doc """
  Exports every Run's log into `out_dir`. Returns the list of written
  paths.
  """
  @spec export_all(Path.t()) :: {:ok, [Path.t()]} | {:error, term()}
  def export_all(out_dir \\ @default_out_dir) do
    with {:ok, runs} <-
           Run
           |> Ash.Query.for_read(:read_unscoped)
           |> Ash.Query.sort(inserted_at: :asc, id: :asc)
           |> Ash.read() do
      {:ok,
       Enum.map(runs, fn run ->
         {:ok, path} = export_run(run, out_dir)
         path
       end)}
    end
  end

  @doc """
  The registered object type names (fixed, deterministic order). With
  `repo_alias?` true (default false) the conditional `Repo` type is
  appended -- the exact declaration set `build_document/3` emits for a
  run whose rows carry an alias.
  """
  @spec object_types(repo_alias? :: boolean()) :: [String.t()]
  def object_types(repo_alias? \\ false)

  def object_types(false), do: @object_types
  def object_types(true), do: @object_types ++ [@repo_type]

  @doc "The registered event type names (fixed, deterministic order)."
  @spec event_types() :: [String.t()]
  def event_types, do: @event_types

  @doc "Default output directory for `export_run/2` / `export_all/1`."
  @spec default_out_dir() :: Path.t()
  def default_out_dir, do: @default_out_dir

  # --------------------------------------------------------------------------------
  # Run-level events + object
  # --------------------------------------------------------------------------------

  # Run lifecycle events carry no payload attributes: the state machine
  # facts are on the Run object; the event's existence + time is the fact.
  # The Run's own alias (when present) rides every run event as a
  # `repo`-qualified relationship.
  defp run_events(run) do
    context = [rel(run.id, "run")] ++ rel_opt_ctx(own_alias(run), "repo")

    Enum.concat([
      maybe_event("run_started", run.id, ts(run.started_at), %{}, context),
      terminal_run_event(run, :completed, context),
      terminal_run_event(run, :failed, context),
      terminal_run_event(run, :abandoned, context)
    ])
  end

  defp terminal_run_event(run, state, context) when state in [:completed, :failed, :abandoned] do
    if run.state == state do
      maybe_event(
        "run_#{state}",
        run.id,
        ts(run.terminal_at),
        %{},
        context
      )
    else
      []
    end
  end

  defp run_objects(run) do
    [
      %{
        "id" => run.id,
        "type" => "Run",
        "attributes" =>
          drop_nils(%{
            "goal" => run.goal,
            "provider" => run.provider,
            "verifier_suite" => run.verifier_suite,
            "org_id" => run.org_id,
            "execution_repo_alias" => own_alias(run),
            "state" => atom(run.state),
            "standing" => atom(run.standing),
            "cycle" => run.cycle,
            "max_cycles" => run.max_cycles,
            "epoch_timeout_seconds" => run.epoch_timeout_seconds,
            "started_at" => ts(run.started_at),
            "deadline_at" => ts(run.deadline_at),
            "terminal_at" => ts(run.terminal_at)
          }),
        "relationships" => []
      }
    ]
  end

  # --------------------------------------------------------------------------------
  # Epoch-level events + objects
  # --------------------------------------------------------------------------------

  defp epoch_events(run, epochs) do
    run_alias = own_alias(run)

    Enum.flat_map(epochs, fn epoch ->
      context =
        [
          rel(run.id, "run"),
          rel(epoch.id, "epoch"),
          rel_opt(epoch.worktree, "worktree")
        ] ++ rel_opt_ctx(effective_alias(epoch, run_alias), "repo")

      terminal =
        case atom(epoch.state) do
          "completed" ->
            maybe_event(
              "epoch_completed",
              epoch.id,
              ts(epoch.completed_at),
              epoch_attrs(epoch),
              lease_context(epoch, context)
            )

          "missed" ->
            maybe_event(
              "epoch_missed",
              epoch.id,
              ts(epoch.terminal_at),
              epoch_attrs(epoch),
              lease_context(epoch, context)
            )

          "failed" ->
            maybe_event(
              "epoch_failed",
              epoch.id,
              ts(epoch.terminal_at),
              epoch_attrs(epoch),
              lease_context(epoch, context)
            )

          _ ->
            []
        end

      Enum.concat([
        maybe_event(
          "epoch_scheduled",
          epoch.id,
          ts(epoch.expected_at) || ts(epoch.inserted_at),
          epoch_attrs(epoch),
          context
        ),
        maybe_event("epoch_started", epoch.id, ts(epoch.started_at), epoch_attrs(epoch), context),
        maybe_event(
          "epoch_claimed",
          epoch.id,
          ts(epoch.claimed_at),
          epoch_attrs(epoch),
          lease_context(epoch, context)
        ),
        maybe_event(
          "worker_heartbeat",
          epoch.id,
          ts(epoch.last_heartbeat_at),
          epoch_attrs(epoch),
          lease_context(epoch, context)
        ),
        terminal
      ])
    end)
  end

  defp epoch_attrs(epoch), do: %{"cycle" => epoch.cycle}

  defp epoch_objects(run, epochs) do
    run_alias = own_alias(run)

    Enum.map(epochs, fn epoch ->
      %{
        "id" => epoch.id,
        "type" => "Epoch",
        "attributes" =>
          drop_nils(%{
            "cycle" => epoch.cycle,
            "exact_subject" => epoch.exact_subject,
            "execution_repo_alias" => own_alias(epoch),
            "state" => atom(epoch.state),
            "expected_at" => ts(epoch.expected_at),
            "started_at" => ts(epoch.started_at),
            "completed_at" => ts(epoch.completed_at),
            "terminal_at" => ts(epoch.terminal_at),
            "lease_expires_at" => ts(epoch.lease_expires_at),
            "claimed_at" => ts(epoch.claimed_at),
            "last_heartbeat_at" => ts(epoch.last_heartbeat_at),
            "leased_to" => epoch.leased_to,
            "worktree" => epoch.worktree,
            "final_head" => epoch.final_head
          }),
        "relationships" =>
          ([rel(run.id, "run")] ++ rel_opt_ctx(effective_alias(epoch, run_alias), "repo"))
          |> Enum.sort_by(& &1["objectId"])
      }
    end)
  end

  # Worker relationships on events: only for events whose fact
  # co-occurred with the lease -- never `epoch_scheduled`/`epoch_started`
  # (both precede any possible claim; the lease requires a `:running`
  # epoch, i.e. one already past `:start`). `epoch_claimed` (the bind
  # itself) and `worker_heartbeat` (a renewal of it) DO carry the worker.
  defp lease_context(epoch, context) do
    case epoch.leased_to do
      nil -> context
      worker -> context ++ [rel(worker, "worker")]
    end
  end

  defp worker_objects(epochs) do
    epochs
    |> Enum.filter(& &1.leased_to)
    |> Enum.group_by(& &1.leased_to, & &1.id)
    |> Enum.map(fn {worker, epoch_ids} ->
      %{
        "id" => worker,
        "type" => "Worker",
        "attributes" => %{},
        "relationships" =>
          epoch_ids
          |> Enum.sort()
          |> Enum.uniq()
          |> Enum.map(&rel(&1, "epoch"))
      }
    end)
  end

  # --------------------------------------------------------------------------------
  # Receipt-level events + objects
  # --------------------------------------------------------------------------------

  defp receipt_events(run, epochs, receipts_by_epoch) do
    run_alias = own_alias(run)

    epochs
    |> Enum.flat_map(fn epoch ->
      context =
        [
          rel(run.id, "run"),
          rel(epoch.id, "epoch"),
          rel_opt(epoch.worktree, "worktree"),
          rel_opt(epoch.leased_to, "worker")
        ] ++ rel_opt_ctx(effective_alias(epoch, run_alias), "repo")

      receipts_by_epoch
      |> Map.get(epoch.id, [])
      |> Enum.flat_map(fn receipt ->
        if heartbeat_receipt?(receipt) do
          # Receipt-vocabulary law: a `:heartbeat` receipt is the typed
          # NON-STANDING tick class. It emits its OWN event type -- never a
          # `receipt_closed` (terminal standing evidence) and never a
          # verification/refused sibling (a heartbeat carries no court
          # verdict, and fabricating standing events from heartbeats is
          # exactly the pollution this class exists to end). RunValidation
          # deliberately does not know this type, so a heartbeat can never
          # satisfy a verified-terminal requirement.
          maybe_event(
            "heartbeat_recorded",
            receipt.id,
            ts(receipt.sealed_at),
            heartbeat_attrs(receipt),
            context ++ [rel(receipt.id, "receipt")]
          )
        else
          Enum.concat([
            maybe_event(
              "receipt_closed",
              receipt.id,
              ts(receipt.sealed_at),
              receipt_closed_attrs(receipt),
              context ++ [rel(receipt.id, "receipt")]
            ),
            verification_events(receipt, run, context),
            refusal_event(receipt, context)
          ])
        end
      end)
    end)
  end

  # The class test is the typed outcome atom -- never jsonb forensics over
  # evidence.
  defp heartbeat_receipt?(receipt), do: atom(receipt.outcome) == "heartbeat"

  defp heartbeat_attrs(receipt) do
    drop_nils(%{
      "outcome" => atom(receipt.outcome),
      "subject" => receipt.subject,
      "action_taken" => ev_key(evidence(receipt), "action_taken")
    })
  end

  defp verification_events(receipt, run, context) do
    case verifier_status(receipt) do
      nil ->
        []

      status when status in ["pass", "fail"] ->
        attrs = drop_nils(%{"verifier_suite" => run.verifier_suite, "verifier_status" => status})

        maybe_event(
          if(status == "pass", do: "verification_passed", else: "verification_failed"),
          receipt.id,
          ts(receipt.sealed_at),
          attrs,
          context ++ [rel(receipt.id, "receipt")]
        )

      # "timeout"/"error": the suite could not produce a verdict -- the
      # sealed outcome is the verdict (`:partial_alive`); recording a
      # "verification_failed" event would falsify what happened.
      _other ->
        []
    end
  end

  defp refusal_event(receipt, context) do
    if atom(receipt.outcome) == "refused" do
      maybe_event(
        "refused",
        receipt.id,
        ts(receipt.sealed_at),
        refusal_attrs(receipt),
        context ++ [rel(receipt.id, "receipt")]
      )
    else
      []
    end
  end

  defp receipt_closed_attrs(receipt) do
    evidence = evidence(receipt)

    drop_nils(%{
      "outcome" => atom(receipt.outcome),
      "subject" => receipt.subject,
      "head_verified" => ev_key(evidence, "head_verified"),
      "refusal_reason" => ev_key(evidence, "refusal_reason"),
      "verifier_status" => verifier_status(receipt),
      "observed_head" => ev_key(evidence, "observed_head"),
      "verifier_unavailable" => ev_key(evidence, "verifier_unavailable")
    })
  end

  defp refusal_attrs(receipt) do
    evidence = evidence(receipt)

    drop_nils(%{
      "outcome" => atom(receipt.outcome),
      "subject" => receipt.subject,
      "refusal_reason" => ev_key(evidence, "refusal_reason")
    })
  end

  defp receipt_objects(epochs, receipts_by_epoch) do
    epochs
    |> Enum.flat_map(&Map.get(receipts_by_epoch, &1.id, []))
    |> Enum.map(fn receipt ->
      %{
        "id" => receipt.id,
        "type" => "Receipt",
        "attributes" =>
          drop_nils(%{
            "subject" => receipt.subject,
            "outcome" => atom(receipt.outcome)
          }),
        "relationships" => [rel(receipt.epoch_id, "epoch")]
      }
    end)
  end

  defp worktree_objects(epochs) do
    epochs
    |> Enum.map(& &1.worktree)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn path ->
      %{"id" => path, "type" => "Worktree", "attributes" => %{}, "relationships" => []}
    end)
  end

  # One Repo object per distinct alias: the epoch effective aliases plus
  # the Run's own. Object id = the alias string (the operator-local
  # Worktrees lookup key -- the domain's own identifier, never generated
  # at export time). Each Repo relates back to the Run it was derived
  # from (always resolvable -- the Run object always exists). Emits
  # NOTHING when no row carries an alias: the legacy single-repo log
  # gains no Repo object and declares no Repo type.
  defp repo_objects(run, run_alias, epochs) do
    epochs
    |> Enum.map(&effective_alias(&1, run_alias))
    |> Kernel.++(List.wrap(run_alias))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn alias ->
      %{
        "id" => alias,
        "type" => "Repo",
        "attributes" => %{},
        "relationships" => [rel(run.id, "run")]
      }
    end)
  end

  # The repo an epoch's facts belong to: the epoch's OWN alias when its
  # row carries one (sibling waves may add a per-Epoch alias field for
  # multi-repo campaigns), otherwise the Run's. nil only when neither has
  # one -- the null-safe legacy path.
  defp effective_alias(epoch, run_alias), do: own_alias(epoch) || run_alias

  # THE alias seam. A struct that has a non-nil `execution_repo_alias`
  # string exposes it; a struct without the key (today's `Epoch`) fails
  # the match and resolves to nil -- no KeyError, no speculative field.
  # COUPLING: if the sibling waves land the per-Epoch alias under a
  # different attribute name, this is the one function to extend.
  defp own_alias(%{execution_repo_alias: alias}) when is_binary(alias), do: alias
  defp own_alias(_row), do: nil

  # Optional relationship as a context list (empty when the fact is
  # absent) -- keeps the event-context builders append-only.
  defp rel_opt_ctx(nil, _qualifier), do: []
  defp rel_opt_ctx(object_id, qualifier), do: [rel(object_id, qualifier)]

  # --------------------------------------------------------------------------------
  # Shared constructors
  # --------------------------------------------------------------------------------

  # An event whose moment is not persisted is NEVER emitted (see the
  # moduledoc mapping table) -- a nil time yields no event, never a
  # defaulted or fabricated one.
  defp maybe_event(_type, _row_id, nil, _attrs, _relationships), do: []

  defp maybe_event(type, row_id, time, attrs, relationships) do
    [
      %{
        "id" => "#{type}:#{row_id}",
        "type" => type,
        "time" => time,
        "attributes" => attrs,
        "relationships" =>
          relationships
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq_by(& &1["objectId"])
          |> Enum.sort_by(& &1["objectId"])
      }
    ]
  end

  defp rel(object_id, qualifier), do: %{"objectId" => object_id, "qualifier" => qualifier}
  defp rel_opt(nil, _qualifier), do: nil
  defp rel_opt(object_id, qualifier), do: rel(object_id, qualifier)

  # Timestamps: Ash's `:utc_datetime_usec` loads real UTC DateTimes; the
  # ISO8601 form ends in "Z". A nil timestamp yields nil -- callers emit
  # no event rather than fabricating a moment (see `maybe_event/5`).
  defp ts(nil), do: nil
  defp ts(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  # Evidence maps arrive with string keys from `Lease`, but Ash `:map`
  # attributes preserve whatever the writer used -- normalize atom keys
  # to strings so test fixtures and hand-sealed receipts behave
  # identically to production. Never `String.to_existing_atom/1` on
  # caller-shaped keys (the atom may not exist; that would raise).
  defp evidence(receipt), do: receipt.evidence || %{}

  defp normalize_keys(evidence) when is_map(evidence) do
    Map.new(evidence, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_keys(_evidence), do: %{}

  defp ev_key(evidence, key), do: Map.get(normalize_keys(evidence), key)

  defp verifier_status(receipt) do
    case ev_key(evidence(receipt), "fabric_verifier") do
      verifier when is_map(verifier) -> normalize_keys(verifier)["status"]
      _ -> nil
    end
  end

  defp atom(nil), do: nil
  defp atom(value) when is_atom(value), do: Atom.to_string(value)
  defp atom(value) when is_binary(value), do: value

  defp drop_nils(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()

  defp run_query(run_id) do
    Run
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(id == ^run_id)
  end

  defp load_epochs(run_id) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^run_id)
    |> Ash.Query.sort(cycle: :asc, id: :asc)
    |> Ash.read()
  end

  defp load_receipts!(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!()
  end
end
