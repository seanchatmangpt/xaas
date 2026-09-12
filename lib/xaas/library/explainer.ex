defmodule Xaas.Library.Explainer do
  @moduledoc """
  Contract/behaviour for generating a student-facing recommendation
  explanation, with a real Groq-backed primary path and a real
  template-based fallback on any failure.

  Per the Next Read real-integrations charter's documented
  graceful-degradation design: `explain/1` first attempts
  `Xaas.Library.Explainer.GroqAdapter` (real ash_ai `prompt/2` generic
  action calling Groq via ReqLLM); on any network/API error it degrades to
  `Xaas.Library.Explainer.TemplateAdapter` (the pre-existing deterministic
  template logic, ported verbatim, never bypassed or deleted).
  """

  alias Xaas.Library.Explainer.{GroqAdapter, TemplateAdapter}
  alias Xaas.Library.{Book, Checkout}

  @type factors :: %{
          required(:collab) => float(),
          required(:semantic) => float(),
          required(:grade_fit) => float(),
          required(:available) => float(),
          required(:diversity) => float(),
          required(:curation) => float()
        }

  @type result :: %{why: String.t(), parts: list(String.t()), source: :groq | :template}

  @doc """
  Behaviour callback: generate an explanation for `book`, given the
  ranker's `factors` and the student's `user_checkouts` history. Real
  implementations must never raise -- any failure degrades to the template
  path.
  """
  @callback explain(Book.t(), factors(), list(Checkout.t())) :: result()

  @behaviour __MODULE__

  @doc """
  Generates the explanation, attempting the real Groq-backed path first
  and falling back to the real template adapter on any failure. Always
  succeeds (the template adapter is pure and cannot fail for a well-formed
  book/factors input).
  """
  @impl __MODULE__
  @spec explain(Book.t(), factors(), list(Checkout.t())) :: result()
  def explain(book, factors, user_checkouts \\ []) do
    case try_groq(book, factors, user_checkouts) do
      {:ok, why} ->
        %{why: why, parts: template_parts(factors), source: :groq}

      {:error, :groq_unavailable, _reason} ->
        template = TemplateAdapter.explain(book, factors, user_checkouts)
        Map.put(template, :source, :template)
    end
  end

  defp try_groq(book, factors, user_checkouts) do
    past_titles =
      user_checkouts
      |> Enum.map(fn
        %Checkout{book: %Book{title: title}} -> title
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.take(2)

    args = %{
      book_title: book.title,
      book_author: book.author,
      book_grade_level: to_string(book.grade_level),
      book_genres: book.genres || [],
      past_titles: past_titles,
      factor_summary: factor_summary(factors)
    }

    GroqAdapter.explain(args)
  end

  defp factor_summary(factors) do
    "collab=#{r(factors.collab)} semantic=#{r(factors.semantic)} grade_fit=#{r(factors.grade_fit)} " <>
      "availability=#{r(factors.available)} diversity=#{r(factors.diversity)} curation=#{r(factors.curation)}"
  end

  defp template_parts(factors) do
    [
      "collaborative #{r(factors.collab)}",
      "semantic #{r(factors.semantic)}",
      "grade fit #{r(factors.grade_fit)}",
      "availability #{r(factors.available)}",
      "diversity #{r(factors.diversity)}"
    ]
  end

  defp r(x), do: Float.round(x * 1.0, 2)
end
