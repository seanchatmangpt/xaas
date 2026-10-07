defmodule Xaas.Castle.RefusalNegativeBatch3Test do
  @moduledoc """
  Wave-2 lane W39 batch 3: negative fixtures for the next 8 uncovered castle refusal
  variants from `docs/sjira/v26.10.6/plans/vector2-refusal-coverage.md` (disjoint from
  batch 1 in `castle_refusal_negative_test.exs` and batch 2 in
  `castle_refusal_negative_batch2_test.exs`).

  Covered here (exact typed refusal, zero state yield — no DB rows, no evidence files):

    1. REFUSED_WRONG_CASTLE_IDENTITY               (castle.ex:949 via release_info/0)
    2. REFUSED_INVALID_CASTLE_ADAPTER_PROFILE      (castle.ex:824)
    3. REFUSED_INVALID_CASTLE_RECEIPT_DIGEST       (castle.ex:961)
    4. REFUSED_CASTLE_CHECKPOINT_DIGEST            (castle.ex:449) — INFEASIBLE, see below
    5. REFUSED_CASTLE_CHECKPOINT_EVIDENCE_PATH     (castle.ex:453) — INFEASIBLE, see below
    6. REFUSED_UNVERIFIED_CASTLE_EVIDENCE          (castle.ex:677 via execute/4 recovery)
    7. REFUSED_UNEXPECTED_CASTLE_EVIDENCE_RECORD   (castle.ex:673 via execute/4 recovery)
    8. REFUSED_AMBIGUOUS_CASTLE_EVIDENCE           (castle.ex:683 via execute/4 recovery)

  Method: real public-function calls on `Xaas.Castle.Admission` /
  `Xaas.Castle.Kernel.CLI` (Chicago — no mocks, no doubles), exactly one evidence field
  mutated per variant, exact-tuple assertion, and real DB + filesystem snapshots
  asserting zero state yield.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @authority %{
    kind: "xaas_reactor",
    source: "castle_refusal_negative_batch3_test",
    scope: "castle.run"
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    setup_fake_castle!()
    {:ok, %{evidence_root: evidence_root()}}
  end

  # -- 1. REFUSED_WRONG_CASTLE_IDENTITY (castle.ex:945-949) --------------------

  test "REFUSED_WRONG_CASTLE_IDENTITY: release info names a foreign kernel" do
    stub_raw!(Jason.encode!(%{"name" => "NOT_CASTLE", "release" => "26.8.18"}))

    before = db_snapshot()

    assert {:error, :REFUSED_WRONG_CASTLE_IDENTITY} =
             Xaas.Castle.Kernel.CLI.release_info()

    assert db_snapshot() == before
  end

  test "REFUSED_WRONG_CASTLE_IDENTITY: release field absent from identity payload" do
    stub_raw!(Jason.encode!(%{"name" => "CASTLE"}))

    assert {:error, :REFUSED_WRONG_CASTLE_IDENTITY} =
             Xaas.Castle.Kernel.CLI.release_info()
  end

  # -- 2. REFUSED_INVALID_CASTLE_ADAPTER_PROFILE (castle.ex:824) ---------------

  test "REFUSED_INVALID_CASTLE_ADAPTER_PROFILE: registered profile carries no adapter_policy map" do
    profile = %{
      allowed_authorities: ["bounded-do"],
      adapter_policy: "not-a-map"
    }

    Application.put_env(:xaas, :castle_adapter_profiles, %{"xaas-local-proof" => profile})

    assert {:error, :REFUSED_INVALID_CASTLE_ADAPTER_PROFILE} =
             Xaas.Castle.Kernel.CLI.manufacture(castle_intent(), witness())
  end

  # -- 3. REFUSED_INVALID_CASTLE_RECEIPT_DIGEST (castle.ex:951-965) ------------

  test "REFUSED_INVALID_CASTLE_RECEIPT_DIGEST: DO output carries a non-digest BRCE receipt" do
    w = witness()
    {:ok, checkpoint} = Xaas.Castle.Kernel.CLI.manufacture(castle_intent(), w)

    stub_do!(%{
      "standing" => "ALIVE",
      "ocel_receipt_digest" => hex(),
      "event_count" => 1,
      "brce_prepare_receipt_digests" => [hex(), "zz-not-a-digest"],
      "brce_outcome_receipt_digests" => [hex()],
      "evidence_commit" => %{"standing" => "ALIVE"}
    })

    before = db_snapshot()

    assert {:error, :REFUSED_INVALID_CASTLE_RECEIPT_DIGEST} =
             execute(checkpoint, w)

    assert db_snapshot() == before
  end

  # -- 4/5. REFUSED_CASTLE_CHECKPOINT_DIGEST / REFUSED_CASTLE_CHECKPOINT_EVIDENCE_PATH
  # INFEASIBLE via the public persisted path (ActuationReceipt.result round-trip):
  # the kernel-emitted checkpoint carries contract.protocol as an ATOM, but the
  # Ecto map persistence of ActuationReceipt.result stringifies it, so
  # Xaas.Castle.Admission.checkpoint/2 always hits the first cond clause
  # (REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH, castle.ex:429) before the
  # digest (castle.ex:449) and evidence-path (castle.ex:453) checks can fire.
  # Verified empirically: committing either the atom or the string form of
  # contract.protocol still reads back as a string and refuses at protocol.
  # => latent defect: every persisted castle checkpoint is refused at
  #    PROTOCOL_MISMATCH on the admitted path; DIGEST/EVIDENCE_PATH are dead
  #    code there. Coordinator/lib-owner to fix (out of W39 lane scope).

  # -- 6/7/8. Evidence recovery surface (castle.ex:643-686) --------------------

  test "REFUSED_UNVERIFIED_CASTLE_EVIDENCE: durable evidence file fails kernel verification" do
    w = witness()
    {:ok, checkpoint} = Xaas.Castle.Kernel.CLI.manufacture(castle_intent(), w)

    File.mkdir_p!(checkpoint["evidence_dir"])
    File.write!(Path.join(checkpoint["evidence_dir"], "evidence-1.json"), "{}")
    stub_raw!("this body is not json")

    before = db_snapshot()

    assert {:error,
            {:REFUSED_UNVERIFIED_CASTLE_EVIDENCE,
             {:REFUSED_NON_JSON_CASTLE_RESPONSE, "this body is not json"}}} =
             execute(checkpoint, w)

    assert db_snapshot() == before
  end

  test "REFUSED_UNEXPECTED_CASTLE_EVIDENCE_RECORD: evidence record is bound to a foreign construct" do
    w = witness()
    {:ok, checkpoint} = Xaas.Castle.Kernel.CLI.manufacture(castle_intent(), w)

    File.mkdir_p!(checkpoint["evidence_dir"])
    File.write!(Path.join(checkpoint["evidence_dir"], "evidence-1.json"), "{}")

    stub_do!(%{
      "standing" => "ALIVE",
      "record" => %{
        "construct_digest" => hex(),
        "subject" => "system:xaas-castle-proof",
        "cell_id" => "cell:xaas:#{w["xaas_receipt_id"]}"
      },
      "record_identity" => hex(),
      "path" => Path.join(checkpoint["evidence_dir"], "evidence-1.json")
    })

    before = db_snapshot()

    assert {:error, :REFUSED_UNEXPECTED_CASTLE_EVIDENCE_RECORD} =
             execute(checkpoint, w)

    assert db_snapshot() == before
  end

  test "REFUSED_AMBIGUOUS_CASTLE_EVIDENCE: two verified evidence records match the checkpoint" do
    w = witness()
    {:ok, checkpoint} = Xaas.Castle.Kernel.CLI.manufacture(castle_intent(), w)

    File.mkdir_p!(checkpoint["evidence_dir"])
    File.write!(Path.join(checkpoint["evidence_dir"], "evidence-1.json"), "{}")
    File.write!(Path.join(checkpoint["evidence_dir"], "evidence-2.json"), "{}")

    matching = %{
      "standing" => "ALIVE",
      "record" => %{
        "construct_digest" => checkpoint["construct_digest"],
        "subject" => "system:xaas-castle-proof",
        "cell_id" => "cell:xaas:#{w["xaas_receipt_id"]}"
      },
      "record_identity" => hex(),
      "path" => Path.join(checkpoint["evidence_dir"], "evidence-1.json")
    }

    stub_do!(matching)

    before = db_snapshot()

    assert {:error, :REFUSED_AMBIGUOUS_CASTLE_EVIDENCE} =
             execute(checkpoint, w)

    assert db_snapshot() == before
  end

  # -- Helpers (mirroring batch 1) ----------------------------------------------

  defp execute(checkpoint, w) do
    before = db_snapshot()
    result = Xaas.Castle.Kernel.CLI.execute(castle_intent(), w, checkpoint, now_ms())
    assert db_snapshot() == before
    result
  end

  defp setup_fake_castle! do
    n =
      "#{System.unique_integer([:positive, :monotonic])}-#{Base.encode16(:crypto.strong_rand_bytes(4))}"

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
    System.put_env("CASTLE_KEY_ID", "xaas-castle-refusal-batch3-test-key")
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
        idempotency_key: "xaas-castle-neg-batch3-#{System.unique_integer([:positive])}",
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

  defp witness do
    %{
      "subject" => "system:xaas-castle-proof",
      "authority" => "bounded-do",
      "witness_digest" => hex(),
      "xaas_receipt_id" => Ecto.UUID.generate()
    }
  end

  defp base_checkpoint(w) do
    identity = Xaas.Castle.Contract.identity()

    %{
      # NOTE: the kernel emits contract.protocol as an atom, but the persisted
      # ActuationReceipt.result (Ecto map round-trip) stringifies it. The
      # admitted Admission.checkpoint/2 path therefore sees the string form.
      "protocol" => to_string(identity.protocol),
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
