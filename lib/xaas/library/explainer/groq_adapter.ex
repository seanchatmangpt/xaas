defmodule Xaas.Library.Explainer.GroqAdapter do
  @moduledoc """
  Real Groq-backed recommendation explanation, via the real ash_ai
  `prompt/2` generic action (`AshAi.Actions.Prompt`) calling ReqLLM's Groq
  provider.

  Wraps `Xaas.Library.Book`'s `:generate_recommendation_explanation` generic
  action (see lib/xaas/library/book.ex). ReqLLM resolves the Groq API key
  via its own `default_env_key: "GROQ_API_KEY"` lookup (confirmed at
  deps/req_llm/lib/req_llm/providers/groq.ex) -- this module never reads or
  passes the key itself.

  Any network/API/tool-loop error is caught and returned as a tagged
  `{:error, :groq_unavailable, reason}` so
  `Xaas.Library.Explainer.explain/1` can degrade to
  `Xaas.Library.Explainer.TemplateAdapter` per the deck's documented
  graceful-degradation design. This module never falls back itself -- that
  is the caller's (`Explainer`'s) job, keeping this adapter a pure
  real-Groq-or-tagged-error boundary.
  """

  alias Xaas.Library.Book

  @model "groq:llama-3.3-70b-versatile"

  @doc """
  Calls the real Groq-backed generic action. Returns `{:ok, why :: String.t()}`
  on success or `{:error, :groq_unavailable, reason}` on any failure
  (network error, missing/invalid GROQ_API_KEY, API error, malformed
  response, or unexpected exception).
  """
  @spec explain(map()) :: {:ok, String.t()} | {:error, :groq_unavailable, term()}
  def explain(%{
        book_title: _,
        book_author: _,
        book_grade_level: _,
        book_genres: _,
        past_titles: _,
        factor_summary: _
      } = args) do
    input =
      Ash.ActionInput.for_action(Book, :generate_recommendation_explanation, args)

    case Ash.run_action(input, authorize?: false) do
      {:ok, text} when is_binary(text) and text != "" ->
        {:ok, String.trim(text)}

      {:ok, other} ->
        {:error, :groq_unavailable, {:unexpected_result, other}}

      {:error, reason} ->
        {:error, :groq_unavailable, reason}
    end
  rescue
    error -> {:error, :groq_unavailable, error}
  catch
    kind, reason -> {:error, :groq_unavailable, {kind, reason}}
  end

  def explain(args) do
    {:error, :groq_unavailable, {:invalid_args, args}}
  end

  @doc "Model spec string used for this adapter's generic action call."
  @spec model() :: String.t()
  def model, do: @model
end
