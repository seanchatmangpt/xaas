defmodule Xaas.Trimtab.Subject do
  alias Xaas.Trimtab.Hash
  @enforce_keys [:id, :source_sha]
  defstruct [:id, :source_sha, :provenance, :digest]

  def new(id, sha, p \\ %{})
      when is_binary(id) and byte_size(id) > 0 and is_binary(sha) and byte_size(sha) > 0 do
    c = %{id: id, source_sha: sha, provenance: p}
    {:ok, struct!(__MODULE__, Map.put(c, :digest, Hash.sha256(c)))}
  end

  def new(_, _, _), do: {:error, :invalid_subject}
  def same?(%__MODULE__{digest: d}, %__MODULE__{digest: d}), do: true
  def same?(_, _), do: false
end
