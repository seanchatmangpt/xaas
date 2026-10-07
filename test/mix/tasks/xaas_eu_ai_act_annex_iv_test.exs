defmodule Mix.Tasks.Xaas.EuAiActAnnexIvTest do
  @moduledoc """
  Court for `mix xaas.eu_ai_act_annex_iv`: the generated Annex-IV document
  must project the REAL capability surface — every cited source path exists
  on disk, the required Annex IV sections are present, and generation is
  deterministic (two runs byte-identical).
  """

  use ExUnit.Case, async: false

  @task Mix.Tasks.Xaas.EuAiActAnnexIv

  defp write_doc!(suffix) do
    path = Path.join(System.tmp_dir!(), "annex_iv_w504_#{suffix}.json")
    File.rm(path)
    doc = @task.build()
    File.write!(path, Jason.encode!(doc, pretty: true) <> "\n")
    {path, doc}
  end

  test "generates to a caller-specified path with all Annex IV sections" do
    {path, doc} = write_doc!("sections")

    on_exit(fn -> File.rm(path) end)

    assert File.exists?(path)

    for section <- ["identity", "capabilities", "human_oversight", "logging", "accuracy_robustness"] do
      assert Map.has_key?(doc, section), "missing Annex IV section: #{section}"
    end

    assert doc["artifact"] =~ "Annex IV"
    assert doc["functor"] == "D: Ont -> Doc"
  end

  test "identity section carries real version and generator identity" do
    {_path, doc} = write_doc!("identity")
    version = File.read!("VERSION") |> String.trim()
    contract = Jason.decode!(File.read!("priv/ash_surface/surface_contract.json"))

    assert doc["identity"]["version"] == version
    assert doc["identity"]["generator_identity"] == contract["generatorIdentity"]
    assert doc["identity"]["surface_digest"] == contract["surfaceDigest"]
  end

  test "capabilities inventory matches the real surface contract" do
    {_path, doc} = write_doc!("capabilities")
    contract = Jason.decode!(File.read!("priv/ash_surface/surface_contract.json"))
    entrypoints = contract["manifest"]["entrypoints"]

    assert doc["capabilities"]["total_entrypoints"] == length(entrypoints)
    assert doc["capabilities"]["resource_count"] ==
             entrypoints |> Enum.map(& &1["resource"]) |> Enum.uniq() |> length()

    assert doc["capabilities"]["resources"]["Xaas.Ultracode.Run"] ==
             Enum.count(entrypoints, &(&1["resource"] == "Xaas.Ultracode.Run"))
  end

  test "every emitted claim carries sources whose paths exist on disk" do
    {_path, doc} = write_doc!("sources")

    claim_sections = ["human_oversight", "logging", "accuracy_robustness"]

    sources =
      for section <- claim_sections,
          claim <- doc[section]["claims"],
          source <- claim["sources"] do
        source
      end

    assert length(sources) > 0

    for source <- sources do
      assert File.exists?(source["path"]),
             "cited source does not exist: #{source["path"]}"

      content = File.read!(source["path"])
      lines = String.split(content, "\n")
      cited = Enum.at(lines, source["line"] - 1)
      assert cited != nil, "cited line missing in #{source["path"]}"
    end
  end

  test "generation is deterministic (two runs byte-identical)" do
    {p1, _} = write_doc!("det1")
    {p2, _} = write_doc!("det2")

    on_exit(fn ->
      File.rm(p1)
      File.rm(p2)
    end)

    assert File.read!(p1) == File.read!(p2)
  end

  test "coverage map rows are projected from the real coverage map" do
    {_path, doc} = write_doc!("coverage")
    rows = doc["coverage_map_rows"]

    assert length(rows) >= 10

    clauses = Enum.map(rows, & &1["clause"])
    assert "12(1)" in clauses
    assert "14(4)(a)" in clauses
    assert "15(1)(c)" in clauses

    coverage_text = File.read!("docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md")
    first_row = hd(rows)
    assert coverage_text =~ first_row["clause"]
  end
end
