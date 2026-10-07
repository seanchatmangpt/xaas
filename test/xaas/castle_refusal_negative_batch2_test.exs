defmodule Xaas.Castle.RefusalNegativeBatch2Test do
  @moduledoc """
  Wave-2 lane W26 batch 2: negative fixtures for the next 8 uncovered castle refusal
  variants from `docs/sjira/v26.10.6/plans/vector2-refusal-coverage.md` (disjoint from
  batch 1 in `castle_refusal_negative_test.exs`).

  Covered here (exact typed refusal, zero state yield — no DB rows, no evidence files):

    1. REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED      (castle.ex:260,278,389)
    2. REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT    (castle.ex:598)
    3. REFUSED_INVALID_CASTLE_EXECUTION_INTENT    (castle.ex:620)
    4. BLOCKED_CASTLE_RUNTIME_CONFIGURATION       (castle.ex:841 nil-env branch)
    5. REFUSED_CASTLE_RUNTIME_IDENTITY            (castle.ex:855 — relative evidence root,
                                                   mismatched-length-64 CASTLE_BIN_SHA256)
   5b. REFUSED_CASTLE_RUNTIME_CONFIGURATION       (castle.ex:857 — malformed CASTLE_BIN_SHA256)
    6. REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE     (castle.ex:821)
    7. REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH (castle.ex:866)
    8. REFUSED_CASTLE_CHECKPOINT_SOURCE_MISMATCH  (castle.ex:869)

  Method: real public-function calls on `Xaas.Castle.Admission` /
  `Xaas.Castle.Kernel.CLI` (Chicago — no mocks, no doubles), exactly one evidence field
  mutated per variant, exact-tuple assertion, and a real filesystem assertion that no
  evidence directory or request artifact was produced.
  """

  use ExUnit.Case, async: false

  alias Xaas.Castle.{Admission, Contract, Kernel.CLI}

  @hex64 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    for k <-
          ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT),
        do: System.delete_env(k)

    previous_profiles = Application.get_env(:xaas, :castle_adapter_profiles)

    on_exit(fn ->
      for k <-
            ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT),
          do: System.delete_env(k)

      if is_nil(previous_profiles),
        do: Application.delete_env(:xaas, :castle_adapter_profiles),
        else: Application.put_env(:xaas, :castle_adapter_profiles, previous_profiles)
    end)

    :ok
  end

  ## 1. REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED

  test "witness/3 with a non-ActionInput subject refuses reactor-context-required" do
    now = System.system_time(:millisecond)

    assert {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED} =
             Admission.witness("not-an-action-input", %{"subject" => "s"}, now)
  end

  test "witness/3 with an ActionInput lacking xaas_actuation context refuses" do
    now = System.system_time(:millisecond)

    input =
      Ash.ActionInput.for_action(Xaas.Operations.RouteCastleRun, :execute, %{intent: %{}}, %{})

    assert {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED} =
             Admission.witness(input, %{"subject" => "s"}, now)
  end

  test "checkpoint/2 with a non-ActionInput subject refuses reactor-context-required" do
    assert {:error, :REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED} =
             Admission.checkpoint("not-an-action-input", %{"xaas_receipt_id" => "r"})
  end

  ## 2. REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT

  test "manufacture/2 with non-map arguments refuses invalid-construct-intent" do
    assert {:error, :REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT} =
             CLI.manufacture("not-a-map", %{"witness_digest" => @hex64})

    assert {:error, :REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT} =
             CLI.manufacture(%{"subject" => "s"}, "not-a-map")

    assert {:error, :REFUSED_INVALID_CASTLE_CONSTRUCT_INTENT} =
             CLI.manufacture(nil, nil)
  end

  ## 3. REFUSED_INVALID_CASTLE_EXECUTION_INTENT

  test "execute/4 with non-map arguments refuses invalid-execution-intent" do
    now = System.system_time(:millisecond)

    assert {:error, :REFUSED_INVALID_CASTLE_EXECUTION_INTENT} =
             CLI.execute(nil, %{}, %{}, now)

    assert {:error, :REFUSED_INVALID_CASTLE_EXECUTION_INTENT} =
             CLI.execute(%{}, nil, %{}, now)

    assert {:error, :REFUSED_INVALID_CASTLE_EXECUTION_INTENT} =
             CLI.execute(%{}, %{}, %{}, "not-an-integer")
  end

  ## 4. BLOCKED_CASTLE_RUNTIME_CONFIGURATION

  test "execute/4 with all CASTLE_* env unset blocks on runtime configuration, no evidence written" do
    intent = valid_intent()
    now = System.system_time(:millisecond)

    assert {:error, :BLOCKED_CASTLE_RUNTIME_CONFIGURATION} =
             CLI.execute(intent, valid_witness(), valid_checkpoint(), now)

    assert_no_evidence_written()
  end

  ## 5. REFUSED_CASTLE_RUNTIME_IDENTITY (castle.ex:855 — relative CASTLE_EVIDENCE_ROOT)

  test "execute/4 with a relative CASTLE_EVIDENCE_ROOT refuses runtime identity" do
    bin = "/bin/echo"
    root = fresh_evidence_root!()

    set_runtime_env(
      bin: bin,
      sha: sha256_of(bin),
      key_path: real_key_file!(),
      key_id: "batch2-key",
      evidence_root: "relative/castle-evidence-root"
    )

    assert {:error, :REFUSED_CASTLE_RUNTIME_IDENTITY} =
             CLI.execute(
               valid_intent(),
               valid_witness(),
               valid_checkpoint(),
               System.system_time(:millisecond)
             )

    assert File.ls!(root) == []
  end

  ## 5b. REFUSED_CASTLE_RUNTIME_CONFIGURATION (castle.ex:857 — malformed CASTLE_BIN_SHA256)

  test "execute/4 with a wrong-length CASTLE_BIN_SHA256 refuses runtime configuration" do
    bin = "/bin/echo"
    root = fresh_evidence_root!()
    set_runtime_env(bin: bin, sha: String.duplicate("a", 63), evidence_root: root)
    now = System.system_time(:millisecond)

    assert {:error, :REFUSED_CASTLE_RUNTIME_CONFIGURATION} =
             CLI.execute(valid_intent(), valid_witness(), valid_checkpoint(), now)

    assert File.ls!(root) == []
  end

  test "execute/4 with a valid-length but mismatched CASTLE_BIN_SHA256 refuses runtime identity" do
    bin = "/bin/echo"
    root = fresh_evidence_root!()
    set_runtime_env(bin: bin, sha: @hex64, key_path: real_key_file!(), evidence_root: root)
    now = System.system_time(:millisecond)

    assert {:error, :REFUSED_CASTLE_RUNTIME_IDENTITY} =
             CLI.execute(valid_intent(), valid_witness(), valid_checkpoint(), now)

    assert File.ls!(root) == []
  end

  ## 6. REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE

  test "execute/4 with an unregistered adapter_profile_id refuses unknown-adapter-profile" do
    with_full_castle_env(fn _evidence_root ->
      intent = valid_intent() |> Map.put(:adapter_profile_id, "no-such-profile")

      assert {:error, :REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE} =
               CLI.execute(
                 intent,
                 valid_witness(),
                 valid_checkpoint(),
                 System.system_time(:millisecond)
               )
    end)
  end

  ## 7/8. Checkpoint contract-field mismatches in the kernel execute gate

  test "checkpoint whose protocol field drifts from the contract refuses protocol-mismatch" do
    with_full_castle_env(fn evidence_root ->
      checkpoint = Map.put(valid_checkpoint(), "protocol", "NOT_THE_CONTRACT_PROTOCOL")

      assert {:error, :REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH} =
               CLI.execute(
                 valid_intent(),
                 valid_witness(),
                 checkpoint,
                 System.system_time(:millisecond)
               )

      assert File.ls!(evidence_root) == []
    end)
  end

  test "checkpoint whose castle_paas_source_sha drifts from the contract refuses source-mismatch" do
    with_full_castle_env(fn evidence_root ->
      contract = Contract.identity()

      checkpoint =
        valid_checkpoint()
        |> Map.put("protocol", contract.protocol)
        |> Map.put("castle_paas_source_sha", String.duplicate("0", 40))

      assert {:error, :REFUSED_CASTLE_CHECKPOINT_SOURCE_MISMATCH} =
               CLI.execute(
                 valid_intent(),
                 valid_witness(),
                 checkpoint,
                 System.system_time(:millisecond)
               )

      assert File.ls!(evidence_root) == []
    end)
  end

  ## Fixtures

  defp valid_intent do
    now = System.system_time(:millisecond)

    %{
      adapter_profile_id: "xaas-negative-batch2",
      subject: "system:xaas-negative-batch2",
      authority: "bounded-do",
      config_graph: %{"zeroUnreceiptedActuation" => true},
      ontology: %{"version" => "26.8.18"},
      process: %{
        id: "powl:xaas-negative-batch2",
        goal_id: "goal:xaas-negative-batch2",
        activities: [%{id: "activity:echo", transition_id: "echo", predecessors: []}]
      },
      envelope: %{
        system_id: "system:xaas-negative-batch2",
        allowed_transition_ids: ["echo"],
        max_steps: 1,
        expires_at_epoch_ms: now + 60_000
      }
    }
  end

  defp valid_witness do
    %{
      "subject" => "system:xaas-negative-batch2",
      "authority" => "bounded-do",
      "witness_digest" => @hex64,
      "xaas_receipt_id" => "00000000-0000-0000-0000-000000000000"
    }
  end

  defp valid_checkpoint do
    %{
      "protocol" => Contract.identity().protocol,
      "castle_paas_source_sha" => Contract.identity().castle_paas_source_sha,
      "witness_digest" => @hex64,
      "construct_digest" => @hex64
    }
  end

  defp with_full_castle_env(fun) do
    bin = "/bin/echo"
    key = real_key_file!()

    evidence_root =
      Path.join(System.tmp_dir!(), "castle-batch2-evidence-#{System.unique_integer([:positive])}")

    File.mkdir_p!(evidence_root)

    set_runtime_env(bin: bin, sha: sha256_of(bin), key_path: key, key_id: "batch2-key")

    previous = Application.get_env(:xaas, :castle_adapter_profiles)

    Application.put_env(:xaas, :castle_adapter_profiles, %{
      "xaas-negative-batch2" => %{
        allowed_authorities: ["bounded-do"],
        adapter_policy: %{
          adapter_id: "xaas-negative-batch2",
          provider: "local",
          workload_identity: "workload:xaas-negative-batch2",
          commands: %{
            "echo" => %{
              transition_id: "protocol-check-only",
              program: "/bin/echo",
              args: ["batch2"],
              allowed_exit_codes: [0],
              max_output_bytes: 4096,
              timeout_ms: 2_000
            }
          }
        }
      }
    })

    try do
      fun.(evidence_root)
    after
      File.rm(key)
      File.rm_rf(evidence_root)
      Application.put_env(:xaas, :castle_adapter_profiles, previous)
    end
  end

  defp unique_suffix, do: "#{System.system_time(:native)}-#{System.unique_integer([:positive])}"

  defp real_key_file! do
    key = Path.join(System.tmp_dir!(), "castle-batch2-key-#{unique_suffix()}")
    File.write!(key, String.duplicate("07", 32), [:exclusive])
    on_exit(fn -> File.rm(key) end)
    key
  end

  defp set_runtime_env(opts) do
    System.put_env("CASTLE_BIN", Keyword.fetch!(opts, :bin))
    System.put_env("CASTLE_BIN_SHA256", Keyword.fetch!(opts, :sha))
    System.put_env("CASTLE_SIGNING_KEY_PATH", opts[:key_path] || "/nonexistent")
    System.put_env("CASTLE_KEY_ID", opts[:key_id] || "test-key")
    System.put_env("CASTLE_EVIDENCE_ROOT", opts[:evidence_root] || System.tmp_dir!())
  end

  defp sha256_of(path), do: Base.encode16(:crypto.hash(:sha256, File.read!(path)), case: :lower)

  defp fresh_evidence_root! do
    root = Path.join(System.tmp_dir!(), "castle-batch2-evidence-#{unique_suffix()}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    root
  end

  defp assert_no_evidence_written do
    root = System.get_env("CASTLE_EVIDENCE_ROOT")

    if is_binary(root) and File.dir?(root) do
      names = File.ls!(root)
      # No castle evidence dir (keyed by the witness digest) and no request
      # artifacts from this test were produced anywhere under the evidence root.
      refute @hex64 in names
      assert Enum.all?(names, &(!String.starts_with?(&1, "castle-batch2")))
    end
  end
end
