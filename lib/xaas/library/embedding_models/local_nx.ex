defmodule Xaas.Library.EmbeddingModels.LocalNx do
  @moduledoc """
  `AshAi.EmbeddingModel` implementation that wraps the existing, real,
  HTTP-free `Xaas.Library.Embeddings.embed/1` Nx-based text embedding
  function for use by `ash_ai`'s `vectorize` DSL.

  This is the *only* embedding model wired into the library domain -- no
  second/redundant embedding model (e.g. a Groq/OpenAI-backed one) is added
  by this module. `Xaas.Library.Embeddings.embed/1` already computes a
  deterministic, offline, 384-dimensional Nx projection; this module only
  adapts its `{:ok, list(float())} | {:error, term()}` per-string contract
  to `AshAi.EmbeddingModel`'s per-list-of-strings `generate/2` callback.

  ## Infrastructure status: BLOCKED

  This module and the `vectorize` wiring on `Xaas.Library.Book` are real,
  compiling AshPostgres/Ash.Vector code. They are **not** yet a working
  end-to-end vector column on the current dev database: the running dev
  Postgres instance has zero rows for `vector` in `pg_available_extensions`
  (confirmed via `psql ... -c "select * from pg_available_extensions where
  name='vector';"`), so `CREATE EXTENSION vector` fails at migration time
  until the Postgres image/host is swapped for one that ships the pgvector
  extension binary (e.g. the `pgvector/pgvector` Docker image). See the
  moduledoc on `Xaas.Library.Book` for the exact blocking hop.
  """

  use AshAi.EmbeddingModel

  alias Xaas.Library.Embeddings

  @dimensions 384

  @impl true
  def dimensions(_opts), do: @dimensions

  @impl true
  def generate(texts, _opts) when is_list(texts) do
    texts
    |> Enum.reduce_while({:ok, []}, fn text, {:ok, acc} ->
      case Embeddings.embed(text || "") do
        {:ok, vector} -> {:cont, {:ok, [vector | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, vectors} -> {:ok, Enum.reverse(vectors)}
      {:error, reason} -> {:error, reason}
    end
  end
end
