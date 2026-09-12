defmodule Xaas.Generation.ProvenanceHeader do
  @moduledoc """
  Generated-file provenance headers — the required component defining a
  real, parseable header line every generated projection should carry so
  its origin and expected hash are self-describing.

  Format (a single-line comment, so it embeds in any commented file):

      # xaas:generated generator=<generator_id> source=<source_path> hash=<sha256_hex>

  Real, no mocking: `build/1` formats the line from real data;
  `parse/1` extracts it back out with a plain regex over real file
  content. There is no separate "header registry" — the header lives in
  the file itself, which is the point (self-describing provenance).
  """

  @header_regex ~r/^#\s*xaas:generated\s+generator=(?<generator_id>\S+)\s+source=(?<source_path>\S+)\s+hash=(?<hash>[0-9a-f]{64})\s*$/m

  @type fields :: %{generator_id: String.t(), source_path: String.t(), hash: String.t()}

  @spec build(fields()) :: String.t()
  def build(%{generator_id: generator_id, source_path: source_path, hash: hash}) do
    "# xaas:generated generator=#{generator_id} source=#{source_path} hash=#{hash}"
  end

  @doc """
  Extracts provenance fields from file content. Returns `nil` when no
  header line is present — absence of a header is itself meaningful data
  (a file the modification detector should treat as unmanaged), not an
  error.
  """
  @spec parse(String.t()) :: fields() | nil
  def parse(content) do
    case Regex.named_captures(@header_regex, content) do
      %{"generator_id" => generator_id, "source_path" => source_path, "hash" => hash} ->
        %{generator_id: generator_id, source_path: source_path, hash: hash}

      nil ->
        nil
    end
  end
end
