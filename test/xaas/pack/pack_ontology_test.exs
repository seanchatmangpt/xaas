defmodule Xaas.PackOntologyTest do
  @moduledoc """
  Drift guards for the capability pack TTL (source of truth) against the
  handwritten fences it mirrors, in the `Xaas.Tunnel.CapabilitiesOntologyTest`
  pattern (equality plus an anti-vacuity mutation):

    * UltraCode delivery profile REFUSED tools == `Xaas.Ultracode.Lease.refused_consequence_tools/0`
      exactly, each with the Lease's refusal tag (`refused_no_authority`);
    * pack facets == `Xaas.Pack.facets/0`, each on an existing ROADMAP.md plane.
  """

  use ExUnit.Case, async: true

  alias Xaas.Generation.UnsupportedReceipt
  alias Xaas.Pack
  alias Xaas.Ultracode.Lease

  @moduletag :tmp_dir

  @source Path.expand("../../../priv/packs/xaas_capability_pack", __DIR__)
  @ultracode "profiles/ultracode.ttl"

  defp delivery_refused(%Pack{declarations: declarations}) do
    for {_capability, %{"facet" => "DeliveryFacet", "standing" => "REFUSED"} = d} <- declarations,
        do: {d["tool"], d["refusal_reason"]}
  end

  defp copy!(tmp_dir) do
    dir = Path.join(tmp_dir, "pack")
    File.mkdir_p!(tmp_dir)
    File.cp_r!(@source, dir)
    dir
  end

  test "UltraCode delivery REFUSED set equals Lease.refused_consequence_tools/0 exactly" do
    assert {:ok, pack} = Pack.load("ultracode")
    refused = delivery_refused(pack)

    assert refused |> Enum.map(&elem(&1, 0)) |> Enum.sort() ==
             Enum.sort(Lease.refused_consequence_tools())

    assert length(refused) == length(Lease.refused_consequence_tools())
    assert Enum.all?(refused, fn {_tool, reason} -> reason == "refused_no_authority" end)
  end

  test "anti-vacuity: a fourth refused delivery tool is detected", %{tmp_dir: tmp_dir} do
    dir = copy!(tmp_dir)

    File.write!(
      Path.join(dir, @ultracode),
      File.read!(Path.join(dir, @ultracode)) <>
        """

        uc:delivery-deploy a xcp:CapabilityDeclaration ;
          xcp:capability "tool:deploy" ;
          xcp:tool "deploy" ;
          xcp:standing "REFUSED" ;
          xcp:facet xcp:DeliveryFacet ;
          xcp:refusalReason "refused_no_authority" .
        """
    )

    assert {:ok, mutated} = Pack.read(dir, @ultracode)
    tools = mutated |> delivery_refused() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    refute tools == Enum.sort(Lease.refused_consequence_tools())
    assert "deploy" in tools
  end

  test "pack facets equal Pack.facets/0: seven facets on existing ROADMAP planes" do
    assert {:ok, pack} = Pack.load("ultracode")
    assert pack.facets == Pack.facets()
    assert map_size(pack.facets) == 7
    assert Enum.all?(Map.values(pack.facets), &(&1 in 1..9))
  end

  test "anti-vacuity: an eighth facet is detected", %{tmp_dir: tmp_dir} do
    dir = copy!(tmp_dir)
    ontology = Path.join(dir, "ontology.ttl")

    File.write!(
      ontology,
      File.read!(ontology) <>
        """

        xcp:ExtraFacet a xcp:Facet ; xcp:roadmapPlane 9 .
        <https://xaas.dev/pack/xaas_capability_pack> xcp:facet xcp:ExtraFacet .
        """
    )

    assert {:ok, mutated} = Pack.read(dir, @ultracode)
    refute mutated.facets == Pack.facets()
  end

  test "the handwritten court carries its generator-capability residue receipt" do
    assert %UnsupportedReceipt{
             generator_id: "ggen_igniter",
             reason: :admission_court_not_derivable
           } =
             Pack.generator_residue()
  end
end
