defmodule Xaas.Generation.ModificationDetector do
  @moduledoc """
  Generated-file modification detector — the required component that
  flags a manual edit to a file carrying a `Xaas.Generation.ProvenanceHeader`.

  Real, no mocking: reads the real file from disk, extracts its real
  provenance header (if any), and compares the header's declared hash to
  the real hash of the file's own body (the content with the header line
  removed, since the header can't hash itself). This is the direct
  implementation of the ticket's second falsifier: "the generated-file
  modification detector fails to flag a manual edit to a file carrying a
  generated-file provenance header" — `detect/1` must return
  `:modified` in exactly that case.
  """

  alias Xaas.Generation.ProvenanceHeader

  @type result :: :match | :modified | :unmanaged | {:error, term()}

  @spec detect(String.t()) :: result()
  def detect(path) do
    case File.read(path) do
      {:ok, content} -> detect_content(content)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec detect_content(String.t()) :: result()
  def detect_content(content) do
    case ProvenanceHeader.parse(content) do
      nil ->
        :unmanaged

      %{hash: declared_hash} ->
        body = strip_header_line(content)
        actual_hash = Base.encode16(:crypto.hash(:sha256, body), case: :lower)
        if actual_hash == declared_hash, do: :match, else: :modified
    end
  end

  defp strip_header_line(content) do
    content
    |> String.split("\n", parts: 2)
    |> case do
      [_header, rest] -> rest
      [only] -> only
    end
  end
end
