defmodule Mix.Tasks.Xaas.EuAiActPackTest do
  use ExUnit.Case, async: false

  @out1 Path.join(System.tmp_dir!(), "eu_ai_act_pack_test_1.json")
  @out2 Path.join(System.tmp_dir!(), "eu_ai_act_pack_test_2.json")

  setup do
    File.rm(@out1)
    File.rm(@out2)
    on_exit(fn ->
      File.rm(@out1)
      File.rm(@out2)
    end)
    :ok
  end

  test "generates a parseable pack to --out with subject, articles, ledger stats" do
    Mix.Task.rerun("xaas.eu_ai_act_pack", ["--out", @out1])

    assert File.exists?(@out1)
    pack = @out1 |> File.read!() |> Jason.decode!()

    assert pack["schema"] == "xaas.eu_ai_act_pack/v1"

    assert %{"branch" => branch, "head_sha" => sha} = pack["subject"]
    assert is_binary(branch) and branch != ""
    assert Regex.match?(~r/^[0-9a-f]{40}$/, sha)

    expected_keys = MapSet.new([
      "art5",
      "art9/10",
      "art11/12",
      "art13/14",
      "art15",
      "art50",
      "art72/86"
    ])

    assert MapSet.new(Map.keys(pack["articles"])) == expected_keys

    for {_key, article} <- pack["articles"] do
      assert is_binary(article["verdict"]) and article["verdict"] != ""
      assert is_binary(article["note"])
      assert is_list(article["evidence"]) and article["evidence"] != []
    end

    # real refusal-ledger corpus stats (ledger is present in this tree)
    assert pack["refusal_corpus"]["status"] == "PRESENT"
    assert pack["refusal_corpus"]["counts"]["declared"] == 62
    assert pack["refusal_corpus"]["counts"]["fixture_covered"] == 62

    # gaps never claimed closed
    assert pack["typed_gaps"]["lines"] != []
    assert Enum.any?(pack["typed_gaps"]["lines"], &String.contains?(&1, "GAP("))
  end

  test "every evidence path cited in the pack exists on disk" do
    Mix.Task.rerun("xaas.eu_ai_act_pack", ["--out", @out1])
    pack = @out1 |> File.read!() |> Jason.decode!()

    for {_key, article} <- pack["articles"],
        path <- article["evidence"] do
      assert File.exists?(path), "cited evidence path missing on disk: #{path}"
    end
  end

  test "deterministic: two runs identical modulo generated_at" do
    Mix.Task.rerun("xaas.eu_ai_act_pack", ["--out", @out1])
    Process.sleep(1100)
    Mix.Task.rerun("xaas.eu_ai_act_pack", ["--out", @out2])

    p1 = @out1 |> File.read!() |> Jason.decode!()
    p2 = @out2 |> File.read!() |> Jason.decode!()

    assert {:ok, t1, _} = DateTime.from_iso8601(p1["generated_at"])
    assert {:ok, t2, _} = DateTime.from_iso8601(p2["generated_at"])
    assert DateTime.compare(t1, t2) == :lt

    d1 = Map.delete(p1, "generated_at") |> Jason.encode!()
    d2 = Map.delete(p2, "generated_at") |> Jason.encode!()
    assert d1 == d2
  end

  test "generation fails loudly when a cited evidence path is missing (fail-closed)" do
    assert_raise Mix.Error, ~r/REFUSED_EVIDENCE_PATH_MISSING/, fn ->
      Mix.Tasks.Xaas.EuAiActPack.verify_paths!(["docs/sjira/v26.10.6/definitely-not-on-disk.md"])
    end

    # and the real article evidence set passes it (generation path, real FS)
    assert :ok ==
             Mix.Tasks.Xaas.EuAiActPack.verify_paths!([
               "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md",
               "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json",
               "lib/xaas/actuation.ex"
             ])
  end
end
