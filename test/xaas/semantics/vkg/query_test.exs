defmodule Xaas.Semantics.VKG.QueryTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.VKG.Query

  test "admits a bounded observe-only engineering query" do
    assert {:ok, query} =
             Query.new(%{
               id: "engineering-customer-orders",
               contract_ids: ["customer", "order"],
               purpose: :engineering_read,
               max_rows: 500,
               timeout_ms: 2_000,
               merge: :union
             })

    assert query.authority == :NONE
    assert query.capability == :select
    assert byte_size(Query.digest(query)) == 64
    assert {:ok, ^query} = Query.admit(query)
  end

  test "query identity is deterministic" do
    attrs = %{
      id: "stable-query",
      contract_ids: ["customer", "order"],
      purpose: :knowledge_lookup
    }

    assert {:ok, first} = Query.new(attrs)
    assert {:ok, second} = Query.new(attrs)
    assert Query.digest(first) == Query.digest(second)
  end

  test "duplicate source identities are refused" do
    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY}} =
             Query.new(%{
               id: "ambiguous",
               contract_ids: ["customer", "customer"],
               purpose: :engineering_read
             })
  end

  test "consequential authority is refused at XaaS boundary" do
    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY}} =
             Query.new(%{
               id: "forbidden",
               contract_ids: ["customer"],
               purpose: :engineering_read,
               authority: :write
             })
  end

  test "unknown application purpose is refused" do
    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY}} =
             Query.new(%{
               id: "unknown-purpose",
               contract_ids: ["customer"],
               purpose: :ambient_ai_decision
             })
  end
end
