defmodule Xaas.Fabric.CastleAliveTest do
  @moduledoc """
  CASTLE ALIVE: the first Chicago closure test of the capability fabric. One consequential
  operation crosses five planes through `Xaas.Fabric` with every plane real: AshR2RML VKG
  projection, the AshGraphLaw WASM engine, the AshAffidavit WASM engine (evidence and
  conformance), and the real CASTLE binary via the receipted `Xaas.Castle` bridge on real
  Postgres. Named exception: the VKG source runner is `Xaas.Test.VKGObservationEngine`, the
  repository's own injected-runner implementation (a real R2RML SQL runner needs an external
  engine). Assertions are on final state, never on interaction counts.
  """
  use ExUnit.Case, async: false

  alias Xaas.Fabric
  alias Xaas.Fabric.{Failure, Planes}
  alias Xaas.Operations.ActuationReceipt

  @moduletag :castle_kernel

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    setup_castle!()
    :ok
  end

  defp setup_castle! do
    bin = Path.expand("~/castle/target/debug/castle")
    sha = bin |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
    System.put_env("CASTLE_BIN", bin)
    System.put_env("CASTLE_BIN_SHA256", sha)

    n = System.unique_integer([:positive, :monotonic])
    key = Path.join(System.tmp_dir!(), "fabric-castle-key-#{n}.hex")
    File.write!(key, String.duplicate("09", 32), [:exclusive])
    System.put_env("CASTLE_SIGNING_KEY_PATH", key)
    System.put_env("CASTLE_KEY_ID", "fabric-castle-test-key")

    root = Path.join(System.tmp_dir!(), "fabric-castle-evidence-#{n}") |> Path.expand()
    File.mkdir_p!(root)
    System.put_env("CASTLE_EVIDENCE_ROOT", root)

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
      File.rm(key)
      File.rm_rf(root)
      for k <- ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT), do: System.delete_env(k)

      if is_nil(previous),
        do: Application.delete_env(:xaas, :castle_adapter_profiles),
        else: Application.put_env(:xaas, :castle_adapter_profiles, previous)
    end)
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

  defp env(amount, authority \\ "bounded-do") do
    id = "op-#{System.unique_integer([:positive])}"

    %{
      operation_id: id,
      subject: "payment:#{id}",
      intent: "discharge obligation by transfer",
      authority: authority,
      amount: amount
    }
  end

  defp planes(amount, overrides \\ %{}) do
    rows = %{"order" => [%{"subject" => "urn:order:10", "customer" => "urn:party:1", "amount" => to_string(amount)}]}

    base = %{
      projection: [{Planes.Projection, vkg: [engine: Xaas.Test.VKGObservationEngine, rows_by_contract: rows]}],
      process: [{Planes.Process, []}],
      law: [{Planes.Law, max_amount_minor: 500_000}],
      evidence: [{Planes.Evidence, []}],
      actuation: [{Planes.Actuation, intent: castle_intent(), allowed_authorities: ["bounded-do"]}]
    }

    Map.merge(base, overrides)
  end

  test "valid operation: evidenced standing, exactly one DO, independently observed" do
    e = env(470_000)
    out = Fabric.run(e, planes(470_000))

    assert out.refusal == nil, inspect(out.refusal)
    assert out.stages == [:requested, :qualified, :constructed, :executed, :observed, :receipted, :reconciled]
    assert out.standing == :evidenced
    assert out.do_crossings == 1
    assert out.facts["actuation.result"].status == :succeeded
    assert out.facts["actuation.observed"]["receipt_durable"] == true
    assert Map.keys(out.served_by) |> Enum.sort() == [:actuation, :evidence, :law, :process, :projection]
    assert [_ | _] = Ash.read!(ActuationReceipt, authorize?: false)
  end

  test "over-limit is nonconstructible: law refuses, no DO, no receipt row" do
    before = length(Ash.read!(ActuationReceipt, authorize?: false))
    out = Fabric.run(env(900_000), planes(900_000))

    assert out.standing == :refused
    assert out.refusal.class == :semantic_refusal
    refute :constructed in out.stages
    assert out.do_crossings == 0
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == before
  end

  test "authority not held by the actuator is refused before DO" do
    out = Fabric.run(env(1_000, "somebody-else"), planes(1_000))
    assert out.standing == :refused
    assert out.refusal.class == :authority_refusal
    assert out.do_crossings == 0
  end

  test "withheld receipt: DO happened, standing stays unknown" do
    pl = planes(5_000, %{evidence: [{Planes.Evidence, withhold: true}]})
    out = Fabric.run(env(5_000), pl)
    assert :executed in out.stages
    refute :receipted in out.stages
    assert out.standing == :unknown
    assert out.refusal.class == :evidence_insufficient
  end

  test "missing plane is capability_unavailable, nothing attempted" do
    out = Fabric.run(env(1_000), Map.delete(planes(1_000), :evidence))
    assert out.refusal.class == :capability_unavailable
    assert out.do_crossings == 0
  end

  test "transient realization failure fails over on observe, never on DO" do
    defmodule FlakyProjection do
      @behaviour Xaas.Fabric.Plane
      def contract, do: %{Planes.Projection.contract() | realization: "flaky-projection"}
      def call(:observe, _e, _f, _o), do: {:error, {:trap, %{class: :blocked_resource}}}
    end

    defmodule FlakyActuator do
      @behaviour Xaas.Fabric.Plane
      def contract, do: %{Planes.Actuation.contract() | realization: "flaky-actuator"}
      def call(:construct, _e, f, _o), do: {:ok, f}
      def call(:execute, _e, _f, _o), do: {:error, {:trap, %{class: :blocked_resource}}}
      def call(_s, _e, _f, _o), do: {:error, :unsupported}
    end

    base = planes(1_000)
    pl = %{base | projection: [{FlakyProjection, []} | base.projection]}
    out = Fabric.run(env(1_000), pl)
    assert out.standing == :evidenced
    assert out.served_by.projection == "xaas-vkg"

    pl2 = %{base | actuation: [{FlakyActuator, []} | base.actuation]}
    out2 = Fabric.run(env(1_000), pl2)
    assert out2.refusal.class == :realization_failed
    assert out2.do_crossings == 1
    refute :executed in out2.stages
  end

  test "a nonconforming process history blocks evidenced standing" do
    defmodule DriftingProcess do
      @behaviour Xaas.Fabric.Plane
      def contract, do: %{Planes.Process.contract() | realization: "drifting-process"}

      # Records an event the model never allows, right after execution.
      def call(:observe, env, %{"process.event" => "executed"} = f, o) do
        {:ok, f} = Planes.Process.call(:observe, env, f, o)
        Planes.Process.call(:observe, env, Map.put(f, "process.event", "refunded"), o)
      end

      def call(stage, env, f, o), do: Planes.Process.call(stage, env, f, o)
    end

    out = Fabric.run(env(1_000), planes(1_000, %{process: [{DriftingProcess, []}]}))
    assert :receipted in out.stages
    refute :reconciled in out.stages
    assert out.standing == :unknown
    assert out.facts["process.conformance"]["conforms"] == false
  end

  test "stage above a realization's ceiling is refused" do
    assert Xaas.Fabric.Plane.permit(Planes.Law.contract(), :construct)
    refute Xaas.Fabric.Plane.permit(Planes.Law.contract(), :execute)
    refute Xaas.Fabric.Plane.permit(Planes.Projection.contract(), :construct)
  end

  test "four refusal shapes normalize to one taxonomy" do
    assert %{class: :semantic_refusal} = Failure.normalize(%{class: :refused_admission}, :law)
    assert %{class: :authority_refusal} = Failure.normalize(%{class: :refused_authority}, :law)
    assert %{class: :realization_failed, transient?: true} = Failure.normalize({:trap, %{class: :trap}}, :evidence)
    assert %{class: :unsupported} = Failure.normalize({:unsupported, %{class: :unsupported}}, :evidence)
    assert %{class: :semantic_refusal} = Failure.normalize("REFUSED:PAYMENT_AMOUNT_ZERO", :castle)
    assert %{class: :realization_failed} = Failure.normalize({:BLOCKED_CASTLE_RUNTIME_CONFIGURATION, nil}, :castle)
  end

  test "castle's envelope source names no concrete realization" do
    src = File.read!(Path.expand("~/castle/src/operation_envelope.rs"))
    for banned <- ["payments::", "Fixture", "ash_", "Registry", "Orchestrator"], do: refute(src =~ banned)
  end
end
