defmodule Xaas.EUAIAct.CorpusLoader do
  @moduledoc """
  Loads the EU AI Act obligation corpus (W520 substrate) from
  `docs/eu_ai_act/corpus.json`.

  Contract: each corpus line is a map with at least `line_id`, `text`, `kind`.
  Raises a typed, lane-attributed error if the corpus has not landed yet.
  """

  @corpus_path "docs/eu_ai_act/corpus.json"

  @typed_message """
  EUAI-Act corpus absent: #{File.cwd!()}/#{@corpus_path} not found.
  Substrate owned by lane W520 (corpus.json). This suite (W526) cannot run \
  until W520 lands the corpus. REFUSED(EUAIA_CORPUS_MISSING_W520).
  """

  defp corpus_path, do: Path.join(File.cwd!(), @corpus_path)

  @doc "Full raw corpus as a list of maps (decoded JSON objects)."
  @spec lines :: [map()]
  def lines do
    path = corpus_path()

    unless File.exists?(path) do
      raise RuntimeError, @typed_message
    end

    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{"titles" => titles}} when is_list(titles) ->
            Enum.flat_map(titles, fn title ->
              for article <- title["articles"] || [], line <- article["lines"] || [], do: line
            end)

          {:ok, other} ->
            raise RuntimeError,
                  "corpus.json must be {\"titles\": [...]} -- got keys: #{inspect(other |> Map.keys() |> Enum.sort())}"

          {:error, reason} ->
            raise RuntimeError, "corpus.json is not valid JSON: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise RuntimeError, "cannot read corpus: #{inspect(reason)} -- " <> @typed_message
    end
  end

  @doc "One corpus line by its line_id, or nil."
  @spec line(String.t()) :: map() | nil
  def line(line_id) when is_binary(line_id) do
    lines() |> Enum.find(fn l -> l["line_id"] == line_id end)
  end

  @doc "Count of obligation lines in the corpus."
  @spec counts :: non_neg_integer()
  def counts, do: length(lines())
end
