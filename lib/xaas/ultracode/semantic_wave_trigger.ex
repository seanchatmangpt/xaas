defmodule Xaas.Ultracode.SemanticWaveTrigger do
  @moduledoc """
  Event-driven half of the semantic-wave clock (wave-6 law).

  Before this module, the ONLY thing that could start a semantic-wave
  dispatch was the `*/30` `:semantic_wave` cron on `Xaas.Ultracode.Run` --
  a freshly materialized `:autonomic_wave_attempt` epoch could wait up to
  30 minutes for its first dispatch attempt. The cron is now demoted to a
  WATCHDOG for missed events; THIS module is the primary clock:

    * `Xaas.Ultracode.SemanticWork.materialize/2` calls `enqueue/1` from
      inside its own `Xaas.Repo.transaction` the moment an admitted
      frontier transition becomes real (Run + first `:running` Epoch
      committed). The Oban job row therefore commits ATOMICALLY with the
      epoch it exists to dispatch -- a wave job can never exist without
      its work (transactional outbox; the "missed event" class is closed
      at creation, not patched over later), and if the job insert fails
      the whole materialization rolls back loudly instead of silently
      degrading to watchdog-only latency.

    * `enqueue/1` is BOUNDED and DEDUPLICATED: one admission event
      enqueues at most one wave job, and Oban-native uniqueness (worker +
      queue + `graph_digest` + `repository_identity`, over the incomplete
      job states) plus an explicit pending-job pre-check guarantees one
      pending wave per graph-digest/repository pair -- never a thundering
      herd, no matter how many descriptors for the same semantic head are
      admitted while a wave is already queued.

    * the enqueued `Worker` runs the SAME `:semantic_wave` generic action
      the cron worker runs, on the SAME single-slot `:ultracode_wave`
      queue (so event waves and watchdog waves can never overlap), with
      the SAME admitted `Xaas.SystemAuthority` service `:oban_scheduler`
      (`Xaas.Checks.SystemActor` exact-subject mapping). The trigger
      grants no new authority; it is a timing change, not an authority
      change. It still cannot select the frontier, lease, verify, or
      promote anything -- dispatch remains "not Lease admission".

  `:continuous_epoch_run` admissions are policy-gated out: the semantic
  wave's domain is `:autonomic_wave_attempt` epochs only (see
  `SemanticWave.ready_epochs/1`); continuous work keeps its tick-clock
  law unchanged.
  """

  alias Xaas.Ultracode.Run
  alias Xaas.SystemAuthority

  @queue :ultracode_wave
  # Oban's unique cast requires ATOM keys (it stringifies them itself when
  # hashing the args).
  @dedup_keys [:graph_digest, :repository_identity]

  # Oban's own `:incomplete` unique-state group (Oban.Job.unique_states/1)
  # -- a wave job in any of these states still owns the dedup slot. The
  # ATOM list feeds Oban's unique cast; the STRING list feeds the SQL
  # pre-check (oban_jobs.state is a string column).
  @pending_state_atoms ~w(suspended available scheduled executing retryable)a
  @pending_states ~w(suspended available scheduled executing retryable)
  @worker_string "Xaas.Ultracode.SemanticWaveTrigger.Worker"

  @unique [
    # One pending wave per {graph_digest, repository_identity} forever, as
    # long as the previous wave job is still in an incomplete state --
    # Oban computes the uniqueness token over exactly these arg keys.
    period: :infinity,
    states: @pending_state_atoms,
    keys: @dedup_keys
  ]

  defmodule Worker do
    @moduledoc """
    The event-path semantic-wave dispatch job: same action, same queue,
    same `:oban_scheduler` system authority as the `*/30` watchdog cron
    (`Xaas.Ultracode.Run.Workers.SemanticWave`), enqueued immediately on
    an admitted frontier transition instead of waiting for the cron.
    """

    # Uniqueness is supplied PER JOB by `SemanticWaveTrigger.enqueue/1`
    # (keys-scoped to the incomplete states) -- a worker-level unique here
    # would also cover completed jobs and wrongly block a legitimate
    # re-dispatch of the same semantic head after a prior wave finished.
    use Oban.Worker, queue: :ultracode_wave, max_attempts: 1

    @impl Oban.Worker
    def perform(_job), do: Xaas.Ultracode.SemanticWaveTrigger.dispatch_now()
  end

  @doc """
  Enqueues the immediate semantic-wave dispatch for one admitted descriptor.

  Called from `SemanticWork.materialize/2` inside its transaction (the
  enqueue joins that transaction -- see the moduledoc). Returns a receipt
  map describing exactly what happened:

    * `%{enqueued?: true, deduped?: false, job_id: id, ...}` -- the wave
      job was inserted and commits with the caller's transaction;
    * `%{enqueued?: false, deduped?: true, ...}` -- a pending wave for
      this graph_digest/repository pair already exists (pre-check); the
      pending job already covers this admission, so no second job;
    * `%{enqueued?: false, policy_gated?: true}` -- a
      `:continuous_epoch_run` admission; not the wave's domain.

  Any Oban insert failure returns `{:error, term}` so the caller's
  transaction rolls back (fail-closed: a lost immediate wave is never
  silently accepted).
  """
  @spec enqueue(descriptor :: map()) :: {:ok, map()} | {:error, term()}
  def enqueue(%{execution_policy: :autonomic_wave_attempt} = descriptor) do
    digest = Map.fetch!(descriptor, :graph_digest)
    repo_identity = Map.fetch!(descriptor, :repository_identity)

    if pending_wave?(digest, repo_identity) do
      {:ok,
       %{
         enqueued?: false,
         deduped?: true,
         policy_gated?: false,
         job_id: nil,
         graph_digest: digest,
         repository_identity: repo_identity
       }}
    else
      args = %{
        "graph_digest" => digest,
        "repository_identity" => repo_identity,
        "trigger" => "semantic_work_admitted"
      }

      case Oban.insert(Worker.new(args, unique: @unique)) do
        {:ok, %Oban.Job{} = job} ->
          {:ok,
           %{
             enqueued?: true,
             deduped?: job.conflict?,
             policy_gated?: false,
             job_id: job.id,
             graph_digest: digest,
             repository_identity: repo_identity
           }}

        {:error, reason} ->
          {:error, {:semantic_wave_enqueue_failed, reason}}
      end
    end
  end

  def enqueue(%{execution_policy: :continuous_epoch_run} = descriptor) do
    {:ok,
     %{
       enqueued?: false,
       deduped?: false,
       policy_gated?: true,
       job_id: nil,
       graph_digest: Map.fetch!(descriptor, :graph_digest),
       repository_identity: Map.fetch!(descriptor, :repository_identity)
     }}
  end

  def enqueue(_other), do: {:error, {:refused_semantic_wave_trigger, :not_a_descriptor}}

  @doc """
  The watchdog body: runs the Run `:semantic_wave` generic action through
  authorization with the `:oban_scheduler` system authority -- the exact
  call the cron worker's `default_actor` performs. Exposed as a function
  so the event-path worker and the cron worker provably run ONE dispatch
  law, not two.
  """
  @spec dispatch_now() :: {:ok, map()} | {:error, term()}
  def dispatch_now do
    actor = SystemAuthority.new(:oban_scheduler)

    Run
    |> Ash.ActionInput.for_action(:semantic_wave, %{}, actor: actor, authorize?: true)
    |> Ash.run_action()
    |> case do
      {:ok, report} -> {:ok, report}
      {:error, error} -> {:error, {:semantic_wave_dispatch_failed, error}}
    end
  end

  @doc """
  True when a wave job for this graph_digest/repository pair is already
  pending (not yet completed/discarded/cancelled). The explicit, legible
  half of the dedup law; Oban-native uniqueness is the race backstop.
  """
  @spec pending_wave?(String.t(), String.t()) :: boolean()
  def pending_wave?(digest, repo_identity) when is_binary(digest) and is_binary(repo_identity) do
    import Ecto.Query

    Xaas.Repo.exists?(
      from(j in Oban.Job,
        where: j.worker == ^@worker_string,
        where: j.queue == ^to_string(@queue),
        where: j.state in ^@pending_states,
        where: fragment("? ->> 'graph_digest'", j.args) == ^digest,
        where: fragment("? ->> 'repository_identity'", j.args) == ^repo_identity
      )
    )
  end

  @doc """
  Deletes every pending wave job for the pair -- the watchdog test's way
  of simulating a genuinely MISSED event insert (a lost/cancelled job),
  proving the cron watchdog catches what the event path dropped. Named
  and public so the simulation is explicit law, not an inline SQL trick.
  """
  @spec clear_pending_waves!(String.t(), String.t()) :: {integer(), nil}
  def clear_pending_waves!(digest, repo_identity) do
    import Ecto.Query

    Xaas.Repo.delete_all(
      from(j in Oban.Job,
        where: j.worker == ^@worker_string,
        where: j.queue == ^to_string(@queue),
        where: j.state in ^@pending_states,
        where: fragment("? ->> 'graph_digest'", j.args) == ^digest,
        where: fragment("? ->> 'repository_identity'", j.args) == ^repo_identity
      )
    )
  end
end
