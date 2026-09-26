defmodule Xaas.Ultracode.RemoteRelayTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.RemoteRelay
  alias Xaas.Ultracode.RemoteRelay.Envelope

  @contract Path.expand("../../../priv/ultracode/remote-relay.contract.json", __DIR__)

  defp state(opts \\ []) do
    RemoteRelay.new_state(
      Keyword.merge([execution_manifest_digest: "manifest", dedup_limit: 2], opts)
    )
  end

  defp envelope(overrides \\ %{}) do
    struct!(
      Envelope,
      Map.merge(
        %{
          command_id: "cmd-1",
          epoch_id: "epoch-1",
          task_id: "task-1",
          sequence: 1,
          intent_digest: "intent",
          exact_subject: "repo@sha",
          verb: :observe,
          execution_manifest_digest: "manifest",
          issued_at: 1,
          expires_at: 10_000,
          channel: :control
        },
        overrides
      )
    )
  end

  defp descriptor(overrides \\ %{}) do
    Map.merge(
      %{
        "schema" => "gall.work-lease/1",
        "work_order_iri" => "urn:gall:work:1",
        "checkpoint_iri" => "urn:gall:checkpoint:1",
        "graph_digest" => "sha256:" <> String.duplicate("a", 64),
        "repository_identity" => "seanchatmangpt/xaas",
        "base_sha" => String.duplicate("b", 40),
        "epoch_id" => "epoch-1",
        "worker_id" => "worker-1",
        "worktree" => "/tmp/xaas"
      },
      overrides
    )
  end

  defp gall_envelope(overrides \\ %{}) do
    d = descriptor()

    envelope(
      Map.merge(
        %{
          task_id: d["work_order_iri"],
          intent_digest: d["graph_digest"],
          exact_subject: d["repository_identity"] <> "@" <> d["base_sha"],
          verb: :actuate,
          authority_ref: "grant-1"
        },
        overrides
      )
    )
  end

  test "machine-readable relay contract pins the executable admission vocabulary" do
    contract = @contract |> File.read!() |> Jason.decode!()

    assert contract["contract"] == "xaas-remote-relay"
    assert contract["contract_version"] == 1
    assert contract["envelope_schema"] == "xaas.remote-relay-envelope/1"
    assert contract["gall_work_binding"]["payload_schema"] == "gall.work-lease/1"
    assert contract["gall_work_binding"]["intent_digest"] == "payload.graph_digest"

    assert Enum.sort(contract["envelope"]["channels"]) == ["control", "observe"]
    assert "EXECUTION_MANIFEST_DRIFT" in contract["refusals"]
    assert "AUTHORITY_REF_REQUIRED" in contract["refusals"]
    assert "KNOWN_REPLAY" in contract["replay"]["after_ack"]

    assert contract["ocel_identity_env"] == [
             "XAAS_LEASE_CWD",
             "XAAS_WORK_ORDER_IRI",
             "XAAS_EPOCH_ID",
             "XAAS_BASE_SHA"
           ]
  end

  test "gall-work admission binds graph, subject, epoch, and work-order identity" do
    env = gall_envelope()
    assert {:ok, _} = RemoteRelay.admit_gall_work(state(), env, descriptor(), 5)
  end

  test "gall-work semantic binding fails closed before generic relay admission" do
    env = gall_envelope()

    assert {:error, :intent_digest_mismatch} =
             RemoteRelay.admit_gall_work(
               state(),
               env,
               descriptor(%{"graph_digest" => "sha256:" <> String.duplicate("c", 64)}),
               5
             )

    assert {:error, :exact_subject_mismatch} =
             RemoteRelay.admit_gall_work(
               state(),
               env,
               descriptor(%{"base_sha" => String.duplicate("c", 40)}),
               5
             )

    assert {:error, :epoch_mismatch} =
             RemoteRelay.admit_gall_work(
               state(),
               env,
               descriptor(%{"epoch_id" => "epoch-2"}),
               5
             )

    assert {:error, :task_mismatch} =
             RemoteRelay.admit_gall_work(
               state(),
               env,
               descriptor(%{"work_order_iri" => "urn:gall:work:2"}),
               5
             )

    assert {:error, :descriptor_schema_mismatch} =
             RemoteRelay.admit_gall_work(
               state(),
               env,
               descriptor(%{"schema" => "gall.work-lease/2"}),
               5
             )
  end

  test "acknowledged transport replay never becomes a fresh command" do
    env = envelope()
    assert {:ok, s0} = RemoteRelay.admit(state(), env, 5)
    assert {:ok, s1} = RemoteRelay.acknowledge(s0, env)
    assert {:replay, ^s1} = RemoteRelay.admit(s1, env, 5)
  end

  test "drop before ack preserves stable actuation idempotency key" do
    env = envelope(%{verb: :actuate, authority_ref: "grant-1"})
    assert {:ok, _} = RemoteRelay.admit(state(), env, 5)
    assert {:ok, args1} = RemoteRelay.bind_actuation_idempotency(env, %{"resource" => "R"})
    assert {:ok, args2} = RemoteRelay.bind_actuation_idempotency(env, %{"resource" => "R"})
    assert args1["idempotency_key"] == "cmd-1"
    assert args2["idempotency_key"] == args1["idempotency_key"]
  end

  test "caller cannot launder a different idempotency identity" do
    env = envelope(%{verb: :actuate, authority_ref: "grant-1"})

    assert {:error, :idempotency_key_mismatch} =
             RemoteRelay.bind_actuation_idempotency(env, %{"idempotency_key" => "other"})
  end

  test "actuate requires authority reference and control channel" do
    assert {:error, :authority_ref_required} =
             RemoteRelay.admit(state(), envelope(%{verb: :actuate}), 5)

    assert {:error, :authority_ref_required} =
             RemoteRelay.admit(
               state(),
               envelope(%{verb: :actuate, channel: :observe, authority_ref: "grant"}),
               5
             )
  end

  test "manifest drift and sequence gaps fail closed" do
    assert {:error, :execution_manifest_drift} =
             RemoteRelay.admit(
               state(),
               envelope(%{execution_manifest_digest: "changed"}),
               5
             )

    assert {:error, :sequence_gap} =
             RemoteRelay.admit(state(), envelope(%{sequence: 2, command_id: "cmd-2"}), 5)
  end

  test "expired commands are refused before execution" do
    assert {:error, :command_expired} =
             RemoteRelay.admit(state(), envelope(%{expires_at: 4}), 5)
  end

  test "dedup memory is bounded while sequence replay stays refused" do
    {:ok, s1} = RemoteRelay.acknowledge(state(), envelope())

    e2 = envelope(%{command_id: "cmd-2", sequence: 2})
    {:ok, s2} = RemoteRelay.acknowledge(s1, e2)

    e3 = envelope(%{command_id: "cmd-3", sequence: 3})
    {:ok, s3} = RemoteRelay.acknowledge(s2, e3)

    assert length(s3.seen_command_ids) == 2
    assert {:replay, ^s3} = RemoteRelay.admit(s3, envelope(), 5)
  end

  test "transport failures remain transport classes" do
    assert :permanent = RemoteRelay.classify_transport_failure(:unauthorized)
    assert :transient = RemoteRelay.classify_transport_failure(:timeout)
    assert :ambiguous = RemoteRelay.classify_transport_failure(:weird)
  end
end
