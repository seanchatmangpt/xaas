defmodule Xaas.Castle.RefusalNegativeBatch5Test do
  @moduledoc """
  Wave-2 lane W67 batch 5: the two adjacent typed-BLOCKED tuples from the W47
  audit tail (`docs/sjira/v26.10.6/plans/vector2-refusal-coverage.md`), declared in
  lib but absent from the plan's section-A variant list and from batches 1-4:

    1. {:error, {:BLOCKED_CASTLE_RUNTIME_FILE, reason}}   (castle.ex:863 via runtime/0)
    2. {:error, {:BLOCKED_CASTLE_EVIDENCE_LIST, reason}}  (castle.ex:656 via
       recover_existing_evidence/3 inside execute/4)

  Method (batch-4 style, Chicago): real kernel module, real subprocess, real FS.
  One input mutated per variant; exact-tuple assertion; zero state yield
  (pre-state == post-state over real Ecto sandbox rows and the evidence tree).

    1. RUNTIME_FILE: point CASTLE_SIGNING_KEY_PATH (or CASTLE_BIN) at a
       nonexistent absolute path — env checks pass, `File.read/1` fails with
       :enoent, and the rescue-free else-clause yields the typed BLOCKED tuple.
    2. EVIDENCE_LIST: manufacture a real kernel checkpoint, then replace the
       (absent) per-witness evidence dir with a regular FILE — `File.ls/1`
       returns {:error, :enotdir}, which is not :enoent, so the typed tuple
       fires before any kernel subprocess DO call.
  """

  use ExUnit.Case, async: false

  alias Xaas.Castle.Kernel.CLI
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    setup_fake_castle!()
    :ok
  end

  # -- 1. {:error, {:BLOCKED_CASTLE_RUNTIME_FILE, _}} (castle.ex:863) -----------

  test "BLOCKED_CASTLE_RUNTIME_FILE: signing key path points at a nonexistent file" do
    missing =
      Path.expand(
        Path.join(
          System.tmp_dir!(),
          "castle-batch5-missing-key-#{System.unique_integer([:positive])}.hex"
        )
      )

    refute File.exists?(missing)

    System.put_env("CASTLE_SIGNING_KEY_PATH", missing)
    before = db_snapshot()

    assert {:error, {:BLOCKED_CASTLE_RUNTIME_FILE, :enoent}} =
             CLI.manufacture(castle_intent(), witness())

    assert db_snapshot() == before
    refute File.exists?(missing)
  end

  test "BLOCKED_CASTLE_RUNTIME_FILE: CASTLE_BIN path points at a nonexistent file" do
    missing =
      Path.expand(
        Path.join(
          System.tmp_dir!(),
          "castle-batch5-missing-bin-#{System.unique_integer([:positive])}.sh"
        )
      )

    refute File.exists?(missing)

    System.put_env("CASTLE_BIN", missing)
    before = db_snapshot()

    assert {:error, {:BLOCKED_CASTLE_RUNTIME_FILE, :enoent}} =
             CLI.manufacture(castle_intent(), witness())

    assert db_snapshot() == before
    refute File.exists?(missing)
  end

  # -- 2. {:error, {:BLOCKED_CASTLE_EVIDENCE_LIST, _}} (castle.ex:656) ----------

  test "BLOCKED_CASTLE_EVIDENCE_LIST: evidence dir path exists as a regular file (enotdir)" do
    w = witness()
    {:ok, checkpoint} = CLI.manufacture(castle_intent(), w)

    evidence_dir = checkpoint["evidence_dir"]
    refute File.exists?(evidence_dir)

    File.write!(evidence_dir, "not a directory")

    before = db_snapshot()

    assert {:error, {:BLOCKED_CASTLE_EVIDENCE_LIST, :enotdir}} =
             CLI.execute(castle_intent(), w, checkpoint, now_ms())

    assert db_snapshot() == before
    assert File.regular?(evidence_dir)
    File.rm(evidence_dir)
  end

  # -- Helpers (batch-4 style) ---------------------------------------------------

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
    System.put_env("CASTLE_KEY_ID", "xaas-castle-refusal-batch5-test-key")
    System.put_env("CASTLE_EVIDENCE_ROOT", root)
    System.put_env("CASTLE_FAKE_OUTPUT", output_path)
    System.delete_env("CASTLE_FAKE_EXIT")

    # Initialize the process-dictionary handles BEFORE any stub write so the
    # setup order is valid inside a fresh test process.
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
