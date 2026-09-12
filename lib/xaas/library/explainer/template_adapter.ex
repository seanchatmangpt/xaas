defmodule Xaas.Library.Explainer.TemplateAdapter do
  @moduledoc """
  Real, deterministic template-based recommendation explanation.

  This is the pre-existing explanation logic that used to live inline as
  `Xaas.Library.Ranker.explain_recommendation/3`, ported here verbatim so it
  can serve as the real fallback path when the Groq-backed
  `Xaas.Library.Explainer.GroqAdapter` fails (network error, missing
  `GROQ_API_KEY`, API error, etc). `Ranker.explain_recommendation/3` now
  delegates to this module rather than duplicating the logic -- see
  lib/xaas/library/ranker.ex.

  Never bypassed: `Xaas.Library.Explainer.explain/1` always has this as its
  terminal, always-succeeds path.
  """

  alias Xaas.Library.{Book, Checkout, Config}

  @doc """
  Generates a grounded textual explanation and part badges for a recommended
  book based on student history and score factors. Pure, deterministic,
  no network calls -- cannot fail for any well-formed input.
  """
  @spec explain(Book.t(), map(), list(Checkout.t())) :: %{
          why: String.t(),
          parts: list(String.t())
        }
  def explain(book, factors, user_checkouts \\ []) do
    parts = [
      "collaborative #{Float.round(factors.collab, 2)}",
      "semantic #{Float.round(factors.semantic, 2)}",
      "grade fit #{Float.round(factors.grade_fit, 2)}",
      "availability #{Float.round(factors.available, 2)}",
      "diversity #{Float.round(factors.diversity, 2)}"
    ]

    parts =
      if factors.curation > 0.0,
        do: parts ++ ["librarian curation +#{Float.round(Config.weights().curation, 2)}"],
        else: parts

    past_titles =
      user_checkouts
      |> Enum.map(fn
        %Checkout{book: %Book{title: title}} -> title
        _ -> "recent readings"
      end)
      |> Enum.take(2)

    bg_float = to_float(book.grade_level)

    why =
      case past_titles do
        [t1, t2] ->
          "Because you finished #{t1} and #{t2} — both aligned in subject and reading level. This title matches their structure and sits within reading level #{bg_float}."

        [t1] ->
          "Because you finished #{t1}. This title continues the theme and matches your reading level band."

        [] ->
          "Because students in your grade band who explored similar subjects read this next, matching reading level #{bg_float}."
      end

    %{why: why, parts: parts}
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_float(n), do: n
  defp to_float(_), do: to_float(Config.default_grade())
end
