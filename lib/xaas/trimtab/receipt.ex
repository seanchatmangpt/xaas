defmodule Xaas.Trimtab.Receipt do
  alias Xaas.Trimtab.{Hash, Subject}
  @enforce_keys [:id, :subject_digest, :provider_id, :input_digest, :output_digest]
  defstruct [
    :id,
    :subject_digest,
    :provider_id,
    :input_digest,
    :output_digest,
    :failed_edges,
    :epoch
  ]

  def seal(%Subject{digest: d}, p, input, output, opts \\ []) do
    c = %{
      subject_digest: d,
      provider_id: p,
      input_digest: Hash.sha256(input),
      output_digest: Hash.sha256(output),
      failed_edges: Keyword.get(opts, :failed_edges, []),
      epoch: Keyword.get(opts, :epoch, 0)
    }

    struct!(__MODULE__, Map.put(c, :id, Hash.sha256(c)))
  end
end
