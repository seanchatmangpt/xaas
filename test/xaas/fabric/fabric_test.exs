defmodule Xaas.Fabric.FabricTest do
  use ExUnit.Case, async: true

  alias Xaas.Fabric.{Contract, Orchestrator, Registry}

  defmodule Proj do
    use Xaas.Fabric.Capability
    def describe, do: %Contract{uri: "capability://projection/map", semantic_id: "proj.v1", realization: "proj", effect_class: :observe}
    def observe(env, f), do: {:ok, Map.put(f, "graph", env.input)}
  end

  defmodule Proc do
    use Xaas.Fabric.Capability
    def describe, do: %Contract{uri: "capability://process/conformance", semantic_id: "proc.v1", realization: "proc", effect_class: :observe}
    def observe(_env, f), do: {:ok, Map.update(f, "events", [f["process.event"]], &(&1 ++ [f["process.event"]]))}
    def receipt(_env, f), do: {:ok, %{"conforms" => f["events"] == ~w(requested constructed executed receipted)}}
  end

  defmodule Law do
    use Xaas.Fabric.Capability
    @inv ["INVALID_IMPLIES_NONCONSTRUCTIBLE"]
    def describe, do: %Contract{uri: "capability://law/admit", semantic_id: "law.v1", realization: "law", effect_class: :construct, invariants: @inv}
    def construct(%{input: %{amount: a}}, f) when a <= 100, do: {:ok, Map.put(f, "admitted", true)}
    def construct(_, _), do: {:error, {:semantic_refusal, :over_limit}}
    def replay(_env, %{"admitted" => true}), do: :ok
    def replay(_env, _), do: {:error, {:semantic_refusal, :diverged}}
  end

  defmodule LawAlt do
    use Xaas.Fabric.Capability
    def describe, do: %{Law.describe() | realization: "law-alt"}
    def construct(env, f), do: Law.construct(env, f)
    def replay(env, r), do: Law.replay(env, r)
  end

  defmodule LawBad do
    use Xaas.Fabric.Capability
    def describe, do: %{Law.describe() | realization: "law-bad", invariants: []}
  end

  defmodule LawFlaky do
    use Xaas.Fabric.Capability
    def describe, do: %{Law.describe() | realization: "law-flaky"}
    def construct(_, _), do: {:error, {:realization_failed, :crashed}}
  end

  defmodule Ev do
    use Xaas.Fabric.Capability
    def describe, do: %Contract{uri: "capability://evidence/attest", semantic_id: "ev.v1", realization: "ev", effect_class: :observe}
    def observe(_env, f), do: {:ok, Map.put(f, "pre", true)}
    def receipt(_env, f), do: {:ok, %{"admitted" => f["admitted"], "settled" => f["settled"], "sig" => :erlang.phash2({f["admitted"], f["settled"]})}}
    def replay(_env, %{"sig" => s} = r), do: if(s == :erlang.phash2({r["admitted"], r["settled"]}), do: :ok, else: {:error, {:evidence_insufficient, :bad}})
  end

  defmodule EvWithheld do
    use Xaas.Fabric.Capability
    def describe, do: %{Ev.describe() | realization: "ev-withheld"}
    def observe(env, f), do: Ev.observe(env, f)
    def receipt(_, _), do: {:error, {:evidence_insufficient, :withheld}}
  end

  defmodule Act do
    use Xaas.Fabric.Capability
    def describe, do: %Contract{uri: "capability://agent/actuate", semantic_id: "act.v1", realization: "act", effect_class: :do}
    def select(%{authority: "ok"}, f), do: {:ok, f}
    def select(_, _), do: {:error, {:authority_refusal, :not_authorized}}
    def execute(_env, f), do: {:ok, Map.put(f, "settled", true)}
    def observe(_env, f), do: {:ok, Map.put(f, "observed", f["settled"] == true)}
  end

  defmodule ActCrash do
    use Xaas.Fabric.Capability
    def describe, do: %{Act.describe() | realization: "act-crash"}
    def select(env, f), do: Act.select(env, f)
    def execute(_, _), do: {:error, {:realization_failed, :crashed}}
  end

  defp reg(mods) do
    Enum.reduce(mods, Registry.new(), fn m, r -> {:ok, r} = Registry.register(r, m); r end)
  end

  defp env(amount, authority \\ "ok"), do: %{operation_id: "op-1", input: %{amount: amount}, authority: authority}

  test "valid operation is alive with one DO and a replayable receipt" do
    r = reg([Proj, Proc, Law, Ev, Act])
    out = Orchestrator.run(r, env(50))
    assert out.refusal == nil
    assert out.stages == [:requested, :qualified, :constructed, :executed, :observed, :receipted, :reconciled]
    assert out.standing == :alive
    assert out.do_crossings == 1
    assert out.facts["observed"] == true
    assert Map.keys(out.served_by) |> Enum.sort() == Orchestrator.uris() |> Map.values() |> Enum.sort()
    assert %{same_decision: true, receipt_valid: true} = Orchestrator.replay(r, env(50), out.receipt)
  end

  test "invalid is nonconstructible: no DO, no settlement" do
    out = Orchestrator.run(reg([Proj, Proc, Law, Ev, Act]), env(500))
    assert out.standing == :refused
    refute :constructed in out.stages
    assert out.do_crossings == 0
    refute Map.has_key?(out.facts, "settled")
  end

  test "authority refusal precedes DO" do
    out = Orchestrator.run(reg([Proj, Proc, Law, Ev, Act]), env(50, "nope"))
    assert out.standing == :refused
    assert out.do_crossings == 0
  end

  test "QRI: equivalent realization swaps in with the same standing; contract breaker is refused" do
    a = Orchestrator.run(reg([Proj, Proc, Law, Ev, Act]), env(50))
    b = Orchestrator.run(reg([Proj, Proc, LawAlt, Ev, Act]), env(50))
    assert {a.standing, a.stages} == {b.standing, b.stages}
    assert b.served_by["capability://law/admit"] == "law-alt"
    {:ok, r} = Registry.register(Registry.new(), Law)
    assert {:error, "REFUSED:QRI_CONTRACT_MISMATCH"} = Registry.register(r, LawBad)
  end

  test "failed realization closes one edge; qualified alternative serves" do
    out = Orchestrator.run(reg([Proj, Proc, LawFlaky, Law, Ev, Act]), env(50))
    assert out.standing == :alive
    assert out.served_by["capability://law/admit"] == "law"
  end

  test "DO never falls over" do
    out = Orchestrator.run(reg([Proj, Proc, Law, Ev, ActCrash, Act]), env(50))
    assert out.do_crossings == 1
    refute :executed in out.stages
    refute Map.has_key?(out.facts, "settled")
  end

  test "execution without receipt has no standing" do
    out = Orchestrator.run(reg([Proj, Proc, Law, EvWithheld, Act]), env(50))
    assert :executed in out.stages
    refute :receipted in out.stages
    assert out.standing == :unknown
  end

  test "missing capability is unavailable" do
    out = Orchestrator.run(reg([Proj, Proc, Law, Act]), env(50))
    assert out.refusal =~ "CAPABILITY_UNAVAILABLE"
    assert out.do_crossings == 0
  end

  test "tampered receipt fails replay; effect class ceiling enforced" do
    r = reg([Proj, Proc, Law, Ev, Act])
    out = Orchestrator.run(r, env(50))
    assert %{receipt_valid: false} = Orchestrator.replay(r, env(50), %{out.receipt | "settled" => false})
    assert {:error, {:authority_refusal, _}} = Contract.permit(Law.describe(), :do)
    assert :ok = Contract.permit(Law.describe(), :construct)
  end
end
