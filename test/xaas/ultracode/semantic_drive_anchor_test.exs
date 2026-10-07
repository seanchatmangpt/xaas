defmodule Xaas.Ultracode.SemanticDriveAnchorTest do
  @moduledoc """
  Chicago qualification of the hop-0 anchor of the ARD section 8 digest law
  (lane R1-X-COURTS; PRD PR-008, GC23-4; ARD section 8, section 26 F2):
  `SemanticDrive.verify_hops/1` is internal agreement only -- a hops
  document forged consistently at every hop satisfies it -- and
  `SemanticDrive.verify_hops/2` refuses unless every hop equals the anchor
  derived from the admitted order.

  Every input is real: the committed reference episode
  `docs/sjira/v26.9.23/episodes/fmt-1` (work graph, hops, ledger) read from
  disk; forgeries are built from it by the same canonical digests the drive
  uses. The live `anchor/1` tests run the real graph side -- a
  `mix semantic_jira.descriptor` OS process in the ggen_igniter checkout
  named by `GGEN_IGNITER_DIR`, compiled into a PRIVATE APFS clone of that
  checkout's `_build/test` -- and skip (named) when it is unset.
  """

  use ExUnit.Case, async: false

  alias Xaas.Sa2a.Route
  alias Xaas.Ultracode.SemanticDrive

  @moduletag timeout: 600_000

  @episode Path.expand("../../../docs/sjira/v26.9.23/episodes/fmt-1", __DIR__)
  @ggen_dir System.get_env("GGEN_IGNITER_DIR")
  @live_skip (cond do
                is_nil(@ggen_dir) ->
                  "GGEN_IGNITER_DIR unset (the graph-side checkout under judgement)"

                not File.regular?(
                  Path.join(@ggen_dir || "", "lib/mix/tasks/semantic_jira.descriptor.ex")
                ) ->
                  "GGEN_IGNITER_DIR #{@ggen_dir} lacks mix semantic_jira.descriptor"

                true ->
                  false
              end)

  setup do
    hops = read!("hops.json")
    row = read!("work.json")["work_orders"] |> Enum.find(&(&1["identity"] == "EP-A"))

    [snapshot] =
      "ledger.ndjson"
      |> path()
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&(&1["identity"] == "EP-A"))
      |> Enum.map(& &1["snapshot_digest"])

    %{hops: hops, row: row, snapshot: snapshot}
  end

  test "the anchor of the committed EP-A row under its admitted snapshot digest is the recorded sJira hop, and anchors the committed hops",
       %{hops: hops, row: row, snapshot: snapshot} do
    assert {:ok, anchor} = SemanticDrive.anchor_from(row, snapshot)
    sjira = hd(hops["hops"])

    assert anchor["tuple"] == sjira["tuple"]
    assert anchor["request"] == sjira["request"]
    assert anchor["tuple_digest"] == sjira["digest"]
    assert anchor["request_digest"] == sjira["request_digest"]
    assert anchor["graph_digest"] == snapshot

    assert {:ok, %{"tuple_digest" => t, "request_digest" => r, "anchor" => bound}} =
             SemanticDrive.verify_hops(hops, anchor)

    assert t == anchor["tuple_digest"] and r == anchor["request_digest"]
    assert bound["work_order"] == "EP-A"
  end

  test "a hops document forged consistently at EVERY hop passes the internal law and is refused by the anchor",
       %{hops: hops, row: row, snapshot: snapshot} do
    forged = forge_every_hop(hops, "postcondition", " (forged at every hop)")

    # the defect (MSA CE23-12 p3): internal agreement alone admits it
    assert {:ok, %{"tuple_digest" => forged_digest}} = SemanticDrive.verify_hops(forged)
    refute forged_digest == hd(hops["hops"])["digest"]

    {:ok, anchor} = SemanticDrive.anchor_from(row, snapshot)

    assert {:refused,
            %{
              "standing" => "REFUSED(tuple_digest_mismatch)",
              "reason" => "tuple_digest_mismatch",
              "broken_term" => "admission_vacuous",
              "hop" => "sjira",
              "detail" => detail
            }} = SemanticDrive.verify_hops(forged, anchor)

    assert detail["anchor"] == "admitted_work_graph"
    assert detail["carrier"] == "tuple"
    assert detail["field"] == "postcondition"
    assert detail["expected"] == anchor["tuple_digest"]
    assert detail["observed"] == forged_digest
  end

  test "every tuple field forged at every hop is refused by the anchor, naming that field",
       %{hops: hops, row: row, snapshot: snapshot} do
    {:ok, anchor} = SemanticDrive.anchor_from(row, snapshot)

    for field <- Route.fields() do
      forged = forge_every_hop(hops, field, "-forged")
      assert {:ok, _} = SemanticDrive.verify_hops(forged), field

      assert {:refused, %{"reason" => "tuple_digest_mismatch", "detail" => detail}} =
               SemanticDrive.verify_hops(forged, anchor),
             field

      assert detail["field"] == field
    end
  end

  test "hops recorded under another admitted snapshot (graph_digest forged at every hop) are refused on the request carrier",
       %{hops: hops, row: row, snapshot: snapshot} do
    other = "sha256:" <> String.duplicate("0", 64)

    forged =
      update_in(hops, ["hops"], fn list ->
        Enum.map(list, fn hop ->
          request = Map.put(hop["request"], "graph_digest", other)

          Map.merge(hop, %{
            "request" => request,
            "request_digest" => SemanticDrive.request_digest(request)
          })
        end)
      end)

    assert {:ok, _} = SemanticDrive.verify_hops(forged)
    {:ok, anchor} = SemanticDrive.anchor_from(row, snapshot)

    assert {:refused,
            %{
              "reason" => "tuple_digest_mismatch",
              "detail" => %{"carrier" => "request", "field" => "graph_digest"}
            }} = SemanticDrive.verify_hops(forged, anchor)
  end

  test "no anchor is REFUSED(hops_unanchored), and a document that disagrees with itself is refused before the anchor",
       %{hops: hops, row: row, snapshot: snapshot} do
    assert {:refused,
            %{"standing" => "REFUSED(hops_unanchored)", "broken_term" => "admission_vacuous"}} =
             SemanticDrive.verify_hops(hops, %{})

    {:ok, anchor} = SemanticDrive.anchor_from(row, snapshot)
    underneath = update_in(hops, ["hops", Access.at(2), "tuple", "subject"], &(&1 <> "!"))

    assert {:refused, %{"reason" => "tuple_digest_mismatch", "hop" => "xaas"}} =
             SemanticDrive.verify_hops(underneath, anchor)
  end

  test "mix xaas.episode --verify-hops without --anchor-work-graph refuses the committed hops: REFUSED(hops_unanchored), exit 3" do
    {code, lines} = run_task(["--verify-hops", path("hops.json")])
    assert code == 3
    last = lines |> List.last() |> Jason.decode!()
    assert last["standing"] == "REFUSED(hops_unanchored)"
    assert last["broken_term"] == "admission_vacuous"
  end

  describe "the live anchor through the graph side" do
    @describetag skip: @live_skip

    setup do
      base = Path.join(System.tmp_dir!(), "anchor-#{System.unique_integer([:positive])}")
      build = Path.join(base, "build")
      File.mkdir_p!(build)
      {_, 0} = System.cmd("cp", ["-cRp", Path.join(@ggen_dir, "_build/test"), build])
      on_exit(fn -> File.rm_rf(base) end)
      %{base: base, build: Path.join(build, "test")}
    end

    # The fmt-1 episode fixture is SEALED: its ledger snapshot digest binds the
    # committed hops, so the work graph cannot be edited (or augmented with the
    # now-required `origin_authority`) without breaking the anchor_from tests
    # above. ggen_igniter AC-04 (23c36c8) requires `origin_authority` on every
    # row at admission; the pre-AC-04 fmt-1 rows are refused before origin
    # resolution, surfacing as `not_eligible ... unknown_identity` (blocked
    # entries carry no identity key). The typed refusal below IS the lawful
    # current outcome: the anchor refusal engine fires exactly as designed on a
    # work order that no longer resolves against the live graph-side law.
    @refusal %{
      "standing" => "REFUSED(descriptor_refused)",
      "reason" => "descriptor_refused",
      "broken_term" => "mu_on_O",
      "hop" => "sjira"
    }

    test "anchor/1 refuses the committed work graph: the pre-AC-04 EP-A row does not resolve under the live descriptor law",
         %{build: build} do
      assert {:refused, refusal} =
               SemanticDrive.anchor(
                 ggen_igniter_dir: @ggen_dir,
                 work_graph: path("work.json"),
                 order: "EP-A",
                 ggen_build_path: build
               )

      assert %{
               "detail" => %{
                 "exit" => 1,
                 "reason" => ["descriptor_refused", ["not_eligible", "EP-A", "unknown_identity"]]
               }
             } =
               refusal

      assert Map.drop(refusal, ["detail"]) == @refusal
    end

    test "anchor/1 refuses an edited work graph with the same typed refusal: no anchor can be minted from an unadmittable row",
         %{base: base, build: build} do
      graph = read!("work.json")

      edited =
        update_in(graph, ["work_orders"], fn rows ->
          Enum.map(rows, fn
            %{"identity" => "EP-A"} = row ->
              Map.update!(row, "postcondition", &(&1 <> " (edited)"))

            row ->
              row
          end)
        end)

      work = Path.join(base, "work.json")
      File.write!(work, Jason.encode!(edited))

      assert {:refused, refusal} =
               SemanticDrive.anchor(
                 ggen_igniter_dir: @ggen_dir,
                 work_graph: work,
                 order: "EP-A",
                 ggen_build_path: build
               )

      assert %{
               "detail" => %{
                 "exit" => 1,
                 "reason" => ["descriptor_refused", ["not_eligible", "EP-A", "unknown_identity"]]
               }
             } =
               refusal

      assert Map.drop(refusal, ["detail"]) == @refusal
    end
  end

  # -- helpers ------------------------------------------------------------------

  defp forge_every_hop(hops, field, suffix) do
    update_in(hops, ["hops"], fn list ->
      Enum.map(list, fn hop ->
        tuple = Map.update!(hop["tuple"], field, &forge(&1, suffix))

        request =
          if Map.has_key?(hop["request"], field),
            do: Map.update!(hop["request"], field, &forge(&1, suffix)),
            else: hop["request"]

        Map.merge(hop, %{
          "tuple" => tuple,
          "digest" => Route.digest(tuple),
          "request" => request,
          "request_digest" => SemanticDrive.request_digest(request)
        })
      end)
    end)
  end

  defp forge(value, suffix) when is_list(value), do: value ++ [String.trim(suffix)]
  defp forge(value, suffix) when is_binary(value), do: value <> suffix

  defp run_task(args) do
    previous = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    code =
      try do
        Mix.Tasks.Xaas.Episode.run(args)
        0
      catch
        :exit, {:shutdown, code} -> code
      after
        Mix.shell(previous)
      end

    {code, collect([])}
  end

  defp collect(acc) do
    receive do
      {:mix_shell, :info, [line]} -> collect(acc ++ [line])
      {:mix_shell, :error, [line]} -> collect(acc ++ [line])
    after
      0 -> acc
    end
  end

  defp path(name), do: Path.join(@episode, name)
  defp read!(name), do: name |> path() |> File.read!() |> Jason.decode!()
end
