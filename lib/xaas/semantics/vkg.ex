defmodule Xaas.Semantics.VKG do
  @moduledoc """
  XaaS consumer facade for AshR2RML's canonical Virtual Knowledge Graph runtime.

  AshR2RML owns source identity, R2RML mappings, federation planning, execution,
  provenance, receipts, and replay. XaaS owns only the application-facing
  admission and projection boundary. This module never mutates a source, never
  grants authority, and never reconstructs AshR2RML semantics locally.
  """

  alias AshR2RML.VKG, as: Runtime
  alias AshR2RML.VKG.Consumer.{Engineering, GraphQL}
  alias Xaas.Semantics.VKG.{Query, Witness}

  @type observation_result ::
          {:ok, Witness.t()} | {:error, AshR2RML.Refusal.t() | term()}

  @doc "Admit and execute one bounded read-only VKG query."
  @spec observe(Query.t() | map(), keyword()) :: observation_result()
  def observe(query_or_attrs, opts \\ [])

  def observe(%Query{} = query, opts) do
    with {:ok, admitted} <- Query.admit(query),
         {:ok, session} <- Runtime.query(admitted.contract_ids, runtime_opts(admitted, opts)),
         {:ok, witness} <- Witness.from_session(admitted, session) do
      {:ok, witness}
    end
  end

  def observe(attrs, opts) when is_map(attrs) do
    with {:ok, query} <- Query.new(attrs) do
      observe(query, opts)
    end
  end

  @doc "Observe every currently admitted VKG source through one bounded query."
  @spec observe_all(keyword()) :: observation_result()
  def observe_all(opts \\ []) do
    with {:ok, catalog} <- Runtime.catalog(root_opt(opts)),
         ids when ids != [] <- AshR2RML.VKG.Catalog.ids(catalog),
         {:ok, query} <-
           Query.new(%{
             id: "xaas-all-sources",
             contract_ids: ids,
             purpose: :engineering_read,
             max_rows: Keyword.get(opts, :max_rows, 50_000),
             timeout_ms: Keyword.get(opts, :timeout_ms, 30_000),
             merge: Keyword.get(opts, :merge, :union)
           }) do
      observe(query, opts)
    else
      [] -> {:error, :REFUSED_VKG_EMPTY_CATALOG}
      error -> error
    end
  end

  @doc "Project an observed witness into XaaS's engineering read model."
  @spec engineering(Witness.t()) :: map()
  def engineering(%Witness{session: session}), do: Engineering.snapshot(session)

  @doc "Project an observed witness into a read-only GraphQL connection."
  @spec graphql(Witness.t(), keyword()) :: map()
  def graphql(%Witness{session: session}, opts \\ []), do: GraphQL.connection(session, opts)

  @doc "Return the canonical source catalog without acquiring source authority."
  @spec catalog(keyword()) :: {:ok, AshR2RML.VKG.Catalog.t()} | {:error, term()}
  def catalog(opts \\ []), do: Runtime.catalog(root_opt(opts))

  @doc "Return a stable application-facing description of an admitted catalog."
  @spec catalog_snapshot(keyword()) :: {:ok, map()} | {:error, term()}
  def catalog_snapshot(opts \\ []) do
    with {:ok, catalog} <- catalog(opts) do
      {:ok, AshR2RML.VKG.Inspection.catalog(catalog)}
    end
  end

  @doc "Serialize a witness using the canonical AshR2RML serializer."
  @spec encode_witness!(Witness.t()) :: String.t()
  def encode_witness!(%Witness{session: session}) do
    AshR2RML.VKG.Serializer.encode_session!(session)
  end

  @doc "Verify the canonical replay boundary carried by a witness."
  @spec verify(Witness.t()) :: :ok | {:error, term()}
  def verify(%Witness{} = witness), do: Witness.verify(witness)

  defp runtime_opts(%Query{} = query, opts) do
    [
      root: Keyword.get(opts, :root),
      engine: Keyword.get(opts, :engine),
      runner: Keyword.get(opts, :runner),
      engine_version: Keyword.get(opts, :engine_version),
      db_url: Keyword.get(opts, :db_url),
      db_user: Keyword.get(opts, :db_user),
      db_password: Keyword.get(opts, :db_password),
      db_driver: Keyword.get(opts, :db_driver),
      properties_path: Keyword.get(opts, :properties_path),
      max_output_bytes: Keyword.get(opts, :max_output_bytes),
      previous_receipt: Keyword.get(opts, :previous_receipt),
      rows_by_contract: Keyword.get(opts, :rows_by_contract),
      max_rows: query.max_rows,
      timeout_ms: query.timeout_ms,
      merge: query.merge,
      capability: query.capability
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp root_opt(opts) do
    case Keyword.get(opts, :root) do
      nil -> []
      root -> [root: root]
    end
  end
end
