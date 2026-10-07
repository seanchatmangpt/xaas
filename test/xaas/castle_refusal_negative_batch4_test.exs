defmodule Xaas.Castle.RefusalNegativeBatch4Test do
  @moduledoc """
  Wave-2 lane W47 batch 4: the REMAINING uncovered castle-engine refusal variants from
  `docs/sjira/v26.10.6/plans/vector2-refusal-coverage.md` section A, after batches 1-3
  (`castle_refusal_negative_test.exs`, `_batch2_`, `_batch3_`).

  Coverage audit of section A (25 castle-family variants + 5 admission/kernel + 2
  blocked): every variant in the plan's section A list is now token-claimed by batches
  1-3 EXCEPT the two covered below:

    9.  REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT   (castle.ex:884 — checkpoint["evidence_dir"]
        != request["evidence_dir"], i.e. the request derives evidence_dir from
        CASTLE_EVIDENCE_ROOT + witness_digest and the checkpoint was drifted elsewhere)
   26.  BLOCKED_CASTLE_TRANSPORT             (castle.ex:941 — System.cmd/3 raises on the
        kernel subprocess; rescued to {:error, {:BLOCKED_CASTLE_TRANSPORT, msg}})

  Both are feasible WITHOUT castle-kernel subprocess courts or DB receipt fixtures:
  EVIDENCE_ROOT_DRIFT through a constructible checkpoint field mutation on a real
  kernel-manufactured checkpoint; BLOCKED_CASTLE_TRANSPORT through a real, present,
  correctly-pinned but non-executable CASTLE_BIN file (real System.cmd raise, no mock).

  No section A variant was left infeasible-and-uncovered by this batch. Adjacent note
  (outside the plan's section A list): REFUSED_AMBIENT_CASTLE_COMMAND_POLICY is
  token-covered at test/xaas/castle_bridge_test.exs:179, and the two typed BLOCKED
  tuples {:error, {:BLOCKED_CASTLE_RUNTIME_FILE, _}} and
  {:error, {:BLOCKED_CASTLE_EVIDENCE_LIST, _}} (castle.ex:863, 656) are declared in lib
  but not named in the audit's variant list; they remain open follow-ups for a future
  lane.
  """

  use ExUnit.Case, async: false

  alias Xaas.Castle.Kernel.CLI
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    setup_fake_castle!()
    :ok
  end

  # -- 1. REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT (castle.ex:884) --------------------
  # request["evidence_dir"] is derived by the kernel from CASTLE_EVIDENCE_ROOT and the
  # witness digest; drifting ONLY the checkpoint's evidence_dir to a different absolute
  # path must refuse before any evidence recovery, subprocess DO call, or state yield.

  test "REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT: checkpoint evidence_dir drifted off the evidence root" do
    w = witness()
    {:ok, checkpoint} = CLI.manufacture(castle_intent(), w)

    drifted =
      Map.put(
        checkpoint,
        "evidence_dir",
        Path.join(
          System.tmp_dir!(),
          "castle-batch4-drifted-#{System.unique_integer([:positive])}"
        )
      )

    before = db_snapshot()

    assert {:error, :REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT} =
             CLI.execute(castle_intent(), w, drifted, now_ms())

    assert db_snapshot() == before
  end

  test "REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT: zero evidence files created under the evidence root" do
    w = witness()
    {:ok, checkpoint} = CLI.manufacture(castle_intent(), w)

    drifted =
      Map.put(
        checkpoint,
        "evidence_dir",
        Path.join(
          System.tmp_dir!(),
          "castle-batch4-drifted-#{System.unique_integer([:positive])}"
        )
      )

    refute File.exists?(drifted["evidence_dir"])
    assert File.ls(evidence_root()) == {:ok, []}

    assert {:error, :REFUSED_CASTLE_EVIDENCE_ROOT_DRIFT} =
             CLI.execute(castle_intent(), w, drifted, now_ms())

    # Neither the drifted path nor a witness-keyed evidence dir was created.
    refute File.exists?(drifted["evidence_dir"])
    assert File.ls(evidence_root()) == {:ok, []}
  end

  # -- 2. BLOCKED_CASTLE_TRANSPORT (castle.ex:941) -------------------------------
  # A real, present, byte-pinned CASTLE_BIN that is NOT executable: runtime/0 accepts it
  # (File.read succeeds, SHA-256 pin matches), then System.cmd/3 raises and the rescue
  # converts to {:error, {:BLOCKED_CASTLE_TRANSPORT, detail}} where detail is a
  # structured map (%{exception, message, executable}) — machine-readable stable
  # keys inside the typed tuple, never a bare string return.

  test "BLOCKED_CASTLE_TRANSPORT: non-executable pinned CASTLE_BIN blocks the kernel subprocess" do
    # Replace the executable fake with a non-executable file of the same bytes.
    script = System.fetch_env!("CASTLE_BIN")
    sha = System.fetch_env!("CASTLE_BIN_SHA256")
    File.chmod!(script, 0o644)

    try do
      assert File.read!(script) |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower) ==
               sha

      before = db_snapshot()

      assert {:error, {:BLOCKED_CASTLE_TRANSPORT, detail}} =
               CLI.manufacture(castle_intent(), witness())

      assert is_map(detail)

      assert MapSet.subset?(
               MapSet.new([:exception, :message, :executable]),
               MapSet.new(Map.keys(detail))
             )

      assert is_binary(detail.exception) and detail.exception != ""
      assert is_binary(detail.message) and detail.message != ""
      assert detail.executable == System.fetch_env!("CASTLE_BIN")
      # No raw exception text at the top level: detail is the map, not a string.
      refute is_binary(detail)

      assert db_snapshot() == before
    after
      File.chmod!(script, 0o755)
    end
  end

  # -- Helpers (mirroring batches 1/3) --------------------------------------------

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

  defp setup_fake_castle! do
    n = "#{System.system_time(:native)}-#{System.unique_integer([:positive, :monotonic])}"

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

    _ = File.rm(key)
    File.write!(key, String.duplicate("09", 32))

    root =
      System.tmp_dir!()
      |> Path.join("xaas-castle-evidence-#{n}")
      |> Path.expand()

    File.mkdir_p!(root)

    System.put_env("CASTLE_BIN", script)
    System.put_env("CASTLE_BIN_SHA256", sha256_file(script))
    System.put_env("CASTLE_SIGNING_KEY_PATH", key)
    System.put_env("CASTLE_KEY_ID", "xaas-castle-refusal-batch4-test-key")
    System.put_env("CASTLE_EVIDENCE_ROOT", root)
    System.put_env("CASTLE_FAKE_OUTPUT", output_path)
    System.delete_env("CASTLE_FAKE_EXIT")

    # Initialize the process-dictionary handles BEFORE any stub write so the
    # setup-order is valid inside a fresh test process (unlike batches 1/3,
    # which write their construct stub before Process.put runs).
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

  defp stub_raw!(body) do
    File.write!(output_path(), body)
  end

  defp output_path do
    Process.get({__MODULE__, :output_path}) || raise "castle fake output path not initialized"
  end

  defp evidence_root do
    Process.get({__MODULE__, :evidence_root}) || raise "castle evidence root not initialized"
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
