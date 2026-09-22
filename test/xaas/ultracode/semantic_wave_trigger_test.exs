defmodule Xaas.Ultracode.SemanticWaveTriggerTest do
  # SemanticCase, not bare DataCase: the trigger law is exercised through
  # SemanticWork.materialize/2 (Xaas.Repo Ash resources + a transaction)
  # and the watchdog half runs the :semantic_wave action through the real
  # SemanticWave.ready_epochs query -- both need the scoped shared
  # Xaas.Repo sandbox owner the template establishes. The template also
  # pins the wave state dir to the fixture dir, so no test here can write
  # receipts outside it.
  use Xaas.Ultracode.SemanticCase, async: false

  alias Xaas.Ultracode.{SemanticWave, SemanticWaveTrigger, SemanticWork}

  import Ecto.Query

  @digest_a "sha256:" <> String.duplicate("a", 64)
  @digest_b "sha256:" <> String.duplicate("b", 64)
  @repo "seanchatmangpt/xaas"
  @worker "Xaas.Ultracode.SemanticWaveTrigger.Worker"

  setup %{state: state} do
    # The watchdog/worker tests fire the :semantic_wave action, whose
    # runner seam defaults to the REAL SemanticWave.run. Wrap it so the
    # dispatch worker is a capture (never the real dispatcher subprocess)
    # while every other part of the law stays real: ready_epochs sensing,
    # receipt writing into the fixture state dir, status computation.
    parent = self()

    Application.put_env(:xaas, :ultracode_semantic_wave_runner, fn opts ->
      worker = fn epoch, _ctx ->
        send(parent, {:semantic_wave_dispatched, epoch.id})
        :ok
      end

      SemanticWave.run(Keyword.merge(opts, worker: worker, state_dir: state))
    end)

    :ok
  end

  # -- the event path ---------------------------------------------------------

  test "an admitted frontier transition enqueues the wave dispatch immediately", %{sha: sha} do
    assert {:ok, %{run: run, epoch: epoch, wave: wave}} =
             SemanticWork.materialize(wave_descriptor(sha, @digest_a, "evt"), binding: :graph)

    # The transition completed: admitted descriptor -> running wave epoch.
    assert run.execution_policy == :autonomic_wave_attempt
    assert epoch.state == :running

    # ...and the wave job is ALREADY pending, committed with it.
    assert wave[:enqueued?] == true
    assert wave[:deduped?] == false
    assert wave[:job_id]

    job = Xaas.Repo.get!(Oban.Job, wave[:job_id])
    assert job.worker == @worker
    assert job.queue == "ultracode_wave"
    assert job.state in ["available", "scheduled", "executing", "retryable"]
    assert job.args["graph_digest"] == @digest_a
    assert job.args["repository_identity"] == @repo
    assert job.args["trigger"] == "semantic_work_admitted"
  end

  test "dedup: one pending wave per graph_digest/repository pair, never a herd", %{sha: sha} do
    assert {:ok, %{wave: first}} =
             SemanticWork.materialize(wave_descriptor(sha, @digest_a, "d1"), binding: :graph)

    # Same semantic head (digest+repo), a DIFFERENT work order: the pending
    # wave already covers it, so no second job.
    assert {:ok, %{wave: second}} =
             SemanticWork.materialize(wave_descriptor(sha, @digest_a, "d2"), binding: :graph)

    assert first[:enqueued?] == true
    assert second[:enqueued?] == false
    assert second[:deduped?] == true
    assert pending_wave_count() == 1

    # A different graph digest is a different frontier: its own wave.
    assert {:ok, %{wave: third}} =
             SemanticWork.materialize(wave_descriptor(sha, @digest_b, "d3"), binding: :graph)

    assert third[:enqueued?] == true
    assert pending_wave_count() == 2
  end

  test "concurrent enqueue attempts stay bounded to one pending wave per pair", %{sha: sha} do
    descriptor = wave_descriptor(sha, @digest_a, "race")

    results =
      1..4
      |> Task.async_stream(fn _ -> SemanticWaveTrigger.enqueue(descriptor) end,
        max_concurrency: 4,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    # Every attempt succeeds -- a dedup is a lawful success, not an error.
    assert Enum.all?(results, &match?({:ok, _}, &1))

    # At least one actually enqueued, and EXACTLY ONE wave job exists for
    # the pair afterwards: the pre-check plus Oban-native uniqueness
    # together bound concurrent admissions to one pending wave.
    assert Enum.any?(results, &match?({:ok, %{enqueued?: true}}, &1))
    assert pending_wave_count() == 1
  end

  test "policy gate: a continuous_epoch_run admission enqueues no wave", %{sha: sha} do
    assert {:ok, %{wave: wave}} =
             SemanticWork.materialize(
               %{
                 wave_descriptor(sha, @digest_a, "cont")
                 | execution_policy: :continuous_epoch_run
               },
               binding: :graph
             )

    assert wave[:enqueued?] == false
    assert wave[:policy_gated?] == true
    assert pending_wave_count() == 0
  end

  test "transactional outbox: a failed materialization leaves no wave job", %{sha: sha} do
    # Unregistered verifier suite -> the Run create fails inside the
    # transaction; the enqueue (which rides that same transaction) must
    # leave zero trace.
    input = %{wave_descriptor(sha, @digest_a, "boom") | verifier_suite: "not-registered"}

    assert {:error, _} = SemanticWork.materialize(input, binding: :graph)
    assert pending_wave_count() == 0
  end

  # -- the watchdog path ------------------------------------------------------

  test "the watchdog catches a simulated missed event insert and dispatches it", %{sha: sha} do
    assert {:ok, %{epoch: epoch}} =
             SemanticWork.materialize(wave_descriptor(sha, @digest_a, "missed"), binding: :graph)

    # The event happened, but its wave job was LOST (a genuinely missed
    # insert: a cancelled/crashed job) -- simulated through the trigger's
    # own explicit clear.
    assert {1, nil} = SemanticWaveTrigger.clear_pending_waves!(@digest_a, @repo)
    assert pending_wave_count() == 0

    # The watchdog fires the SAME action+authority the cron worker runs
    # (dispatch_now is the shared body; the generated cron worker reaches
    # it through the schedule's :oban_scheduler default_actor).
    assert {:ok, %{status: "DISPATCHED", receipt: receipt_path}} =
             SemanticWaveTrigger.dispatch_now()

    assert File.exists?(receipt_path)

    # The dispatch reached the missed epoch through the real
    # ready_epochs -> dispatch machinery (only the worker was captured).
    assert_receive {:semantic_wave_dispatched, epoch_id}
    assert epoch_id == epoch.id
  end

  test "the watchdog is a no-op when nothing wave-ready exists", %{sha: sha} do
    # A continuous-policy admission is not the wave's domain: nothing
    # wave-ready, nothing pending -- the watchdog must report IDLE and
    # dispatch nothing.
    assert {:ok, _} =
             SemanticWork.materialize(
               %{
                 wave_descriptor(sha, @digest_a, "idle")
                 | execution_policy: :continuous_epoch_run
               },
               binding: :graph
             )

    assert {:ok, %{status: "IDLE", receipt: receipt_path}} = SemanticWaveTrigger.dispatch_now()

    assert File.exists?(receipt_path)
    refute_receive {:semantic_wave_dispatched, _}
  end

  # -- the enqueued job's body ------------------------------------------------

  test "the enqueued trigger job dispatches the ready epoch when performed (public-API chain)",
       %{sha: sha} do
    # The ggen emitter contract end-to-end, in the sandbox: a STRING-keyed
    # descriptor using the documented "repository" alias, inserted through
    # the public admit+materialize API, then the enqueued Oban job's real
    # perform/1.
    descriptor =
      wave_descriptor(sha, @digest_a, "chain")
      |> Enum.map(fn {key, value} -> {Atom.to_string(key), value} end)
      |> Map.new()
      |> Map.put("repository", @repo)
      |> Map.delete("repository_identity")

    assert {:ok, %{epoch: epoch, wave: %{enqueued?: true, job_id: job_id}}} =
             SemanticWork.materialize(descriptor, binding: :graph)

    assert {:ok, %{status: "DISPATCHED"}} =
             SemanticWaveTrigger.Worker.perform(%Oban.Job{id: job_id, args: %{}})

    assert_receive {:semantic_wave_dispatched, epoch_id}
    assert epoch_id == epoch.id
  end

  # -- fixtures ---------------------------------------------------------------

  defp wave_descriptor(sha, digest, suffix) do
    %{
      work_order_iri: "urn:gall:work-order:xaas:trigger-#{suffix}",
      checkpoint_iri: "urn:gall:checkpoint:xaas:trigger-#{suffix}",
      graph_digest: digest,
      repository_identity: @repo,
      execution_repo_alias: "demo",
      base_sha: sha,
      goal: "Dispatch the admitted semantic work immediately.",
      provider: "zcode",
      verifier_suite: "semantic-test",
      execution_policy: :autonomic_wave_attempt,
      dependencies: []
    }
  end

  defp pending_wave_count do
    Xaas.Repo.one(
      from(j in Oban.Job,
        where: j.worker == ^@worker,
        where: j.state in ^~w(suspended available scheduled executing retryable),
        select: count(j.id)
      )
    )
  end
end
