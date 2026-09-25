defmodule Xaas.Ultracode.RecurrenceTest do
  @moduledoc """
  Qualification of the recurrence edge (`receipt[n] -> reobserve[n+1] ->
  frontier[n+1] -> work-order[n+1]`) as a machine-queryable fact:

    * the edge derives from REAL sealed receipts and the Run's real semantic
      identity -- no fabricated IRIs where the Run carries none;
    * standing receipts only (the `:heartbeat` lifecycle class is excluded);
    * frontier dispositions are the typed loop vocabulary, and satisfied work
      leaves the frontier while everything else licenses an n+1 candidate;
    * every n+1 candidate carries an ORIGIN AUTHORITY and is
      provider-neutral (no provider field; provider identity only in the
      capabilityId left segment, the one lawful surface);
    * determinism: the same rows derive the same edge (replay);
    * an injected frontier source is honored, and a malformed one fails
      CLOSED (`{:error, _}`), never silently replaced by the default.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Recurrence, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  defp semantic_run(provider, overrides \\ []) do
    attrs =
      Map.merge(
        %{
          goal: "recurrence qualification.",
          provider: provider,
          work_order_iri: "urn:sj:wo:recurrence-test",
          checkpoint_iri: "urn:sj:ckpt:recurrence-test",
          graph_digest: "sha256:#{String.duplicate(String.slice(provider, 0, 1) || "a", 64)}",
          repository_identity: "seanchatmangpt/xaas",
          base_sha: String.duplicate("b", 40),
          capability_id: "zcode:fix-build"
        },
        Map.new(overrides)
      )

    Run
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!()
  end

  defp epoch_for(run, cycle, subject) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{run_id: run.id, cycle: cycle, exact_subject: subject, state: :running},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp seal(epoch, outcome, evidence \\ %{}) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: epoch.exact_subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
  end

  # ------------------------------------------------------------------
  # The edge
  # ------------------------------------------------------------------

  describe "recurrence_edge/1" do
    test "an alive-sealed episode is a closed edge: empty frontier BECAUSE the goal is met" do
      run = semantic_run("rec-edge-closed")
      epoch = epoch_for(run, 0, "rec:subject-0")

      # :alive requires the qualifying court (head_verified + fabric pass).
      seal(epoch, :alive, %{
        "head_verified" => true,
        "fabric_verifier" => %{"status" => "pass"}
      })

      assert {:ok, edge} = Recurrence.recurrence_edge(run)
      assert edge.closed? == true
      assert edge.frontier == []
      assert edge.next_work_orders == []
      assert length(edge.receipts) == 1
      assert hd(edge.receipts).outcome == :alive
    end

    test "a partial_alive receipt reobserves onto the frontier and licenses an n+1 candidate with origin authority" do
      run = semantic_run("rec-edge-open")
      epoch = epoch_for(run, 0, "rec:subject-open")
      receipt = seal(epoch, :partial_alive, %{"head_verified" => true})

      assert {:ok, edge} = Recurrence.recurrence_edge(run)
      assert edge.closed? == false

      # reobserve: the LATEST standing per work order (keyed by the
      # receipt's own subject), with its disposition.
      assert [%{work_order: "rec:subject-open", disposition: :reobserve, standing_in: :partial_alive} =
                observed] = edge.reobserve
      assert observed.receipt_id == receipt.id
      assert observed.reconstructed == true

      # frontier: the entry stays eligible.
      assert [%{disposition: :reobserve}] = edge.frontier

      # work-order[n+1]: provider-neutral, origin-authoritative, chained.
      assert [candidate] = edge.next_work_orders

      assert candidate.origin_authority == :ultracode_reactor
      assert candidate.predecessor == "rec:subject-open"
      assert candidate.parent_episode == run.id
      assert candidate.identity == "rec:subject-open@1"
      assert candidate.subject == "rec:subject-open"

      # Provider neutrality: NO provider field anywhere; the capabilityId
      # left segment is the one lawful provider surface.
      refute Map.has_key?(candidate, :provider)
      assert candidate.capability_id == "zcode"

      # Semantic identity carried from the Run, replay binding derived.
      assert candidate.base_sha == run.base_sha
      assert candidate.graph_digest == run.graph_digest
      assert candidate.checkpoint_iri == run.checkpoint_iri
      assert candidate.replay_binding =~ ~r/^sha256:[0-9a-f]{64}$/
    end

    test "each standing outcome maps to its typed disposition (repair/reorder/unsupported stay eligible)" do
      run = semantic_run("rec-edge-dispositions")

      epoches =
        for {subject, i} <- Enum.with_index(~w(a b c d), 0) do
          # Completed epochs (never concurrently-active), one receipt each.
          Epoch
          |> Ash.Changeset.for_create(
            :create,
            %{run_id: run.id, cycle: i, exact_subject: "rec:disp-#{subject}", state: :completed},
            authorize?: false
          )
          |> Ash.create!()
        end

      seal(Enum.at(epoches, 0), :build_broken)
      seal(Enum.at(epoches, 1), :refused)
      seal(Enum.at(epoches, 2), :unsupported)
      seal(Enum.at(epoches, 3), :heartbeat)

      assert {:ok, edge} = Recurrence.recurrence_edge(run)

      dispositions = Enum.sort(Enum.map(edge.reobserve, & &1.disposition))
      assert dispositions == [:reorder, :repair, :unsupported]

      # The heartbeat receipt is NOT standing: exactly 3 receipts counted.
      assert length(edge.receipts) == 3
      assert length(edge.next_work_orders) == 3
    end

    test "latest receipt wins when a work order was sealed twice" do
      run = semantic_run("rec-edge-latest")
      epoch = epoch_for(run, 0, "rec:latest")

      seal(epoch, :build_broken)
      seal(epoch, :alive, %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}})

      assert {:ok, edge} = Recurrence.recurrence_edge(run)
      assert [%{standing_in: :alive, disposition: :satisfied}] = edge.reobserve
      assert edge.closed? == true
    end

    test "a Run with NO semantic identity degrades honestly: epoch subject keys, no fabricated fields" do
      run = semantic_run("rec-edge-bare", work_order_iri: nil, checkpoint_iri: nil, graph_digest: nil, repository_identity: nil, base_sha: nil, capability_id: nil)

      epoch = epoch_for(run, 0, "rec:bare-subject")
      seal(epoch, :blocked)

      assert {:ok, edge} = Recurrence.recurrence_edge(run)
      assert [%{work_order: "rec:bare-subject"}] = edge.reobserve

      [candidate] = edge.next_work_orders
      assert candidate.subject == "rec:bare-subject"
      assert candidate.capability_id == "construction"
      refute Map.has_key?(candidate, :graph_digest)
      refute Map.has_key?(candidate, :base_sha)
      refute Map.has_key?(candidate, :replay_binding)
      assert candidate.origin_authority == :ultracode_reactor
    end

    test "the edge is DETERMINISTIC: same rows, same edge (replay)" do
      run = semantic_run("rec-edge-determinism")
      epoch = epoch_for(run, 0, "rec:det")
      seal(epoch, :partial_alive)

      {:ok, edge1} = Recurrence.recurrence_edge(run)
      {:ok, edge2} = Recurrence.recurrence_edge(run)

      # Only the derivation moment differs; everything derived from rows is
      # byte-stable.
      assert %{edge1 | derived_at: nil} == %{edge2 | derived_at: nil}
    end

    test "an unknown run id is typed" do
      assert {:error, {:run_not_found, _, _}} = Recurrence.recurrence_edge(Ecto.UUID.generate())
    end
  end

  # ------------------------------------------------------------------
  # Injectable frontier source (the sJira seam)
  # ------------------------------------------------------------------

  describe "frontier source seam" do
    test "an injected source REPLACES the default and its entries drive candidates" do
      run = semantic_run("rec-edge-source")
      epoch = epoch_for(run, 0, "rec:source")
      seal(epoch, :partial_alive)

      Application.put_env(:xaas, :ultracode_frontier_source, {__MODULE__, :sJira_frontier})

      on_exit(fn -> Application.delete_env(:xaas, :ultracode_frontier_source) end)

      assert {:ok, edge} = Recurrence.recurrence_edge(run)

      # The injected source's own entries (not the receipt-derived ones).
      assert [%{work_order: "urn:sj:wo:injected"} = entry] = edge.frontier
      assert entry.frontier_source == :injected
      assert [%{predecessor: "urn:sj:wo:injected"}] = edge.next_work_orders
    end

    test "a malformed injected source fails CLOSED (never silently default)" do
      run = semantic_run("rec-edge-source-bad")
      epoch = epoch_for(run, 0, "rec:source-bad")
      seal(epoch, :partial_alive)

      Application.put_env(:xaas, :ultracode_frontier_source, {__MODULE__, :bad_frontier})

      on_exit(fn -> Application.delete_env(:xaas, :ultracode_frontier_source) end)

      assert {:error, {:frontier_source_malformed, _, _}} = Recurrence.recurrence_edge(run)
    end

    def sJira_frontier(_run) do
      {:ok, [%{work_order: "urn:sj:wo:injected", disposition: :repair, standing_in: :blocked, receipt_id: "injected", frontier_source: :injected}]}
    end

    def bad_frontier(_run), do: {:ok, "not a list"}
  end

  # ------------------------------------------------------------------
  # The qualify law (mix xaas.autonomy.qualify's judgment)
  # ------------------------------------------------------------------

  describe "Mix.Tasks.Xaas.Autonomy.Qualify.qualify/1" do
    test "a closed, deterministic, provider-neutral edge judges ALIVE" do
      run = semantic_run("rec-qualify-alive")
      epoch = epoch_for(run, 0, "rec:qualify-alive")

      seal(epoch, :alive, %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}})

      report = Mix.Tasks.Xaas.Autonomy.Qualify.qualify(run)
      assert report.standing == :alive
      assert report.edge.closed? == true
    end

    test "an open edge still judges ALIVE (the law is closure machine-queryability, not goal completion)" do
      run = semantic_run("rec-qualify-open")
      epoch = epoch_for(run, 0, "rec:qualify-open")
      seal(epoch, :partial_alive)

      report = Mix.Tasks.Xaas.Autonomy.Qualify.qualify(run)

      # The frontier licenses exactly one candidate, chained + authorized:
      # the edge is well-formed even though the goal is not yet met.
      assert report.standing == :alive
      assert report.edge.closed? == false
      assert report.edge.next_work_orders == 1
    end

    test "a failing frontier source judges BLOCKED (infrastructure, never a verdict)" do
      run = semantic_run("rec-qualify-blocked")

      Application.put_env(:xaas, :ultracode_frontier_source, {__MODULE__, :bad_frontier})

      on_exit(fn -> Application.delete_env(:xaas, :ultracode_frontier_source) end)

      report = Mix.Tasks.Xaas.Autonomy.Qualify.qualify(run)
      assert report.standing == :blocked
    end
  end

  # ------------------------------------------------------------------
  # Pack-law grounding
  # ------------------------------------------------------------------

  test "pack_law/0 grounds both work-order laws in the admitted packs (or reports absence honestly)" do
    case Recurrence.pack_law() do
      {:ok, facts} ->
        assert facts.origin_authority_law_present? == true
        assert facts.provider_neutrality_law_present? == true

      {:error, :pack_absent} ->
        # The packs are not checked out here; the edge still works, the
        # grounding is just honestly reported absent.
        :ok
    end
  end
end
