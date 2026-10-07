defmodule Xaas.CastleRefusalNegativeTest do
  @moduledoc """
  Negative (typed-refusal) fixtures for the XaaS -> CASTLE engine — v26.10.6
  convergence vector 2, refusal-coverage batch 1 (castle engine).

  Each test mutates exactly one evidence field and asserts the exact typed
  `{:error, ...}` refusal plus zero state yield (pre-state == post-state:
  real Ecto sandbox rows via `Xaas.Actuation.prepare_external`, real subprocess
  for the kernel, evidence tree unchanged).

  Chicago discipline: no mocks. The CASTLE binary is replaced by a real
  /bin/sh executable that emits canned construct/DO JSON or a non-zero exit —
  a real subprocess, not a test double of an owned collaborator (the real
  admitted binary is a build artifact of a separate repo; the :castle_kernel
  court covers that subject). All other collaborators are real.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @authority %{kind: "xaas_reactor", source: "castle_refusal_negative_test", scope: "castle.run"}

  # W297d: /tmp file-lock mutex path — see with_castle_lock/1 below.
  # XAAS_CASTLE_TEST_LOCK overrides it at RUNTIME (isolated verification on a
  # shared checkout where several lanes run the same files concurrently); the
  # full suite uses the shared default so every castle subprocess serializes.
  defp castle_lock_path do
    System.get_env("XAAS_CASTLE_TEST_LOCK") ||
      Path.join(System.tmp_dir!(), "xaas-castle-test-cli.lock")
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    setup_fake_castle!()
    :ok
  end

  test "REFUSED_INVALID_CASTLE_DIGEST: construct output carries a non-hex digest" do
    stub_construct!(%{
      "standing" => "ALIVE",
      "construct_digest" => "zz-not-a-digest",
      "construct_receipt_digest" => hex(),
      "process_digest" => hex(),
      "replay_identity_digest" => hex()
    })

    before = db_snapshot()

    assert {:error, :REFUSED_INVALID_CASTLE_DIGEST} =
             castle_manufacture(castle_intent(), witness())

    assert db_snapshot() == before
  end

  test "REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE: construct output is not standing ALIVE" do
    stub_construct!(%{
      "standing" => "REFUTED",
      "construct_digest" => hex(),
      "construct_receipt_digest" => hex(),
      "process_digest" => hex(),
      "replay_identity_digest" => hex()
    })

    assert {:error, :REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE} =
             castle_manufacture(castle_intent(), witness())
  end

  test "REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE: intent names an unconfigured profile" do
    intent = Map.put(castle_intent(), :adapter_profile_id, "xaas-does-not-exist")

    assert {:error, :REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE} =
             castle_manufacture(intent, witness())
  end

  test "REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED: authority outside the profile ceiling" do
    intent = %{castle_intent() | authority: "unbounded-do"}
    w = witness(%{"authority" => "unbounded-do"})

    assert {:error, :REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED} =
             castle_manufacture(intent, w)
  end

  test "REFUSED_CASTLE_RUNTIME_IDENTITY: CASTLE_BIN_SHA256 does not match the real binary" do
    System.put_env("CASTLE_BIN_SHA256", hex())

    assert {:error, :REFUSED_CASTLE_RUNTIME_IDENTITY} =
             castle_manufacture(castle_intent(), witness())
  end

  test "REFUSED_CASTLE_KERNEL_DRIFT: checkpoint kernel_binary_sha256 mutated" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    checkpoint = Map.put(checkpoint, "kernel_binary_sha256", hex())

    assert {:error, :REFUSED_CASTLE_KERNEL_DRIFT} = execute(w, checkpoint)
  end

  test "REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT: checkpoint signing_key_sha256 mutated" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    checkpoint = Map.put(checkpoint, "signing_key_sha256", hex())

    assert {:error, :REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT} = execute(w, checkpoint)
  end

  test "REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT: checkpoint adapter_profile_digest mutated" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    checkpoint = Map.put(checkpoint, "adapter_profile_digest", hex())

    assert {:error, :REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT} = execute(w, checkpoint)
  end

  test "REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH: checkpoint witness_digest mutated" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    checkpoint = Map.put(checkpoint, "witness_digest", hex())

    assert {:error, :REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH} = execute(w, checkpoint)
  end

  test "REFUSED_CASTLE_CONSTRUCT_DIGEST: checkpoint construct_digest is not a digest" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    checkpoint = Map.put(checkpoint, "construct_digest", "zz-not-a-digest")

    assert {:error, :REFUSED_CASTLE_CONSTRUCT_DIGEST} = execute(w, checkpoint)
  end

  test "REFUSED_UNRECEIPTED_CASTLE_DO: kernel DO output is not a receipted ALIVE result" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    stub_do!(%{"standing" => "REFUTED"})

    assert {:error, :REFUSED_UNRECEIPTED_CASTLE_DO} = execute(w, checkpoint)
  end

  test "REFUSED_NON_JSON_CASTLE_RESPONSE: kernel subprocess emits a non-JSON body" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    stub_raw!("hello, not json at all")

    assert {:error, {:REFUSED_NON_JSON_CASTLE_RESPONSE, "hello, not json at all"}} =
             execute(w, checkpoint)
  end

  test "REFUSED_CASTLE_EXIT: kernel subprocess exits non-zero" do
    w = witness()
    {:ok, checkpoint} = castle_manufacture(castle_intent(), w)
    stub_do!(%{"standing" => "REFUTED"})
    System.put_env("CASTLE_FAKE_EXIT", "7")
    before = db_snapshot()

    assert {:error, {:REFUSED_CASTLE_EXIT, 7, output}} = execute(w, checkpoint)

    assert output =~ "REFUTED"
    assert db_snapshot() == before
  end

  test "REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED: ActionInput carries no actuation context" do
    input = Ash.ActionInput.for_action(RouteCastleRun, :execute, %{intent: castle_intent()})

    assert {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED} =
             Xaas.Castle.Admission.witness(input, castle_intent(), now_ms())
  end

  test "REFUSED_XAAS_ADMISSION_EXPIRED: envelope expires in the past" do
    intent = expire_envelope(castle_intent(), -120_000)
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:error, :REFUSED_XAAS_ADMISSION_EXPIRED} =
             Xaas.Castle.Admission.witness(input, intent, now_ms())
  end

  test "REFUSED_XAAS_ADMISSION_MISMATCH: envelope carries no expiry field" do
    base = castle_intent()
    intent = %{base | envelope: Map.delete(base.envelope, :expires_at_epoch_ms)}
    admission = prepare_admission!(intent)

    assert {:error, :REFUSED_XAAS_ADMISSION_MISMATCH} =
             Xaas.Castle.Admission.witness(action_input(intent, admission), intent, now_ms())
  end

  test "REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH: witness bound to a foreign receipt" do
    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, w} = Xaas.Castle.Admission.witness(input, intent, now_ms())

    foreign = Map.put(w, "xaas_receipt_id", Ecto.UUID.generate())

    assert {:error, :REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH} =
             Xaas.Castle.Admission.checkpoint(input, foreign)
  end

  test "REFUSED_XAAS_CHECKPOINT_HASH_REQUIRED: committed checkpoint result_hash corrupted" do
    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, w} = Xaas.Castle.Admission.witness(input, intent, now_ms())
    checkpoint = base_checkpoint(w)

    assert {:ok, _} =
             Xaas.Actuation.checkpoint_external(admission, %{"castle_construct" => checkpoint})

    receipt = Ash.get!(ActuationReceipt, admission.receipt.id, authorize?: false)

    assert {:ok, _} =
             Ash.update(receipt, %{result_hash: "zz-not-a-digest"},
               action: :checkpoint,
               authorize?: false
             )

    before = db_snapshot()

    assert {:error, :REFUSED_XAAS_CHECKPOINT_HASH_REQUIRED} =
             Xaas.Castle.Admission.checkpoint(input, w)

    assert db_snapshot() == before
  end

  test "REFUSED_XAAS_CASTLE_CHECKPOINT_REQUIRED: checkpoint committed without castle_construct" do
    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, w} = Xaas.Castle.Admission.witness(input, intent, now_ms())

    assert {:ok, _} =
             Xaas.Actuation.checkpoint_external(admission, %{
               "not_castle_construct" => %{"x" => 1}
             })

    assert {:error, :REFUSED_XAAS_CASTLE_CHECKPOINT_REQUIRED} =
             Xaas.Castle.Admission.checkpoint(input, w)
  end

  defp execute(w, checkpoint) do
    before = db_snapshot()

    result =
      with_castle_lock(fn ->
        Xaas.Castle.Kernel.CLI.execute(castle_intent(), w, checkpoint, now_ms())
      end)

    assert db_snapshot() == before
    result
  end

  # W297d: under full-suite concurrency, real-OS castle subprocesses from
  # concurrent test modules raced on the shared /tmp surface — the kernel's
  # exclusive request-file write returned {:error, :eexist} and, under memory
  # pressure, the spawned /bin/sh died with SIGKILL (exit 137). Serialize every
  # kernel CLI invocation behind a /tmp file-lock mutex (exclusive-create spin
  # lock, not a test double), so only one castle subprocess exists at a time.

  defp with_castle_lock(fun) do
    {:ok, lock} = acquire_castle_lock(castle_lock_path())

    try do
      fun.()
    after
      File.close(lock)
      File.rm(castle_lock_path())
    end
  end

  # Exclusive-create mutex: first opener holds the file; contenders spin until
  # the holder unlinks it. (OTP 28 removed :file.write_lock, so no flock.)
  # Self-healing against a holder killed mid-hold (SIGKILL leaves the file):
  # a live castle subprocess completes in seconds even under load, so a hold
  # longer than @castle_lock_stale_ms means the holder is dead — break it.
  @castle_lock_stale_ms 30_000

  defp acquire_castle_lock(path, waited_ms \\ 0)

  defp acquire_castle_lock(path, waited_ms) when waited_ms >= @castle_lock_stale_ms do
    File.rm(path)
    acquire_castle_lock(path, -1)
  end

  defp acquire_castle_lock(path, waited_ms) do
    case File.open(path, [:read, :write, :exclusive]) do
      {:ok, fd} ->
        {:ok, fd}

      {:error, :eexist} ->
        Process.sleep(50)
        acquire_castle_lock(path, waited_ms + 50)

      {:error, :enoent} ->
        File.mkdir_p!(Path.dirname(path))
        acquire_castle_lock(path, waited_ms)
    end
  end

  # W974: this helper previously re-entered itself inside with_castle_lock/1 —
  # infinite self-recursion, so every manufacture-based test deadlocked on its
  # own /tmp file lock (13/19 ExUnit timeouts; W863 lsof evidence). Call the
  # real kernel CLI manufacture/2 under the lock instead.
  defp castle_manufacture(intent, witness) do
    with_castle_lock(fn -> Xaas.Castle.Kernel.CLI.manufacture(intent, witness) end)
  end

  defp setup_fake_castle! do
    n = System.unique_integer([:positive, :monotonic])

    script =
      System.tmp_dir!()
      |> Path.join("xaas-castle-fake-bin-#{n}.sh")
      |> Path.expand()

    File.write!(script, """
    #!/bin/sh
    : "${CASTLE_FAKE_EXIT:=0}"
    cat "$CASTLE_FAKE_OUTPUT"
    exit "$CASTLE_FAKE_EXIT"
    """)

    File.chmod!(script, 0o755)

    output_path =
      System.tmp_dir!()
      |> Path.join("xaas-castle-fake-output-#{n}.json")

    key =
      System.tmp_dir!()
      |> Path.join("xaas-castle-key-#{n}.hex")

    # Replace-mode write (no [:exclusive]): unique-per-setup path + on_exit cleanup
    # make an /tmp-residue collision a replace, not a File.WriteError crash.
    File.write!(key, String.duplicate("09", 32))

    root =
      System.tmp_dir!()
      |> Path.join("xaas-castle-evidence-#{n}")
      |> Path.expand()

    File.mkdir_p!(root)

    System.put_env("CASTLE_BIN", script)
    System.put_env("CASTLE_BIN_SHA256", sha256_file(script))
    System.put_env("CASTLE_SIGNING_KEY_PATH", key)
    System.put_env("CASTLE_KEY_ID", "xaas-castle-refusal-test-key")
    System.put_env("CASTLE_EVIDENCE_ROOT", root)
    System.put_env("CASTLE_FAKE_OUTPUT", output_path)
    System.delete_env("CASTLE_FAKE_EXIT")

    Process.put({__MODULE__, :evidence_root}, root)
    Process.put({__MODULE__, :output_path}, output_path)

    stub_construct!(%{
      "standing" => "ALIVE",
      "construct_digest" => hex(),
      "construct_receipt_digest" => hex(),
      "process_digest" => hex(),
      "replay_identity_digest" => hex()
    })

    profile = %{
      allowed_authorities: ["bounded-do"],
      adapter_policy: %{
        adapter_id: "xaas-local-proof",
        provider: "local",
        workload_identity: "workload:xaas-castle-proof",
        commands: %{
          "echo" => %{
            transition_id: "echo",
            program: "/bin/echo",
            args: ["fabric"],
            allowed_exit_codes: [0],
            max_output_bytes: 4096,
            timeout_ms: 2_000
          }
        }
      }
    }

    previous = Application.get_env(:xaas, :castle_adapter_profiles)
    Application.put_env(:xaas, :castle_adapter_profiles, %{"xaas-local-proof" => profile})

    on_exit(fn ->
      File.rm(script)
      File.rm(output_path)
      File.rm(key)
      File.rm_rf(root)

      for k <-
            ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT CASTLE_FAKE_OUTPUT CASTLE_FAKE_EXIT) do
        System.delete_env(k)
      end

      if is_nil(previous),
        do: Application.delete_env(:xaas, :castle_adapter_profiles),
        else: Application.put_env(:xaas, :castle_adapter_profiles, previous)
    end)

    :ok
  end

  defp stub_construct!(construct), do: stub_raw!(Jason.encode!(construct))
  defp stub_do!(do_output), do: stub_raw!(Jason.encode!(do_output))

  defp stub_raw!(body) do
    File.write!(output_path(), body)
  end

  defp output_path do
    Process.get({__MODULE__, :output_path}) || raise "castle fake output path not initialized"
  end

  defp evidence_root do
    Process.get({__MODULE__, :evidence_root}) || raise "castle evidence root not initialized"
  end

  defp db_snapshot do
    %{
      intents: length(Ash.read!(ActuationIntent, authorize?: false)),
      receipts: length(Ash.read!(ActuationReceipt, authorize?: false)),
      evidence: evidence_names()
    }
  end

  defp evidence_names do
    case File.ls(evidence_root()) do
      {:ok, names} -> Enum.sort(names)
      {:error, :enoent} -> :enoent
    end
  end

  defp prepare_admission!(intent) do
    {:ok, prepared} =
      Xaas.Actuation.prepare_external(RouteCastleRun, :execute, %{intent: intent},
        subject_id: intent.subject,
        idempotency_key: "xaas-castle-neg-#{System.unique_integer([:positive])}",
        authorize?: false,
        authority: @authority
      )

    assert prepared.status == :prepared
    prepared.admission
  end

  defp action_input(intent, admission) do
    Ash.ActionInput.for_action(RouteCastleRun, :execute, %{intent: intent},
      context: Xaas.Actuation.context(admission)
    )
  end

  defp castle_intent do
    now = System.system_time(:millisecond)

    %{
      adapter_profile_id: "xaas-local-proof",
      subject: "system:xaas-castle-proof",
      authority: "bounded-do",
      config_graph: %{"zeroUnreceiptedActuation" => true},
      ontology: %{"version" => "26.8.18"},
      process: %{
        id: "powl:xaas-castle-proof",
        goal_id: "goal:xaas-castle-proof",
        activities: [%{id: "activity:echo", transition_id: "echo", predecessors: []}]
      },
      envelope: %{
        system_id: "system:xaas-castle-proof",
        allowed_transition_ids: ["echo"],
        max_steps: 1,
        expires_at_epoch_ms: now + 60_000
      }
    }
  end

  defp expire_envelope(intent, delta_ms) do
    put_in(intent.envelope.expires_at_epoch_ms, intent.envelope.expires_at_epoch_ms + delta_ms)
  end

  defp witness(params \\ %{}) do
    Map.merge(
      %{
        "subject" => "system:xaas-castle-proof",
        "authority" => "bounded-do",
        "witness_digest" => hex(),
        "xaas_receipt_id" => Ecto.UUID.generate()
      },
      params
    )
  end

  defp base_checkpoint(w) do
    identity = Xaas.Castle.Contract.identity()

    %{
      "protocol" => identity.protocol,
      "castle_paas_source_sha" => identity.castle_paas_source_sha,
      "witness_digest" => w["witness_digest"],
      "construct_digest" => hex(),
      "construct_receipt_digest" => hex(),
      "process_digest" => hex(),
      "replay_identity_digest" => hex(),
      "kernel_binary_sha256" => sha256_file(System.fetch_env!("CASTLE_BIN")),
      "signing_key_sha256" => sha256_file(System.fetch_env!("CASTLE_SIGNING_KEY_PATH")),
      "adapter_profile_digest" => hex(),
      "evidence_dir" => Path.join(evidence_root(), w["witness_digest"])
    }
  end

  defp sha256_file(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp hex do
    :crypto.strong_rand_bytes(32)
    |> Base.encode16(case: :lower)
  end

  defp now_ms, do: System.system_time(:millisecond)
end
