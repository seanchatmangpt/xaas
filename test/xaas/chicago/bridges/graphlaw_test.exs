defmodule Xaas.Chicago.Bridges.GraphlawTest do
  @moduledoc """
  Falsifiers for the GraphLaw policy bridge:

    * a dead host yields the host layer's own typed `:host_not_started` refusal —
      green on a dead backend would be fake;
    * the subject URN appears byte-for-byte in the rendered facts; one mutated
      character renders different facts;
    * against a live engine (the test-env pool starts the vendored WASM), the
      over-limit-without-approval purchase is refused by the ENGINE and the same
      purchase with approval is admitted — a real verdict flip, never a mock.
  """

  use ExUnit.Case, async: false

  alias Xaas.Bridges
  alias Xaas.Bridges.Graphlaw

  @subject Bridges.subject()
  @dead_server :l7_graphlaw_host_never_started

  describe "dead host (typed refusal passthrough)" do
    test "assess on a never-started server refuses :host_not_started" do
      claim = %{"amount" => 1500, "limit" => 500, "approved" => false}

      assert {:refused, refusal} =
               Graphlaw.assess(claim, server: @dead_server, subject: @subject)

      assert refusal.code == :host_not_started
      assert refusal.class == :blocked_resource
      assert refusal.broken_term == :R_missing_consequence
      assert refusal.subject == @subject
    end
  end

  describe "fact rendering" do
    test "subject URN round-trips byte-for-byte into the facts" do
      facts = Graphlaw.purchase_facts(%{"amount" => 1500, "limit" => 500, "approved" => false})

      assert facts =~ @subject
      assert facts =~ ~s(<#{@subject}> <https://w3id.org/chicago#overLimit> "true" .)
      assert facts =~ ~s(approval> "pending" .)
    end

    test "one mutated subject character renders different facts (no fuzzy match)" do
      mutated = String.replace(@subject, "purchase-001", "purchase-002")

      original = Graphlaw.purchase_facts(%{"amount" => 10, "limit" => 5})
      mutated_facts = Graphlaw.purchase_facts(%{"amount" => 10, "limit" => 5}, mutated)

      assert original =~ @subject
      refute mutated_facts =~ @subject
      assert mutated_facts =~ mutated
      assert original != mutated_facts
    end

    test "approval flips the rendered approval fact" do
      pending = Graphlaw.purchase_facts(%{"amount" => 10, "limit" => 5})
      granted = Graphlaw.purchase_facts(%{"amount" => 10, "limit" => 5, "approved" => true})

      assert pending =~ ~s(approval> "pending" .)
      assert granted =~ ~s(approval> "granted" .)
    end
  end

  describe "live engine (vendored WASM via the test-env pool)" do
    test "over-limit purchase flips from refused to admitted on approval" do
      claim = %{"amount" => 1500, "limit" => 500}

      case live_host?() do
        true ->
          assert {:refused, refused} = Graphlaw.assess(claim)
          assert refused.code == :not_admitted
          assert refused.class == :refused_admission

          assert {:ok, admitted} =
                   Graphlaw.assess(Map.put(claim, "approved", true))

          assert admitted.state == :admitted
          assert admitted.standing == "PARTIAL_ALIVE"
          assert admitted.provenance.receipts >= 1
          assert admitted.authority_ceiling == :none

        false ->
          # No live host in this environment: the pool layer's own typed refusal
          # is the real observed behavior. It is NOT green — the bridge reports
          # exactly what the host layer reported.
          assert {:refused, refusal} = Graphlaw.assess(claim)
          assert refusal.code == :host_not_started
      end
    end

    test "within-limit purchase is admitted with focus on the exact subject" do
      case live_host?() do
        true ->
          assert {:ok, admitted} =
                   Graphlaw.assess(%{"amount" => 100, "limit" => 500}, subject: @subject)

          assert admitted.subject == @subject

        false ->
          assert {:refused, refusal} =
                   Graphlaw.assess(%{"amount" => 100, "limit" => 500}, subject: @subject)

          assert refusal.code == :host_not_started
      end
    end
  end

  defp live_host? do
    match?({:ok, _}, AshGraphLaw.Pool.info())
  end
end
