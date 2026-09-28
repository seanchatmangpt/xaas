defmodule Xaas.Ultracode.CapabilityResolverTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Falsifier-first, HERMETIC qualification of the Ultracode
  capability-resolution court (`Xaas.Ultracode.CapabilityResolver`) and
  its wiring into `Autonomic.run/1` (`Autonomic.resolve_capabilities/2`).

  No DB, no Ash resources, no HTTP: sources are inlined test modules
  injected through the real config seam (`config :xaas,
  :ultracode_capability_sources`, the same `Application.put_env` +
  `on_exit` restore pattern the repo's provider tests use), so the
  court's classification, its FAIL-CLOSED law, and the receipt
  persistence are qualified against the real resolver code path only.

  THE INVARIANT under test, encoded as the anti-vacuity mutation:

      FRONTIER(w)  <=>  ¬∃ c ∈ Closure(C_fleet) : c ⊨ requirements(w)

  the court must FLIP an item's class when one satisfying capability is
  injected into (or removed from) a source -- a court that cannot flip
  admits nothing and refuses nothing (admission_vacuous).

  Worker-eligibility is asserted STRUCTURALLY: `resolve_capabilities/2`
  returns only `:frontier` items as dispatchable, so a non-frontier class
  makes the worker unreachable for that item by construction (the
  DB-gated full-loop execution of that fact lives in the :subprocess
  autonomic suite). The `Local` source's read path is DB-gated and is
  exercised there, not here; its failure mapping (read error =>
  `{:error, _}` => `:unresolved`) is the same fail-closed law qualified
  below through the `ErrorSource`.
  """

  alias Xaas.Ultracode.Autonomic
  alias Xaas.Ultracode.CapabilityResolver
  alias Xaas.Ultracode.CapabilityResolver.Receipt
  alias Xaas.Ultracode.CapabilityResolver.Source.Sa2a

  @capability_id_pattern_gate "recipe:mix-format"

  # -- test sources (witnesses, per the Source behaviour) ----------------

  defmodule EmptySource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: {:ok, []}
  end

  defmodule OkSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do: {:ok, [%{capability_id: "recipe:mix-format", satisfies: ["recipe:mix-format"]}]}
  end

  defmodule ErrorSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: {:error, :db_down}
  end

  defmodule SkippedSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: {:skipped, :not_configured}
  end

  # The mutation lever: the SAME source, flipped by a test env key. THE
  # anti-vacuity witness -- the court must flip the item's class when the
  # fleet's answer changes.
  defmodule FlipSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx) do
      if Application.get_env(:xaas, :test_resolver_inject_capability, false) do
        {:ok, [%{capability_id: "recipe:mix-format", satisfies: ["recipe:mix-format"]}]}
      else
        {:ok, []}
      end
    end
  end

  defmodule BadCandidateSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: {:ok, [%{"capability_id" => "NOT A CAPABILITY ID"}]}
  end

  defmodule GarbageSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: :garbage
  end

  defmodule RaisingSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx), do: raise("witness exploded")
  end

  defmodule ComposeSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do:
        {:ok,
         [
           %{capability_id: "report:aggregate", satisfies: ["req-2"]},
           %{capability_id: "ingest:normalize", satisfies: ["req-1"]}
         ]}
  end

  defmodule ExtendSource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do: {:ok, [%{capability_id: "ingest:normalize", satisfies: ["req-1"]}]}
  end

  defmodule FamilySource do
    @behaviour Xaas.Ultracode.CapabilityResolver.Source
    @impl true
    def candidates(_item, _ctx),
      do: {:ok, [%{capability_id: "recipe:other-thing", satisfies: ["recipe:other-thing"]}]}
  end

  # -- fixtures -----------------------------------------------------------

  defp item(id \\ "w-mix", capability \\ @capability_id_pattern_gate) do
    %{"id" => id, "capability_id" => capability}
  end

  defp ctx(tmpdir, extra \\ []) do
    Map.merge(
      %{
        out_dir: tmpdir,
        ledger: Path.join(tmpdir, "ledger.ndjson")
      },
      Map.new(extra)
    )
  end

  defp with_sources(sources, fun) do
    Application.put_env(:xaas, :ultracode_capability_sources, sources)

    try do
      fun.()
    after
      Application.delete_env(:xaas, :ultracode_capability_sources)
    end
  end

  # The resolution receipts only: the same file also carries the
  # deterministic execution records (xaas.capability-execution-record/1)
  # appended after them for non-frontier verdicts.
  defp ndjson_lines(path) do
    path
    |> all_lines()
    |> Enum.filter(&(&1["schema"] == "xaas.capability-resolution-receipt/1"))
  end

  defp all_lines(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  # -- the invariant: reuse flips frontier, and only frontier dispatches --

  describe "THE INVARIANT (FRONTIER(w) <=> no fleet capability satisfies requirements(w))" do
    test "anti-vacuity mutation: injecting the satisfying capability flips :frontier -> :reuse" do
      Application.put_env(:xaas, :test_resolver_inject_capability, false)

      try do
        with_sources(%{"fleet" => FlipSource}, fn ->
          tmp =
            Path.join(System.tmp_dir!(), "resolver-flip-#{System.unique_integer([:positive])}")

          File.mkdir_p!(tmp)

          assert %{class: :frontier} = CapabilityResolver.resolve_item(item(), ctx(tmp))

          # THE FLIP: one capability enters the closure, the same item with
          # the same requirements is no longer frontier. A court that could
          # not flip would be vacuous in both directions.
          Application.put_env(:xaas, :test_resolver_inject_capability, true)

          assert %{class: :reuse} = CapabilityResolver.resolve_item(item(), ctx(tmp))
        end)
      after
        Application.delete_env(:xaas, :test_resolver_inject_capability)
      end
    end

    test "(a) a satisfying existing capability => :reuse and NO item reaches a worker" do
      with_sources(%{"local" => OkSource}, fn ->
        tmp = Path.join(System.tmp_dir!(), "resolver-reuse-#{System.unique_integer([:positive])}")
        File.mkdir_p!(tmp)

        {frontier, results} =
          Autonomic.resolve_capabilities([item()], ctx(tmp))

        # Worker-eligibility is structural: nothing dispatchable comes back,
        # so the worker function is unreachable for this item.
        assert frontier == []
        assert [%{item: "w-mix", status: :satisfied_existing, attempts: 0} = result] = results
        assert [%{"class" => "reuse"}] = ndjson_lines(receipt_path(tmp))

        # The hermetic OkSource names no prior subject (no run/work order/
        # receipt witness), so the reuse is EXECUTED as a typed
        # unsupported(no_prior_subject) record -- never a fabricated replay.
        assert result.outcome == {:unsupported, :no_prior_subject}

        assert [_resolution, %{"schema" => "xaas.capability-execution-record/1"} = exec] =
                 all_lines(receipt_path(tmp))

        assert exec["outcome"] == "unsupported:no_prior_subject"
      end)
    end

    test "(b) zero satisfiers from all-ok sources => :frontier, worker invoked, residual on the receipt" do
      with_sources(%{"fleet" => EmptySource}, fn ->
        tmp =
          Path.join(System.tmp_dir!(), "resolver-frontier-#{System.unique_integer([:positive])}")

        File.mkdir_p!(tmp)

        {frontier, results} =
          Autonomic.resolve_capabilities([item()], ctx(tmp))

        assert frontier == [item()]
        assert results == []

        assert [%{"class" => "frontier", "residual_requirements" => residual}] =
                 ndjson_lines(receipt_path(tmp))

        assert residual == [@capability_id_pattern_gate]
      end)
    end

    test "(c) one source {:error, _} => :unresolved and NO item reaches a worker" do
      with_sources(%{"local" => OkSource, "broken" => ErrorSource}, fn ->
        tmp = Path.join(System.tmp_dir!(), "resolver-error-#{System.unique_integer([:positive])}")
        File.mkdir_p!(tmp)

        {frontier, results} =
          Autonomic.resolve_capabilities([item()], ctx(tmp))

        assert frontier == []
        assert [%{status: :blocked, reason: "capability_resolution_unresolved"}] = results

        receipt = ndjson_lines(receipt_path(tmp)) |> hd()
        assert receipt["class"] == "unresolved"
        assert receipt["sources_queried"]["broken"]["status"] == "error"
      end)
    end

    test "(d) source {:skipped, _} under the default full-closure mode => :unresolved" do
      with_sources(%{"sa2a" => SkippedSource, "local" => OkSource}, fn ->
        receipt = CapabilityResolver.resolve_item(item(), %{})

        assert receipt.class == :unresolved
        assert receipt.sources_queried["sa2a"].status == :skipped
      end)
    end

    test "(d2) reduced-closure mode (capability_full_closure: false) lets :ok sources decide" do
      with_sources(%{"sa2a" => SkippedSource, "local" => OkSource}, fn ->
        receipt = CapabilityResolver.resolve_item(item(), %{capability_full_closure: false})

        assert receipt.class == :reuse
      end)
    end

    test "a court with zero answering witnesses refuses :frontier (never vacuous)" do
      with_sources(%{}, fn ->
        assert %{class: :unresolved} = CapabilityResolver.resolve_item(item(), %{})
      end)

      with_sources(%{"skipped" => SkippedSource}, fn ->
        assert %{class: :unresolved} = CapabilityResolver.resolve_item(item(), %{})
      end)
    end

    test "one invalid candidate fails its WHOLE source => :unresolved (fail-closed)" do
      with_sources(%{"local" => OkSource, "wild" => BadCandidateSource}, fn ->
        assert %{class: :unresolved} = CapabilityResolver.resolve_item(item(), %{})
      end)
    end

    test "a misbehaving source (garbage result, or a raise) is a failed source => :unresolved" do
      with_sources(%{"garbage" => GarbageSource}, fn ->
        assert %{class: :unresolved} = CapabilityResolver.resolve_item(item(), %{})
      end)

      with_sources(%{"raises" => RaisingSource}, fn ->
        assert %{class: :unresolved} = CapabilityResolver.resolve_item(item(), %{})
      end)
    end
  end

  # -- classification (mechanical v1) -------------------------------------

  describe "classification" do
    test ":compose when a bounded composition covers what no single capability does" do
      with_sources(%{"fleet" => ComposeSource}, fn ->
        item = %{"id" => "w-two", "required_capabilities" => ["req-1", "req-2"]}

        receipt = CapabilityResolver.resolve_item(item, %{})

        assert receipt.class == :compose
        # Deterministic greedy order: the tie (both cover one) goes to the
        # greater capability_id first.
        assert receipt.selected_capabilities == ["report:aggregate", "ingest:normalize"]
        assert receipt.residual_requirements == nil
      end)
    end

    test ":extend with the uncovered residual when candidates only partially cover" do
      with_sources(%{"fleet" => ExtendSource}, fn ->
        item = %{"id" => "w-part", "required_capabilities" => ["req-1", "req-2"]}

        receipt = CapabilityResolver.resolve_item(item, %{})

        assert receipt.class == :extend
        assert receipt.selected_capabilities == ["ingest:normalize"]
        assert receipt.residual_requirements == ["req-2"]
      end)
    end

    test ":generate when no candidate covers the requirement but its family is known" do
      with_sources(%{"fleet" => FamilySource}, fn ->
        receipt = CapabilityResolver.resolve_item(item("w-fam", "recipe:brand-new"), %{})

        assert receipt.class == :generate
        assert receipt.selected_capabilities == []
        # :generate names no residual: the family is witnessed, the
        # capability itself is not, and the receipt's residual is reserved
        # for frontier/extend/unresolved.
        assert receipt.residual_requirements == nil
      end)
    end

    test "an item declaring NO requirements is :frontier by SCOPE (nothing witnesses it)" do
      with_sources(%{"fleet" => OkSource}, fn ->
        receipt = CapabilityResolver.resolve_item(%{"id" => "w-open"}, %{})

        assert receipt.class == :frontier
        # Source-independent: no closure entry can cover an unnamed
        # requirement, so the court queries nothing (zero-information check).
        assert receipt.sources_queried == %{}
      end)

      # Not an exception to the fail-closed law -- an outranked law: even a
      # FAILING source cannot change a mechanically source-independent verdict.
      with_sources(%{"broken" => ErrorSource}, fn ->
        assert %{class: :frontier} =
                 CapabilityResolver.resolve_item(%{"id" => "w-open"}, %{})
      end)
    end
  end

  describe "requirements/1 (mechanical extraction)" do
    test "capability_id, its 'capability' alias, and required_capabilities, deduped and sorted" do
      item = %{
        "id" => "w",
        "capability_id" => "b:x",
        "capability" => "a:y",
        "required_capabilities" => ["a:y", "c:z"]
      }

      assert CapabilityResolver.requirements(item) == ["a:y", "b:x", "c:z"]
    end

    test "a required_capabilities binary string counts as one requirement" do
      assert CapabilityResolver.requirements(%{"required_capabilities" => "b:x"}) == ["b:x"]
    end

    test "no declared requirements => []" do
      assert CapabilityResolver.requirements(%{"id" => "w", "goal" => "do a thing"}) == []
    end
  end

  # -- the receipt ---------------------------------------------------------

  describe "resolution receipt" do
    test "(f) persisted (NDJSON) BEFORE the dispatch stage, falsifier carried, sources recorded" do
      with_sources(%{"fleet" => OkSource}, fn ->
        tmp =
          Path.join(System.tmp_dir!(), "resolver-receipt-#{System.unique_integer([:positive])}")

        File.mkdir_p!(tmp)

        items = [item("w-1"), %{"id" => "w-2", "goal" => "unscoped work"}]

        {frontier, _results} = Autonomic.resolve_capabilities(items, ctx(tmp))

        # The stage returned => every item's receipt is already on disk,
        # including the frontier item's (workers claim only after this).
        path = receipt_path(tmp)
        assert File.exists?(path)

        assert [%{"item_id" => "w-1"}, %{"item_id" => "w-2"}] = lines = ndjson_lines(path)

        for line <- lines do
          assert line["schema"] == "xaas.capability-resolution-receipt/1"
          assert line["falsifier"] == Receipt.falsifier()
          assert line["resolved_at"]
        end

        # w-1 declared a requirement => the fleet source was queried and recorded.
        assert hd(lines)["class"] == "reuse"
        assert hd(lines)["selected_capabilities"] == [@capability_id_pattern_gate]
        assert hd(lines)["sources_queried"]["fleet"]["status"] == "ok"

        # w-2 declared none => the court's verdict is source-independent,
        # so nothing was queried and the receipt records exactly that.
        assert List.last(lines)["class"] == "frontier"
        assert List.last(lines)["sources_queried"] == %{}

        # Only the frontier item is dispatchable.
        assert [%{"id" => "w-2"}] = frontier
      end)
    end

    test "the standing falsifier is the one from the operator contract" do
      assert Receipt.falsifier() ==
               "an already-qualified capability or lawful composition satisfying this " <>
                 "residual refutes this receipt"
    end

    test "classes are the six of the contract" do
      assert Receipt.classes() == [:reuse, :compose, :extend, :generate, :frontier, :unresolved]
    end
  end

  # -- the wiring ----------------------------------------------------------

  describe "Autonomic wiring" do
    test "capability_resolution: false BYPASSES the court (logged) and dispatches everything" do
      tmp = Path.join(System.tmp_dir!(), "resolver-bypass-#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)

      items = [item("w-1"), item("w-2")]

      {frontier, results} =
        Autonomic.resolve_capabilities(items, ctx(tmp, capability_resolution: false))

      assert frontier == items
      assert results == []
      # No receipts file: the court never ran.
      refute File.exists?(receipt_path(tmp))

      ledger = File.read!(Path.join(tmp, "ledger.ndjson"))
      assert ledger =~ "capability_resolution_bypassed"
    end

    test "the court runs by default and the ledger records the class map" do
      with_sources(%{"fleet" => OkSource}, fn ->
        tmp =
          Path.join(System.tmp_dir!(), "resolver-ledger-#{System.unique_integer([:positive])}")

        File.mkdir_p!(tmp)

        Autonomic.resolve_capabilities([item("w-1")], ctx(tmp))

        ledger = File.read!(Path.join(tmp, "ledger.ndjson"))
        assert ledger =~ "capability_resolution"
        assert ledger =~ "reuse"
      end)
    end
  end

  # -- the SA2A source (config-driven; transport errors are fail-closed) ----

  describe "Sa2a source" do
    test "unset endpoint => {:skipped, :not_configured}" do
      Application.delete_env(:xaas, :ultracode_sa2a_capability_endpoint)

      assert {:skipped, :not_configured} = Sa2a.candidates(item(), %{})
    end

    test "garbage endpoint config => {:error, _}" do
      Application.put_env(:xaas, :ultracode_sa2a_capability_endpoint, 42)

      try do
        assert {:error, {:invalid_endpoint_config, 42}} = Sa2a.candidates(item(), %{})
      after
        Application.delete_env(:xaas, :ultracode_sa2a_capability_endpoint)
      end
    end

    test "an unreachable endpoint is a FAILED source (court fail-closes), never a skip" do
      Application.put_env(
        :xaas,
        :ultracode_sa2a_capability_endpoint,
        "http://127.0.0.1:1/sa2a/capabilities"
      )

      try do
        assert {:error, _transport} = Sa2a.candidates(item(), %{})

        with_sources(%{"sa2a" => Sa2a}, fn ->
          assert %{class: :unresolved} = CapabilityResolver.resolve_item(item(), %{})
        end)
      after
        Application.delete_env(:xaas, :ultracode_sa2a_capability_endpoint)
      end
    end
  end

  defp receipt_path(tmp), do: Path.join(tmp, "capability-resolutions.ndjson")
end
