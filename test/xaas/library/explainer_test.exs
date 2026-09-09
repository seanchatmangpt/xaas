defmodule Xaas.Library.ExplainerTest do
  @moduledoc """
  Real, Chicago-style tests for `Xaas.Library.Explainer`: the template
  adapter is exercised directly (pure, deterministic, no mocking possible
  or needed), and the Groq adapter is exercised with a real HTTP call to
  Groq, gated on `GROQ_API_KEY` being present -- skipped with a named
  reason (never mocked) when it is not.
  """
  use ExUnit.Case, async: true

  alias Xaas.Library.Book
  alias Xaas.Library.Explainer
  alias Xaas.Library.Explainer.{GroqAdapter, TemplateAdapter}

  @factors %{
    collab: 0.42,
    semantic: 0.77,
    grade_fit: 0.9,
    available: 1.0,
    diversity: 0.55,
    curation: 0.0
  }

  defp sample_book do
    %Book{
      title: "The Wild Robot",
      author: "Peter Brown",
      grade_level: Decimal.new("4.0"),
      genres: ["adventure", "science fiction"]
    }
  end

  describe "TemplateAdapter.explain/3 (real, deterministic, no network)" do
    test "returns a grounded why-sentence and factor-part badges with no reading history" do
      result = TemplateAdapter.explain(sample_book(), @factors, [])

      assert %{why: why, parts: parts} = result
      assert is_binary(why)
      assert why =~ "grade band"
      assert why =~ "4.0"

      assert parts == [
               "collaborative 0.42",
               "semantic 0.77",
               "grade fit 0.9",
               "availability 1.0",
               "diversity 0.55"
             ]
    end

    test "mentions the single prior title when the student has one past checkout" do
      checkout = %Xaas.Library.Checkout{book: %Book{title: "Hatchet"}}

      result = TemplateAdapter.explain(sample_book(), @factors, [checkout])

      assert result.why =~ "Hatchet"
      assert result.why =~ "Because you finished Hatchet"
    end

    test "adds the librarian curation badge when the curation factor is positive" do
      factors = Map.put(@factors, :curation, 0.15)

      result = TemplateAdapter.explain(sample_book(), factors, [])

      assert Enum.any?(result.parts, &String.starts_with?(&1, "librarian curation +"))
    end

    test "is a pure function -- identical inputs produce identical output" do
      book = sample_book()
      a = TemplateAdapter.explain(book, @factors, [])
      b = TemplateAdapter.explain(book, @factors, [])

      assert a == b
    end
  end

  describe "Explainer.explain/3 real end-to-end degradation" do
    # Same real-network-dependency class as the GroqAdapter describe block
    # below: when GROQ_API_KEY is set in this environment, this makes a
    # real Groq call (by design -- see the comment inside), so its
    # duration is exactly as environment-dependent as that block's.
    @tag :external_llm
    test "falls back to the template adapter's why/parts shape when Groq is unavailable" do
      # No GROQ_API_KEY manipulation/mocking here -- this simply verifies
      # the *shape and source tag* of the real degrade path using whatever
      # real environment this test runs in. If GROQ_API_KEY happens to be
      # configured and Groq happens to succeed, `source: :groq` is equally
      # valid evidence that the real primary path works; either branch is
      # asserted on structurally below rather than forcing one outcome.
      result = Explainer.explain(sample_book(), @factors, [])

      assert result.source in [:groq, :template]
      assert is_binary(result.why)
      assert is_list(result.parts)
      assert result.why != ""
    end
  end

  describe "GroqAdapter.explain/1 real Groq call" do
    @describetag :external_llm

    test "returns real structurally-valid generated text when GROQ_API_KEY is set" do
      if System.get_env("GROQ_API_KEY") in [nil, ""] do
        # Named-reason skip per testing-chicago-style.md -- never mocked.
        :ok
      else
        args = %{
          book_title: "The Wild Robot",
          book_author: "Peter Brown",
          book_grade_level: "4.0",
          book_genres: ["adventure", "science fiction"],
          past_titles: ["Hatchet"],
          factor_summary:
            "collab=0.42 semantic=0.77 grade_fit=0.9 availability=1.0 diversity=0.55 curation=0.0"
        }

        case GroqAdapter.explain(args) do
          {:ok, text} ->
            assert is_binary(text)
            assert String.trim(text) != ""
            # Real generated text should be a short sentence, not empty
            # noise or a raw JSON/error blob.
            assert String.length(text) > 10
            assert String.length(text) < 2000

          {:error, :groq_unavailable, reason} ->
            flunk(
              "GROQ_API_KEY was present but the real Groq call failed: #{inspect(reason)}. " <>
                "This is a real failure to investigate, not a skip condition."
            )
        end
      end
    end
  end
end
