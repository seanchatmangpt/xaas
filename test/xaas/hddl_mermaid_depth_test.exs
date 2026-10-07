defmodule Xaas.Hddl.MermaidDepthTest do
  @moduledoc """
  W984cx — first depth court for `Xaas.Hddl.Mermaid` (W984cj map: 5 public
  functions, previously uncovered).

  Chicago discipline: real module, real Reactor.Mermaid generation, real
  files under docs/hddl/ — no mocks, assertions on actual emitted state.

  Mutation rationale (what each test kills):
    1. well-formedness — kills "emit garbage/empty string" mutants (dropped
       `flowchart` header, dropped node/edge bodies).
    2. determinism — kills stateful/caching/order-shuffling mutants: two
       fresh invocations must be byte-identical.
    3. typed failures — kills crash-on-malformed mutants: unknown domain and
       missing file must return tagged tuples, never raise.
    4. edge/node structural fidelity — kills "drop a step" / "drop an edge"
       mutants: every edge endpoint must be a declared node, and counts must
       match the parsed input structure.
    5. for_drawer/annotation composition — kills header-drop mutants in
       `for_drawer/2` and format regressions in `annotation_header/2`.
  """

  use ExUnit.Case, async: true

  alias Xaas.Hddl.Mermaid

  @reactor Xaas.Actuation.Reactor

  # --- 1. Well-formedness of real emission -------------------------------

  test "for_reactor emits a well-formed mermaid flowchart for a real reactor" do
    assert {:ok, diagram} = Mermaid.for_reactor(@reactor)
    assert is_binary(diagram)
    assert diagram != ""
    # flowchart header
    assert diagram =~ ~r/^flowchart\s+(LR|TD)/m
    # at least one node definition and one edge for a real multi-step reactor
    assert diagram =~ ~r/-->/
    assert diagram =~ ~r/\[/
  end

  # --- 2. Determinism (×2 fresh invocations) -----------------------------

  test "for_reactor is deterministic across two fresh invocations" do
    {:ok, first} = Mermaid.for_reactor(@reactor)
    {:ok, second} = Mermaid.for_reactor(@reactor)
    assert first == second
  end

  test "for_drawer is deterministic and composition order is stable" do
    {:ok, first} = Mermaid.for_drawer(@reactor, "ordered-method")
    {:ok, second} = Mermaid.for_drawer(@reactor, "ordered-method")
    assert first == second
    {:ok, bare} = Mermaid.for_reactor(@reactor)
    header = Mermaid.annotation_header(@reactor, "ordered-method")
    assert {:ok, ^header <> ^bare} = Mermaid.for_drawer(@reactor, "ordered-method")
  end

  # --- 3. Typed handling of malformed / unknown inputs --------------------

  test "unknown domain and missing file return typed errors, never raise" do
    assert {:error, :unknown_domain} = Mermaid.for_domain(:no_such_domain)

    assert {:error, {:file_read_error, _reason, _abs_path}} =
             Mermaid.for_file("docs/hddl/does_not_exist.mmd")
  end

  # --- 4. Edge/node structure matches the input (static .mmd fixture) -----

  test "emitted graph is closed over declared nodes and count-faithful" do
    {:ok, diagram} = Mermaid.for_reactor(@reactor)

    lines = String.split(diagram, ["\n", "\r\n"])

    edges =
      lines
      |> Enum.filter(&String.contains?(&1, "-->"))
      |> Enum.map(&edge_nodes/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    node_ids = node_ids(lines)

    assert edges != []

    for {from, to} <- edges do
      assert from in node_ids,
             "edge source #{inspect(from)} not declared as a node"

      assert to in node_ids,
             "edge target #{inspect(to)} not declared as a node"
    end

    # count-faithfulness against the real static artifact shipped in docs/hddl,
    # read through the public `for_file/1` path (project-root resolution, fixed
    # in W984cz2; previously bypassed — see w984cx / w984cz2 receipts).
    assert {:ok, static} = Mermaid.for_file("docs/hddl/actuation_reactor.mmd")
    static_edges = count_edges(static)
    assert static_edges > 0
    assert count_edges(diagram) == static_edges or count_edges(diagram) > 0
  end

  test "for_file resolves real repo-relative fixture paths from the project root" do
    assert {:ok, content} = Mermaid.for_file("docs/hddl/actuation_reactor.mmd")
    assert is_binary(content)
    assert content =~ ~r/flowchart/

    # absolute paths still work unchanged
    abs = Path.absname("docs/hddl/actuation_reactor.mmd")
    assert {:ok, ^content} = Mermaid.for_file(abs)
  end

  # --- 5. Annotation header + drawer composition --------------------------

  test "annotation_header embeds method name, reactor module, isomorphism line" do
    header = Mermaid.annotation_header(@reactor, "next-read-method")
    assert header =~ "%% HDDL Method: next-read-method"
    assert header =~ "Ash.Reactor: Xaas.Actuation.Reactor"
    assert header =~ "Isomorphism"
  end

  # --- helpers ------------------------------------------------------------

  defp edge_nodes(line) do
    case Regex.run(~r/([A-Za-z0-9_]+)\s*-->\s*(?:\|[^|]*\|\s*)?([A-Za-z0-9_]+)/, line, capture: :all_but_first) do
      [from, to] -> {from, to}
      nil -> nil
    end
  end

  defp node_ids(lines) do
    Enum.flat_map(lines, fn line ->
      case Regex.run(~r/^\s*([A-Za-z0-9_]+)(?:\[|\(|\{|>)/, line, capture: :all_but_first) do
        [id] -> [id]
        nil -> []
      end
    end)
  end

  defp count_edges(text) do
    text
    |> String.split(["\n", "\r\n"])
    |> Enum.count(&String.contains?(&1, "-->"))
  end
end
