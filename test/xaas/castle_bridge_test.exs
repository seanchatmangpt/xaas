defmodule Xaas.CastleBridgeTest do
  @moduledoc """
  Chicago-style qualification of the XaaS -> CASTLE bridge.

  The default test proves the private action cannot be reached with `authorize?: false`
  alone. The `:castle_kernel` court uses real Postgres, real XaaS Ash/Reactor, and the
  exact compiled CASTLE binary supplied by the dedicated cross-repo workflow. The
  immutable bridge identity is injected by the pinned ggen-marketplace pack before
  that court runs; this test consumes the runtime contract instead of duplicating SHA
  or protocol literals.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{ActuationReceipt, RouteCastleRun}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp intent(now_epoch_ms) do
    %{
      adapter_profile_id: "xaas-local-proof",
      subject: "system:xaas-castle-proof",
      authority: "bounded-do",
      config_graph: %{"zeroUnreceiptedActuation" => true},
      ontology: %{"version" => "26.8.18"},
      process: %{
        id: "powl:xaas-castle-proof",
        goal_id: "goal:xaas-castle-proof",
        activities: [
          %{id: "activity:echo", transition_id: "echo", predecessors: []}
        ]
      },
      envelope: %{
        system_id: "system:xaas-castle-proof",
        allowed_transition_ids: ["echo"],
        max_steps: 1,
        expires_at_epoch_ms: now_epoch_ms + 60_000
      }
    }
  end

  test "direct private action is refused without a real XaaS Reactor receipt" do
    input =
      Ash.ActionInput.for_action(
        RouteCastleRun,
        :execute,
        %{intent: intent(System.system_time(:millisecond))}
      )

    assert {:error, error} = Ash.run_action(input, authorize?: false)
    assert inspect(error) =~ "REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED"
  end

  @tag :castle_kernel
  test "real XaaS actuation nests exact CASTLE BRCE receipts and replays without a second DO" do
    bin = System.fetch_env!("CASTLE_BIN")
    expected_sha = System.fetch_env!("CASTLE_BIN_SHA256")

    actual_sha =
      bin
      |> File.read!()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    assert actual_sha == String.downcase(expected_sha)

    signing_key_path =
      Path.join(
        System.tmp_dir!(),
        "xaas-castle-key-#{System.unique_integer([:positive, :monotonic])}.hex"
      )

    File.write!(signing_key_path, String.duplicate("09", 32), [:exclusive])
    System.put_env("CASTLE_SIGNING_KEY_PATH", signing_key_path)
    System.put_env("CASTLE_KEY_ID", "xaas-castle-test-key")

    evidence_root =
      Path.join(
        System.tmp_dir!(),
        "xaas-castle-evidence-#{System.unique_integer([:positive, :monotonic])}"
      )
      |> Path.expand()

    File.mkdir_p!(evidence_root)
    System.put_env("CASTLE_EVIDENCE_ROOT", evidence_root)

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
            args: ["xaas-castle-bridge"],
            allowed_exit_codes: [0],
            max_output_bytes: 4096,
            timeout_ms: 2_000
          }
        }
      }
    }

    previous_profiles = Application.get_env(:kanban, :castle_adapter_profiles)
    Application.put_env(:kanban, :castle_adapter_profiles, %{"xaas-local-proof" => profile})

    on_exit(fn ->
      File.rm(signing_key_path)
      File.rm_rf(evidence_root)
      System.delete_env("CASTLE_SIGNING_KEY_PATH")
      System.delete_env("CASTLE_KEY_ID")
      System.delete_env("CASTLE_EVIDENCE_ROOT")

      if is_nil(previous_profiles),
        do: Application.delete_env(:kanban, :castle_adapter_profiles),
        else: Application.put_env(:kanban, :castle_adapter_profiles, previous_profiles)
    end)

    key = "xaas-castle-#{System.unique_integer([:positive])}"
    request = intent(System.system_time(:millisecond))
    authority = %{kind: "xaas_reactor", source: "castle_bridge_test", scope: "castle.run"}

    assert {:ok, first} =
             Xaas.Castle.run(request,
               idempotency_key: key,
               authority: authority
             )

    assert first.status == :succeeded
    refute first.replay?
    assert first.receipt.status == :succeeded
    assert first.receipt.ontology_projection_hash == RouteCastleRun.ontology_projection_hash()
    assert first.result["standing"] == "ALIVE"
    assert byte_size(first.result["construct_digest"]) == 64
    assert byte_size(first.result["construct_receipt_digest"]) == 64
    assert length(first.result["brce_prepare_receipt_digests"]) == 1
    assert length(first.result["brce_outcome_receipt_digests"]) == 1
    assert first.result["evidence_commit"]["standing"] == "ALIVE"
    assert byte_size(first.result["xaas_outer_admission"]["witness_digest"]) == 64

    contract = Xaas.Castle.Contract.identity()
    assert is_atom(contract.protocol)
    assert first.result["contract"]["protocol"] == Atom.to_string(contract.protocol)
    assert first.result["contract"]["castle_paas_source_sha"] == contract.castle_paas_source_sha
    assert first.result["contract"]["castle_paas_pack_sha"] == contract.castle_paas_pack_sha
    assert first.result["contract"]["ash_r2rml_sha"] == contract.ash_r2rml_sha

    receipt_count = length(Ash.read!(ActuationReceipt, authorize?: false))

    assert {:ok, replay} =
             Xaas.Castle.run(request,
               idempotency_key: key,
               authority: authority
             )

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == first.receipt.id
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == receipt_count
  end

  @tag :castle_kernel
  test "caller-supplied provider command policy is refused before CASTLE actuation" do
    request =
      intent(System.system_time(:millisecond))
      |> Map.put(:adapter_policy, %{commands: %{"echo" => %{program: "/bin/false"}}})

    assert {:error, error} =
             Xaas.Castle.run(request,
               idempotency_key: "xaas-castle-ambient-#{System.unique_integer([:positive])}",
               authority: %{kind: "xaas_reactor", scope: "castle.run"}
             )

    assert inspect(error) =~ "REFUSED_AMBIENT_CASTLE_COMMAND_POLICY"
  end
end
