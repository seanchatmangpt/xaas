defmodule Xaas.Semantics.VKG.FamilyCourtW984hnTest do
  @moduledoc """
  Lane W984hn unclaimed-family court for `lib/xaas/semantics/vkg/` + `vkg.ex`
  — the branches NOT courted by W650h33b (query_depth), W984dt (ledger), or
  W984ex (graphql surface; no receipt landed, surface unclaimed at write time).

  Chicago style: real `Xaas.Semantics.VKG` modules over the real test engine
  (`Xaas.Test.VKGObservationEngine`), real `AshR2RML` sessions, zero mocks and
  zero stubs. Every assertion names the mutation it kills.

  Falsifier: any mutation that removes one of the courted branches and still
  yields `{:ok, _}` / `:ok` on the paired assertion.
  """

  use ExUnit.Case, async: true

  alias AshR2RML.Refusal
  alias Xaas.Semantics.VKG
  alias Xaas.Semantics.VKG.{Query, Replay, Witness, Workspace}

  @engine Xaas.Test.VKGObservationEngine

  describe "VKG.observe_all/1 happy path (vkg.ex:38)" do
    test "observes every admitted source through one bounded query with witness identity" do
      # Mutation rationale: kills the mutation that makes observe_all/1 drop the
      # catalog ids (calling observe with an empty/hardcoded contract set) — the
      # witness must carry exactly the full admitted source set and be sealed by
      # the same canonical session pipeline as a single-source observe.
      assert {:ok, catalog} = VKG.catalog()
      ids = AshR2RML.VKG.Catalog.ids(catalog)
      assert ids != []

      assert {:ok, %Witness{} = witness} = VKG.observe_all(engine: @engine)

      assert witness.contract_ids == ids
      assert witness.row_count == length(ids)
      assert witness.authority == :NONE
      assert witness.standing == :observed_not_actuated
      assert String.starts_with?(witness.id, "xaas-vkg-witness-")
      assert byte_size(witness.query_sha256) == 64
      assert :ok = Witness.verify(witness)

      # determinism: two observe_all runs over the same catalog seal identical
      # identity (kills the mutation that folds wall-clock into witness id)
      assert {:ok, witness2} = VKG.observe_all(engine: @engine)
      assert witness2.id == witness.id
      assert witness2.receipt_id == witness.receipt_id
    end
  end

  describe "facade map-path admission refusal (vkg.ex:29)" do
    test "an unadmittable map is refused before any observation exists" do
      # Mutation rationale: kills the mutation that makes the map clause of
      # observe/2 skip Query.new/1 admission (returning the query unadmitted) —
      # an unadmitted purpose would then reach the canonical runtime.
      assert {:error, %Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :purpose}} =
               VKG.observe(%{
                 id: "w984hn-bad-purpose",
                 contract_ids: ["customer"],
                 purpose: :not_a_purpose
               })
    end
  end

  describe "Witness.from_session contract-set mismatch (witness.ex:132)" do
    test "an admitted query paired with a foreign real session is refused at :contract_ids" do
      # Mutation rationale: kills the mutation that deletes exact_contracts/2 —
      # under that mutation a witness could be minted whose envelope claims one
      # source set while the canonical session federated a different one.
      assert {:ok, customer_query} =
               Query.new(%{
                 id: "w984hn-customer",
                 contract_ids: ["customer"],
                 purpose: :engineering_read
               })

      assert {:ok, order_session} =
               observe_session(%{
                 id: "w984hn-order-session",
                 contract_ids: ["order"],
                 purpose: :engineering_read
               })

      assert {:error,
              %Refusal{code: :REFUSED_XAAS_VKG_WITNESS, subject: :contract_ids} = refusal} =
               Witness.from_session(customer_query, order_session)

      assert refusal.evidence == %{query: ["customer"], plan: ["order"]}
    end
  end

  describe "Witness.verify authority branch (witness.ex:126)" do
    test "a witness whose authority field is no longer :NONE refuses" do
      # Mutation rationale: kills the mutation that drops the
      # `witness.authority == :NONE` conjunct from verify/1 — a witness that
      # somehow claims actuation authority would then verify cleanly.
      assert {:ok, witness} =
               VKG.observe(
                 %{id: "w984hn-authority", contract_ids: ["customer"], purpose: :engineering_read},
                 engine: @engine
               )

      elevated = %{witness | authority: :DO}

      assert {:error, %Refusal{code: :REFUSED_XAAS_VKG_WITNESS, subject: :witness}} =
               Witness.verify(elevated)
    end
  end

  describe "Replay.workspace error propagation (replay.ex:52)" do
    test "one tampered witness halts the whole workspace replay with its refusal" do
      # Mutation rationale: kills the mutation that swaps reduce_while halt for
      # cont (dropping the failed witness's refusal) — a workspace containing a
      # desynchronized witness would then replay as deterministic.
      assert {:ok, good} =
               VKG.observe(
                 %{id: "w984hn-good", contract_ids: ["customer"], purpose: :engineering_read},
                 engine: @engine
               )

      assert {:ok, order} =
               VKG.observe(
                 %{id: "w984hn-order", contract_ids: ["order"], purpose: :engineering_read},
                 engine: @engine
               )

      assert {:ok, workspace} = Workspace.build("w984hn-ws", [good, order])
      assert {:ok, _} = Replay.workspace(workspace)

      tampered = %{order | row_count: order.row_count + 1}
      bad_workspace = %{workspace | witnesses: [good, tampered]}

      assert {:error, %Refusal{code: :REFUSED_XAAS_VKG_WITNESS}} =
               Replay.workspace(bad_workspace)
    end
  end

  describe "VKG.graphql/2 cursor semantics through the facade (w984ex-unclaimed)" do
    test "cursor roundtrip pages the sealed result order with correct pageInfo" do
      # Mutation rationale: kills the mutation that breaks cursor binding to the
      # result digest (e.g. start_index/3 ignoring the row-sha conjunct) — a
      # cursor from one result would then page a different sealed result.
      assert {:ok, witness} =
               VKG.observe(
                 %{
                   id: "w984hn-graphql",
                   contract_ids: ["order"],
                   purpose: :engineering_read
                 },
                 engine: @engine,
                 rows_by_contract: %{
                   "order" => [
                     %{"subject" => "urn:order:10", "amount" => "42"},
                     %{"subject" => "urn:order:11", "amount" => "43"}
                   ]
                 }
               )

      assert {:ok, page1} = unwrap(VKG.graphql(witness, first: 1))

      assert [%{"node" => %{"subject" => first_subject}}] = page1["edges"]
      assert first_subject in ["urn:order:10", "urn:order:11"]
      assert page1["pageInfo"]["hasNextPage"] == true
      assert page1["pageInfo"]["hasPreviousPage"] == false
      assert page1["authority"] == "NONE"
      assert page1["resultSha256"] == witness.result_sha256

      cursor = page1["pageInfo"]["endCursor"]
      assert is_binary(cursor)

      assert {:ok, page2} = unwrap(VKG.graphql(witness, first: 1, after: cursor))
      assert [%{"node" => %{"subject" => second_subject}}] = page2["edges"]
      # the cursor advances through the sealed result order: page 2 yields the
      # row page 1 did not, exactly once per row overall
      assert second_subject != first_subject
      assert Enum.sort([first_subject, second_subject]) == ["urn:order:10", "urn:order:11"]
      assert page2["pageInfo"]["hasPreviousPage"] == true
      assert page2["pageInfo"]["hasNextPage"] == false
      assert page2["pageInfo"]["endCursor"] != nil

      # paging past the end yields an empty edge list with endCursor nil
      assert {:ok, page3} = unwrap(VKG.graphql(witness, first: 1, after: page2["pageInfo"]["endCursor"]))
      assert page3["edges"] == []
      assert page3["pageInfo"]["endCursor"] == nil
    end

    test "a forged cursor is refused at the typed boundary, never silently restarted" do
      # Mutation rationale: kills the mutation that makes start_index/3 swallow a
      # malformed cursor and restart pagination from 0 — a tampered cursor would
      # then silently rewind the read model to the first page.
      assert {:ok, witness} =
               VKG.observe(
                 %{id: "w984hn-forged", contract_ids: ["customer"], purpose: :knowledge_lookup},
                 engine: @engine
               )

      assert {:error, %Refusal{code: :REFUSED_VKG_QUERY_PLAN, subject: :cursor}} =
               VKG.graphql(witness, first: 1, after: "w984hn-forged-cursor")
    end
  end

  defp observe_session(attrs) do
    with {:ok, query} <- Query.new(attrs),
         {:ok, session} <-
           AshR2RML.VKG.query(query.contract_ids, engine: @engine) do
      {:ok, session}
    end
  end

  defp unwrap({:error, _} = error), do: error
  defp unwrap(conn) when is_map(conn), do: {:ok, conn}
end
