defmodule Xaas.Fabric.Planes.Projection do
  @moduledoc """
  `capability://projection/map` over `Xaas.Semantics.VKG` (AshR2RML). Observes external rows
  through an admitted contract and projects them to Turtle for the law plane. Authority NONE.

  opts: `:contract_ids` (default `["order"]`), `:vkg` (keyword passed to `VKG.observe/2`:
  `engine:`, `rows_by_contract:`, ...), `:graph` (fun `witness_rows -> turtle`, optional).
  """
  @behaviour Xaas.Fabric.Plane

  alias Xaas.Semantics.VKG

  @impl true
  def contract,
    do: %{
      uri: "capability://projection/map",
      semantic_id: "projection.map.vkg.v1",
      realization: "xaas-vkg",
      ceiling: :observe
    }

  @impl true
  def call(:observe, env, facts, opts) do
    ids = Keyword.get(opts, :contract_ids, ["order"])

    query = %{id: env.operation_id, contract_ids: ids, purpose: :engineering_read}

    with {:ok, witness} <- VKG.observe(query, Keyword.get(opts, :vkg, [])),
         :ok <- VKG.verify(witness) do
      rows = witness.session.result.rows
      {:ok, Map.merge(facts, %{"witness" => witness, "rows" => rows, "graph" => turtle(rows)})}
    end
  end

  def call(_stage, _env, _facts, _opts), do: {:error, :unsupported}

  defp turtle(rows) do
    body =
      Enum.map_join(rows, "\n", fn row ->
        subject = row["subject"] || "urn:unknown"
        amount = row["amount"] || "0"
        "<#{subject}> a ex:Payment ; ex:amountMinor #{String.to_integer(to_string(amount))} ."
      end)

    "@prefix ex: <https://xaas.example/fabric#> .\n" <> body <> "\n"
  end
end
