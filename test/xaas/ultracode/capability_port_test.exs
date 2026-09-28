defmodule Xaas.Ultracode.CapabilityPortTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the agent-facing SA2A capability port
  (`Xaas.Ultracode.CapabilityPort`). Sources are REAL, simple
  implementations of the court's `Source` behaviour, injected through the
  court's own config seam (`:ultracode_capability_sources`, put/restored
  per test -- hence async: false). The negative-bypass case drives the REAL
  `Source.Sa2a` over a real TCP connect to a dead port.
  """

  alias Xaas.Ultracode.CapabilityPort
  alias Xaas.Ultracode.CapabilityResolver.Source.Sa2a
  alias Xaas.Ultracode.RuntimeSurface

  defmodule HoldsSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do:
        {:ok,
         [
           %{capability_id: "recipe:mix-format", satisfies: ["recipe:mix-format"]},
           %{capability_id: "sa2a:publish_change", satisfies: ["sa2a:publish_change"]}
         ]}
  end

  defmodule EmptySource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: {:ok, []}
  end

  @lease_ctx %{
    "lease_token" => "lease-tok-1",
    "epoch_id" => "epoch-1",
    "run_id" => "run-1",
    "provider" => "zcode",
    "worker_id" => "worker-1",
    "repo" => "seanchatmangpt/xaas",
    "base_sha" => "1111111111111111111111111111111111111111",
    "branch" => "v26.9.27/closure-runtime",
    "cwd" => "/tmp/lease-cwd",
    "work_id" => "XAAS-26927-01"
  }

  setup do
    keys = [:ultracode_capability_sources, :ultracode_sa2a_capability_endpoint]
    saved = Map.new(keys, &{&1, Application.fetch_env(:xaas, &1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {key, {:ok, value}} -> Application.put_env(:xaas, key, value)
        {key, :error} -> Application.delete_env(:xaas, key)
      end)
    end)

    tmp = Path.join(System.tmp_dir!(), "capability-port-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, gap_path: Path.join(tmp, "gaps.ndjson")}
  end

  defp sources(map), do: Application.put_env(:xaas, :ultracode_capability_sources, map)

  test "a held capability binds a handle whose subject comes from the lease", %{gap_path: gap} do
    sources(%{"local" => HoldsSource})

    wire = %{"subject" => %{"repo" => "seanchatmangpt/xaas"}, "note" => "fmt"}

    assert {:ok, handle} =
             CapabilityPort.resolve(@lease_ctx, "recipe:mix-format", wire, gap_path: gap)

    assert handle["state"] == "bound"
    assert handle["capability_id"] == "recipe:mix-format"
    assert handle["requested"] == "recipe:mix-format"

    assert handle["subject"] == %{
             "repo" => "seanchatmangpt/xaas",
             "base_sha" => @lease_ctx["base_sha"],
             "branch" => @lease_ctx["branch"]
           }

    assert handle["authority_requirement"] == "none"
    assert handle["invocation_contract"] == "local"
    assert handle["lease_token"] == "lease-tok-1"
    assert handle["work_id"] == "XAAS-26927-01"
    assert handle["provenance"]["resolution_class"] == "reuse"
    assert handle["provenance"]["policy_digest"] == RuntimeSurface.policy_digest()
    assert handle["provenance"]["receipt"]["class"] == "reuse"
    assert handle["provenance"]["receipt"]["selected_capabilities"] == ["recipe:mix-format"]
    refute File.exists?(gap)
  end

  test "a consequential capability is only invocable via BRCE actuate", %{gap_path: gap} do
    sources(%{"local" => HoldsSource})

    assert {:ok, handle} =
             CapabilityPort.resolve(@lease_ctx, "sa2a:publish_change", %{}, gap_path: gap)

    assert handle["authority_requirement"] == "brce"
    assert handle["invocation_contract"] == "actuate"
  end

  test "NEGATIVE BYPASS: dead SA2A endpoint => CAPABILITY_UNAVAILABLE, gap, no provider path",
       %{gap_path: gap} do
    sources(%{"sa2a" => Sa2a})
    Application.put_env(:xaas, :ultracode_sa2a_capability_endpoint, "http://127.0.0.1:1/")

    assert {:error, failure} =
             CapabilityPort.resolve(@lease_ctx, "recipe:mix-format", %{}, gap_path: gap)

    assert failure["code"] == "CAPABILITY_UNAVAILABLE"
    assert failure["details"]["sources"]["sa2a"]["status"] == "error"

    assert failure["details"]["sources"]["sa2a"]["detail"]["code"] ==
             "CAPABILITY_UNAVAILABLE"

    assert [line] = gap |> File.read!() |> String.split("\n", trim: true)
    entry = Jason.decode!(line)
    assert entry["capability"] == "recipe:mix-format"
    assert entry["code"] == "CAPABILITY_UNAVAILABLE"
    assert entry["work_id"] == "XAAS-26927-01"
    assert entry["repo"] == "seanchatmangpt/xaas"
    assert is_binary(entry["at"])

    # The port exposes no provider/fallback entry point.
    functions = Keyword.keys(CapabilityPort.__info__(:functions))

    for forbidden <- [:invoke, :call_provider, :fallback, :fetch, :request] do
      refute forbidden in functions
    end

    # And the external world stays refused after the failure.
    assert {:error, {:forbidden_external_semantic_edge, %{"to" => "WebFetch"}}} =
             RuntimeSurface.admit_tool("WebFetch", nil)
  end

  test "a fully witnessed closure with no satisfier => NO_CAPABILITY + gap", %{gap_path: gap} do
    sources(%{"local" => EmptySource})

    assert {:error, %{"code" => "NO_CAPABILITY", "details" => details}} =
             CapabilityPort.resolve(@lease_ctx, "recipe:absent-thing", %{}, gap_path: gap)

    assert details["resolution_class"] == "frontier"
    assert %{"recipe:absent-thing" => 1} = CapabilityPort.gap_stats(gap)
  end

  test "zero counted sources => NO_CAPABILITY (no source answered)", %{gap_path: gap} do
    sources(%{})

    assert {:error,
            %{"code" => "NO_CAPABILITY", "details" => %{"reason" => "no_source_answered"}}} =
             CapabilityPort.resolve(@lease_ctx, "recipe:mix-format", %{}, gap_path: gap)
  end

  test "a wire subject disagreeing with the lease => PROVENANCE_MISMATCH", %{gap_path: gap} do
    sources(%{"local" => HoldsSource})
    claimed = %{"subject" => %{"repo" => "seanchatmangpt/xaas", "base_sha" => "2222"}}

    assert {:error, %{"code" => "PROVENANCE_MISMATCH", "details" => details}} =
             CapabilityPort.resolve(@lease_ctx, "recipe:mix-format", claimed, gap_path: gap)

    assert details["keys"] == ["base_sha"]
    assert details["bound"] == %{"base_sha" => @lease_ctx["base_sha"]}
    assert details["claimed"] == %{"base_sha" => "2222"}
    refute File.exists?(gap)
  end

  describe "check_handle/2" do
    setup %{gap_path: gap} do
      sources(%{"local" => HoldsSource})
      {:ok, handle} = CapabilityPort.resolve(@lease_ctx, "recipe:mix-format", %{}, gap_path: gap)
      {:ok, handle: handle}
    end

    test "live lease, same subject => :ok", %{handle: handle} do
      assert :ok = CapabilityPort.check_handle(handle, {:ok, @lease_ctx})
    end

    test "expired lease => UNAUTHORIZED revoked", %{handle: handle} do
      assert {:error, %{"code" => "UNAUTHORIZED", "details" => %{"reason" => "revoked"}}} =
               CapabilityPort.check_handle(handle, {:error, :lease_expired})
    end

    test "different lease token => UNAUTHORIZED revoked", %{handle: handle} do
      other = Map.put(@lease_ctx, "lease_token", "lease-tok-2")

      assert {:error, %{"code" => "UNAUTHORIZED", "details" => details}} =
               CapabilityPort.check_handle(handle, {:ok, other})

      assert details["reason"] == "revoked"
      assert details["cause"] == "lease_token_mismatch"
    end

    test "moved base => STALE_SUBJECT", %{handle: handle} do
      moved = Map.put(@lease_ctx, "base_sha", "3333333333333333333333333333333333333333")

      assert {:error, %{"code" => "STALE_SUBJECT", "details" => details}} =
               CapabilityPort.check_handle(handle, {:ok, moved})

      assert details["bound"] == @lease_ctx["base_sha"]
      assert details["observed"] == moved["base_sha"]
    end
  end

  test "gap_stats counts repeated gaps per capability", %{gap_path: gap} do
    for _ <- 1..3,
        do: CapabilityPort.record_gap(%{"capability" => "a:x", "code" => "X"}, gap_path: gap)

    CapabilityPort.record_gap(%{"capability" => "b:y", "code" => "X"}, gap_path: gap)

    assert CapabilityPort.gap_stats(gap) == %{"a:x" => 3, "b:y" => 1}
    assert CapabilityPort.gap_stats(gap <> ".missing") == %{}
  end
end
