defmodule Xaas.Ultracode.OrderProbesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of `Xaas.Ultracode.OrderProbes`: real Semantic
  Jira order files (the committed `docs/sjira/v26.9.21` orders AND synthetic
  ones written to real temp git repos), the real `Sensing.derive/2` jira_dir
  profile, and the real `Verifier.run/2` consuming what comes out.
  """

  alias Xaas.Test.DodFixture, as: Fx
  alias Xaas.Ultracode.{OrderProbes, Sensing}

  @orders Path.expand("../../../docs/sjira/v26.9.21", __DIR__)

  defp order(front_extra \\ %{}, body \\ "") do
    front =
      Map.merge(
        %{
          "identity" => "SJ-900",
          "acceptance" => ["answer is 42", "feature exists"],
          "falsifiers" => ["wrong answer accepted", "missing feature accepted"]
        },
        front_extra
      )

    "---\n" <>
      Jason.encode!(front, pretty: true) <>
      "\n---\n\n# SJ-900: a test order\n\n## Status\nOPEN\n\n" <> body
  end

  defp block(probes), do: "```xaas-probes\n" <> Jason.encode!(probes, pretty: true) <> "\n```\n"

  describe "the committed Semantic Jira orders" do
    test "every real order parses; front-matter falsifiers/acceptance are extracted; none declares probes yet" do
      files = Path.wildcard(Path.join(@orders, "00[1-9]-*.md"))
      assert length(files) == 9

      for file <- files do
        assert {:ok, order} = OrderProbes.read(file)
        assert order.identity =~ ~r/\ASJ-00\d\z/
        assert order.acceptance != [] and order.falsifiers != []
        assert order.probes == []
        assert order.unprobed_falsifiers == order.falsifiers
      end
    end

    test "SJ-001's own falsifiers are read verbatim and coverage is refused until they have probes" do
      assert {:ok, order} = OrderProbes.read(Path.join(@orders, "001-xaas-semantic-jira-e2e.md"))

      assert order.identity == "SJ-001"

      assert order.falsifiers == [
               "materialize accepts a WorkOrder whose digest was altered after admission",
               "receipt seals without the required courts passing"
             ]

      assert length(order.acceptance) == 3
      assert {:error, {:unprobed_falsifiers, missing}} = OrderProbes.require_coverage(order)
      assert missing == order.falsifiers
    end
  end

  describe "parse/1" do
    test "binds probes to falsifiers/acceptance by index or exact text, defaults ids, reports coverage" do
      text =
        order(
          %{},
          block([
            %{
              "kind" => "replace",
              "file" => "answer.txt",
              "pattern" => "42",
              "replacement" => "41",
              "falsifier" => 0
            },
            %{
              "id" => "no-feature",
              "kind" => "delete_file",
              "file" => "feature.txt",
              "falsifier" => "missing feature accepted"
            },
            %{"kind" => "truncate", "file" => "answer.txt", "acceptance" => 0}
          ])
        )

      assert {:ok, order} = OrderProbes.parse(text)

      assert [
               %{
                 "id" => "SJ-900-p1",
                 "falsifier" => "wrong answer accepted",
                 "occurrence" => "first"
               },
               %{"id" => "no-feature", "falsifier" => "missing feature accepted"},
               %{"id" => "SJ-900-p3", "acceptance" => "answer is 42"}
             ] = order.probes

      assert order.unprobed_falsifiers == []
      assert OrderProbes.require_coverage(order) == :ok

      partial = order(%{}, block([%{"kind" => "truncate", "file" => "a", "falsifier" => 1}]))
      assert {:ok, %{unprobed_falsifiers: ["wrong answer accepted"]}} = OrderProbes.parse(partial)
    end

    test "an order with no probes block parses with probes == []" do
      assert {:ok, %{probes: [], identity: "SJ-900"}} = OrderProbes.parse(order())
    end

    test "invalid declarations are typed refusals" do
      bad = fn probes -> OrderProbes.parse(order(%{}, block(probes))) end

      assert {:error, {:invalid_order_probe, _, {:unanchored_probe, "falsifier", 7}}} =
               bad.([%{"kind" => "truncate", "file" => "a", "falsifier" => 7}])

      assert {:error,
              {:invalid_order_probe, _, {:unanchored_probe, "falsifier", "invented sentence"}}} =
               bad.([%{"kind" => "truncate", "file" => "a", "falsifier" => "invented sentence"}])

      assert {:error, {:invalid_order_probe, _, {:unanchored_probe, "acceptance", -1}}} =
               bad.([%{"kind" => "truncate", "file" => "a", "acceptance" => -1}])

      assert {:error, {:invalid_order_probe, _, :probe_has_no_anchor}} =
               bad.([%{"kind" => "truncate", "file" => "a"}])

      assert {:error, {:invalid_probe, _, {:unknown_kind, _}}} =
               bad.([%{"kind" => "rm_rf", "file" => "a", "falsifier" => 0}])

      assert {:error, {:invalid_probe, _, :file_escapes_repo}} =
               bad.([%{"kind" => "truncate", "file" => "../../etc/passwd", "falsifier" => 0}])

      assert {:error, {:duplicate_probe_ids, ["x"]}} =
               bad.([
                 %{"id" => "x", "kind" => "truncate", "file" => "a", "falsifier" => 0},
                 %{"id" => "x", "kind" => "truncate", "file" => "b", "falsifier" => 1}
               ])

      assert {:error, :probes_block_not_a_json_list} =
               OrderProbes.parse(order(%{}, "```xaas-probes\n{not json\n```\n"))

      assert {:error, :no_front_matter} = OrderProbes.parse("# just a heading\n")

      assert {:error, :front_matter_not_json_object} =
               OrderProbes.parse("---\nnot: json\n---\n# x\n")

      assert {:error, {:bad_front_matter_field, "falsifiers"}} =
               OrderProbes.parse(order(%{"falsifiers" => "prose"}))

      assert {:error, :bad_identity} = OrderProbes.parse(order(%{"identity" => "has space"}))
      assert {:error, {:unreadable_order, :enoent}} = OrderProbes.read("/nonexistent/order.md")
    end
  end

  describe "item_fields/1 and Sensing.derive/2 (jira_dir)" do
    setup do
      parent = Fx.tmp("sense")

      {repo, _head} =
        Fx.repo(parent, %{
          "docs/jira/probed.md" =>
            order(
              %{},
              block([
                %{
                  "kind" => "replace",
                  "file" => "answer.txt",
                  "pattern" => "42",
                  "replacement" => "41",
                  "falsifier" => 0
                }
              ])
            ),
          "docs/jira/plain.md" =>
            "# Plain ticket\n\n## Status\nOPEN\n\nNo front matter, no probes.\n",
          "docs/jira/broken.md" =>
            order(%{}, block([%{"kind" => "truncate", "file" => "a", "falsifier" => "made up"}]))
            |> String.replace("SJ-900", "SJ-901"),
          "answer.txt" => "42\n"
        })

      %{repo: repo}
    end

    test "item_fields/1 is empty without a probes block, probes/probes_error with one" do
      assert OrderProbes.item_fields("# t\n\n## Status\nOPEN\n") == %{}
      assert OrderProbes.item_fields(order()) == %{}

      assert %{"probes" => [%{"id" => "SJ-900-p1"}]} =
               OrderProbes.item_fields(
                 order(%{}, block([%{"kind" => "truncate", "file" => "a", "falsifier" => 0}]))
               )

      assert %{"probes_error" => error} =
               OrderProbes.item_fields(
                 order(%{}, block([%{"kind" => "truncate", "file" => "a", "falsifier" => 9}]))
               )

      assert error =~ "unanchored_probe"

      # a probes block on a file with no front matter cannot be silently dropped
      assert %{"probes_error" => no_front} =
               OrderProbes.item_fields("# x\n```xaas-probes\n[]\n```\n")

      assert no_front =~ "no_front_matter"
    end

    test "derive puts probes on the item, adds nothing to plain tickets, and stays deterministic",
         %{repo: repo} do
      assert {:ok, doc} = Sensing.derive(%{"type" => "jira_dir"}, repo)
      assert {:ok, ^doc} = Sensing.derive(%{"type" => "jira_dir"}, repo)

      by_file = Map.new(doc["items"], &{&1["source"]["file"], &1})

      assert %{"probes" => [%{"kind" => "replace", "falsifier" => "wrong answer accepted"}]} =
               probed = by_file["docs/jira/probed.md"]

      refute Map.has_key?(probed, "probes_error")

      plain = by_file["docs/jira/plain.md"]
      refute Map.has_key?(plain, "probes")
      refute Map.has_key?(plain, "probes_error")

      assert %{"probes_error" => error} = by_file["docs/jira/broken.md"]
      assert error =~ "made up"
    end
  end
end
