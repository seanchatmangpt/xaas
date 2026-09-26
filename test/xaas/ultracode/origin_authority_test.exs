defmodule Xaas.Ultracode.OriginAuthorityTest do
  @moduledoc """
  Chicago-style qualification of the origin-authority backfill (v26.9.25
  post-tag hardening, X1) against ggen_igniter's G1 origin trust-root pin law
  (ggen_igniter 647db5f208b7ec88c84f0dc7d70925b4dec330f9).

  Two layers, no mocks or stubs:

    * the real XaaS builders -- `SemanticCrown.base_work_order/2`,
      `SemanticCrown.dependent_work_order/3`, `SemanticCrown.observe_args/4`
      and `SemanticDrive.Episode.work_graph/4` -- carry the pinned canonical
      objective and never take a caller- or base-declared origin;
    * with a ggen_igniter checkout that carries the trust roots
      (`GGEN_IGNITER_DIR`, else `~/ggen_igniter`; skipped by name when it has
      no `sj:AuthorityTrustRoot` or no compiled `_build/test`), the real
      graph side as OS processes in that checkout: `mix
      semantic_jira.frontier` admits the builders' orders, blocks the same
      orders with the origin removed, and blocks a self-declared objective
      stamped by the real kernel (`Authority.admit/1`) as
      `authority_not_pinned`; `mix semantic_jira.observe` admits the crown's
      observe call and refuses it without `--origin-authority`.
  """
  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{SemanticCrown, SemanticDrive}
  alias Xaas.Ultracode.SemanticDrive.Episode

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"
  @mvp @sj <> "objective-semantic-jira-mvp"
  @code_work @sj <> "objective-code-work-authority"
  @rogue @sj <> "objective-xaas-self-declared"
  @sha String.duplicate("a", 40)

  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || Path.expand("~/ggen_igniter")
  @ontology Path.join(@ggen_dir, "priv/ggen/semantic-jira-pack/ontology.ttl")
  @ggen_ready File.regular?(@ontology) and
                File.read!(@ontology) =~ "a sj:AuthorityTrustRoot" and
                File.dir?(Path.join(@ggen_dir, "_build/test/lib/ggen_igniter"))

  defp item(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "contract-evidence-receipt",
        "goal" => "Add three negative fixtures to the evidence-receipt contract schema.",
        "allowed_paths" => ["tests/test_contract_evidence_receipt.py"]
      },
      overrides
    )
  end

  defp ctx, do: %{base_sha: @sha}

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  # ------------------------------------------------------------------ builders

  test "the crown's base WorkOrder originates from the pinned SJ MVP objective" do
    assert SemanticCrown.origin_authority() == @mvp
    base = SemanticCrown.base_work_order(ctx(), item())
    assert base["origin_authority"] == @mvp
    assert base["base_sha"] == @sha
  end

  test "an APS item cannot declare the crown base's origin" do
    base = SemanticCrown.base_work_order(ctx(), item(%{"origin_authority" => @rogue}))
    assert base["origin_authority"] == @mvp
  end

  test "the dependent WorkOrder sets its own origin: never inherited, never taken from base" do
    base = SemanticCrown.base_work_order(ctx(), item())

    for declared <- [
          Map.delete(base, "origin_authority"),
          Map.put(base, "origin_authority", @rogue)
        ] do
      dependent = SemanticCrown.dependent_work_order(ctx(), declared, item())
      assert dependent["origin_authority"] == @mvp
      assert dependent["identity"] == "SJ-CROWN-B"
    end
  end

  test "the observe call binds the observation to the pinned origin (INVARIANT A)" do
    args = SemanticCrown.observe_args("f.json", "b.json", "o.ttl", "c.json")
    assert [_, @mvp | _] = Enum.drop_while(args, &(&1 != "--origin-authority"))
    assert Enum.count(args, &(&1 == "--origin-authority")) == 1
  end

  test "both episode orders originate from the pinned code-work objective" do
    assert Episode.origin_authority() == @code_work
    graph = Episode.work_graph("x1", @sha, "lib/ggen_igniter.ex")
    assert [%{"identity" => "EP-A"} = a, %{"identity" => "EP-B"} = b] = graph["work_orders"]
    assert a["origin_authority"] == @code_work
    assert b["origin_authority"] == @code_work
  end

  # ------------------------------------------------------------------ the real graph side

  describe "the real G1 kernel in the ggen_igniter checkout" do
    if not @ggen_ready do
      @describetag skip:
                     "ggen_igniter checkout #{@ggen_dir} has no sj:AuthorityTrustRoot pins or no compiled _build/test"
    end

    @tag timeout: 600_000
    test "both chosen objectives are pinned trust roots of the canonical ontology" do
      ontology = File.read!(@ontology)

      for iri <- [@mvp, @code_work] do
        local = String.replace_prefix(iri, @sj, "")

        assert ontology =~
                 ~r/sj:trust-root-#{local} a sj:AuthorityTrustRoot ;\s+[^.]*sj:authorityIri sj:#{local} ;/
      end

      refute ontology =~ "objective-xaas-self-declared"
    end

    @tag timeout: 600_000
    test "frontier: the episode's EP-A is eligible with its pinned origin digest; removed origin is blocked" do
      graph = Episode.work_graph("x1", @sha, "lib/ggen_igniter.ex")
      [a, b] = graph["work_orders"]

      assert {0, frontier} = frontier([a, b])
      assert [%{"identity" => "EP-A"} = eligible] = frontier["eligible"]
      assert eligible["origin_authority"] == @code_work
      assert "sha256:" <> _ = eligible["origin_admission_digest"]

      assert {0, frontier} = frontier([Map.delete(a, "origin_authority")])
      assert frontier["eligible"] == []
      assert [%{"reason" => reason}] = frontier["blocked"]
      assert reason =~ ~s(missing_required_field, "origin_authority")
    end

    @tag timeout: 600_000
    test "frontier: a self-declared objective stamped by the real kernel is refused authority_not_pinned" do
      dir = tmp_dir("x1_rogue")
      authority = Path.join(dir, "authority.ttl")
      script = Path.join(dir, "stamp.exs")

      File.write!(script, """
      [out, rogue] = System.argv()
      sj = "#{@sj}"

      graph =
        RDF.Graph.new([
          {RDF.iri(rogue), RDF.type(), RDF.iri(sj <> "StrategicObjective")},
          {RDF.iri(rogue), RDF.iri("http://www.w3.org/2000/01/rdf-schema#label"),
           RDF.literal("XaaS self-declared objective")}
        ])

      {:ok, stamped, _report} = GgenIgniter.SemanticJira.Authority.admit(graph)
      %{admitted: %{^rogue => _}} = GgenIgniter.SemanticJira.Authority.index(stamped)
      File.write!(out, RDF.Turtle.write_string!(stamped))
      """)

      assert {_, 0} = mix(["run", "--no-start", script, authority, @rogue])
      assert File.read!(authority) =~ "admissionDigest"

      [a, _b] = Episode.work_graph("x1", @sha, "lib/ggen_igniter.ex")["work_orders"]
      rogue = Map.put(a, "origin_authority", @rogue)

      assert {0, frontier} = frontier([rogue], authority)
      assert frontier["eligible"] == []
      assert [%{"identity" => "EP-A"} = blocked] = frontier["blocked"]
      assert blocked["refusal"] == ["authority_not_pinned", @rogue]

      # The same caller graph does not unpin the canonical objective.
      assert {0, frontier} = frontier([a], authority)
      assert frontier["eligible"] == []
    end

    @tag timeout: 600_000
    test "frontier: the crown's base WorkOrder is admitted; without origin it is blocked" do
      base = SemanticCrown.base_work_order(ctx(), item())

      assert {0, frontier} = frontier([base])
      assert [%{"identity" => "SJ-CROWN-BASE"} = eligible] = frontier["eligible"]
      assert eligible["origin_authority"] == @mvp

      assert {0, frontier} = frontier([Map.delete(base, "origin_authority")])
      assert frontier["eligible"] == []
      assert [%{"reason" => reason}] = frontier["blocked"]
      assert reason =~ ~s(missing_required_field, "origin_authority")
    end

    @tag timeout: 600_000
    test "observe: the crown's observe call is admitted; without --origin-authority it is refused" do
      dir = tmp_dir("x1_observe")
      finding = Path.join(dir, "finding.json")
      base = Path.join(dir, "base.json")
      ontology = Path.join(dir, "ontology.ttl")
      out = Path.join(dir, "candidate.json")
      digest = fn byte -> "sha256:" <> String.duplicate(byte, 64) end

      File.write!(
        finding,
        Jason.encode!(%{
          "normative_model_digest" => digest.("1"),
          "observed_model_digest" => digest.("2"),
          "observation_receipt_digest" => digest.("3"),
          "delta" => "contract-evidence-receipt has < 3 negative fixtures"
        })
      )

      File.write!(base, Jason.encode!(SemanticCrown.base_work_order(ctx(), item())))
      File.write!(ontology, SemanticCrown.admission_ontology(@ggen_dir))

      args = SemanticCrown.observe_args(finding, base, ontology, out)
      assert {output, 0} = mix(["semantic_jira.observe" | args])
      candidate = File.read!(out) |> Jason.decode!()
      assert candidate["work_order"]["origin_authority"] == @mvp, output
      assert candidate["shacl"]["conforms"] == true

      stripped = strip_origin(args)
      refute "--origin-authority" in stripped
      assert {output, 1} = mix(["semantic_jira.observe" | stripped])
      assert output =~ "missing_origin_authority"
    end
  end

  defp strip_origin(["--origin-authority", _iri | rest]), do: rest
  defp strip_origin([arg | rest]), do: [arg | strip_origin(rest)]
  defp strip_origin([]), do: []

  defp frontier(orders, authority \\ nil) do
    dir = tmp_dir("x1_frontier")
    work = Path.join(dir, "work.json")
    ledger = Path.join(dir, "ledger.ndjson")
    File.write!(work, Jason.encode!(orders))
    File.write!(ledger, "")

    args =
      ["semantic_jira.frontier", "--work-orders", work, "--ledger", ledger] ++
        if(authority, do: ["--authority-graph", authority], else: [])

    {out, code} = mix(args)
    {code, last_json(out)}
  end

  # A real `mix` OS process in the ggen_igniter checkout, on the toolchain
  # its own `_build/test` was compiled with (`SemanticDrive.graph_toolchain/2`,
  # the graph side's resolver), with the XaaS node's toolchain and Mix
  # variables unset.
  defp mix(args) do
    build = Path.join(@ggen_dir, "_build/test")
    assert {:ok, toolchain} = SemanticDrive.graph_toolchain(@ggen_dir, build)

    unset =
      ~w(MIX_BUILD_ROOT MIX_DEPS_PATH MIX_EXS MIX_TARGET MIX_HOME MIX_ARCHIVES ROOTDIR BINDIR EMU PROGNAME ASDF_ELIXIR_VERSION ASDF_ERLANG_VERSION ASDF_INSTALL_VERSION ASDF_INSTALL_PATH ASDF_INSTALL_TYPE)

    System.cmd(toolchain["mix"], args,
      cd: @ggen_dir,
      stderr_to_stdout: true,
      env:
        [{"MIX_ENV", "test"}, {"MIX_BUILD_PATH", build}, {"PATH", toolchain["path"]}] ++
          Enum.map(unset, &{&1, nil})
    )
  end

  defp last_json(out) do
    out
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case Jason.decode(String.trim(line)) do
        {:ok, %{} = json} -> json
        _ -> nil
      end
    end)
  end
end
