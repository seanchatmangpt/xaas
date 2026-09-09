defmodule XaasWeb.A2A.NextReadUserAgent do
  @moduledoc """
  Real A2A (Agent-to-Agent, https://google.github.io/A2A/) server agent that
  simulates a Next Read end user (a student persona borrowing/browsing
  books) grounded in the formal HDDL Task Calculus (docs/hddl/next-read.hddl).
  Built so an MCP-speaking LLM (or any A2A client) can drive `Xaas.Library`
  the same way a human reader would through `XaasWeb.NextRead.ReaderLive` --
  real Ash reads/creates with verified preconditions, not a stub.
  """

  use A2A.Agent,
    name: "next-read-user",
    description: "Simulates a Next Read reader (student) persona for end-to-end multi-agent testing with HDDL task calculus",
    skills: [
      %{
        id: "browse",
        name: "Browse books",
        description: "List books for a grade band as a given user actor (HDDL task: MCP-INSPECT-CATALOG)",
        tags: ["next-read", "library", "hddl"]
      },
      %{
        id: "checkout",
        name: "Checkout a book",
        description: "Borrow a book as a given user actor (HDDL task: A2A-SIMULATE-USER-CIRCULATION / checkout-book)",
        tags: ["next-read", "library", "hddl"]
      },
      %{
        id: "hddl-plan",
        name: "HDDL Plan Inspection",
        description: "Inspect the formal HDDL compound tasks, methods, and epistemic receipts for Next Read",
        tags: ["next-read", "hddl", "calculus"]
      }
    ]

  alias Xaas.Library.{Book, Checkout}
  alias Xaas.Library.Changes.WriteActorResolutionAudit

  @internal_api_caller_id "internal_api_token"

  @impl A2A.Agent
  def handle_message(message, _context) do
    text = A2A.Message.text(message) || ""

    case parse(text) do
      {:ok, :hddl_plan} ->
        {:reply, [A2A.Part.Text.new(hddl_plan_summary())]}

      {:ok, {:ok, actor}, command} ->
        run(actor, command)

      {:ok, {:error, :unauthorized_actor}, _command} ->
        {:error, "as:<user_id> denied: no active persona grant for this caller (HDDL precondition failed: persona-granted)"}

      :error ->
        {:input_required, [A2A.Part.Text.new(usage())]}
    end
  end

  defp usage do
    "Expected: \"as:<user_id|guest> browse grade:<n>\" | " <>
      "\"as:<user_id|guest> recommend grade:<n>\" | " <>
      "\"as:<user_id> checkout book:<book_id> school:<school_id>\" | " <>
      "\"hddl:plan\""
  end

  defp hddl_plan_summary do
    """
    [HDDL Domain: next-read]
    Compound Tasks:
      - NEXT-READ-DUAL-PERSONA-EXPERIENCE (Method: m-dual-persona-split-experience)
      - STUDENT-DISCOVER-AND-CHECKOUT (Methods: m-student-discover-and-checkout-available, m-student-discover-and-place-hold)
      - LIBRARIAN-ADVISORY-AND-CURATE (Method: m-librarian-advisory-and-curate)
      - A2A-SIMULATE-USER-CIRCULATION (Method: m-a2a-simulate-user-circulation)
    Preconditions Enforced: (persona-granted ?token ?student), (book-available ?book)
    Receipt Model: Sealed idempotency keys + Epistemic Standing (DO vs CLAIM)
    """
  end

  defp parse("hddl:plan"), do: {:ok, :hddl_plan}

  defp parse(text) do
    with [_, actor_ref, rest] <- Regex.run(~r/^as:(\S+)\s+(.+)$/, text) do
      {:ok, resolve_actor(actor_ref, @internal_api_caller_id), rest}
    else
      _ -> :error
    end
  end

  defp resolve_actor("guest", _caller_id), do: {:ok, nil}

  defp resolve_actor(user_id, caller_id) do
    case Xaas.Library.PersonaGrant.active_for(caller_id, user_id, authorize?: false) do
      {:ok, [_grant | _]} ->
        case Ash.get(Xaas.Accounts.User, user_id, authorize?: false) do
          {:ok, user} ->
            WriteActorResolutionAudit.write(%{caller_id: caller_id, user_id: user_id, outcome: "allowed"})
            {:ok, user}

          {:error, _} ->
            WriteActorResolutionAudit.write(%{caller_id: caller_id, user_id: user_id, outcome: "denied"})
            {:error, :unauthorized_actor}
        end

      {:ok, []} ->
        WriteActorResolutionAudit.write(%{caller_id: caller_id, user_id: user_id, outcome: "denied"})
        {:error, :unauthorized_actor}

      {:error, _} ->
        WriteActorResolutionAudit.write(%{caller_id: caller_id, user_id: user_id, outcome: "denied"})
        {:error, :unauthorized_actor}
    end
  end

  defp run(actor, command) do
    cond do
      match = Regex.run(~r/^(?:browse|recommend)\s+grade:(\d+)/, command) ->
        [_, grade_str] = match
        grade = String.to_integer(grade_str)
        browse(actor, grade)

      match = Regex.run(~r/^checkout\s+book:(\S+)\s+school:(\S+)/, command) ->
        [_, book_id, school_id] = match
        checkout(actor, book_id, school_id)

      true ->
        {:input_required, [A2A.Part.Text.new(usage())]}
    end
  end

  defp browse(actor, grade) do
    case Book
         |> Ash.Query.for_read(:by_grade_band, %{min_grade: grade - 1, max_grade: grade + 1})
         |> Ash.read(actor: actor) do
      {:ok, books} ->
        summary =
          books
          |> Enum.map(&"#{&1.title} by #{&1.author} (grade #{&1.grade_level}, #{&1.available_copies} available)")
          |> Enum.join("; ")

        text = if books == [], do: "No books found for grade #{grade}.", else: "Found #{length(books)}: #{summary}"
        {:reply, [A2A.Part.Text.new(text)]}

      {:error, error} ->
        {:error, "browse failed: #{Exception.message(error)}"}
    end
  end

  defp checkout(actor, book_id, school_id) do
    if actor == nil do
      {:reply, [A2A.Part.Text.new("checkout requires a real as:<user_id> actor, not guest (HDDL actor-resolved failed)")]}
    else
      params = %{book_id: book_id, user_id: actor.id, school_id: school_id}
      idempotency_key = "checkout:#{book_id}:#{actor.id}:#{school_id}"

      case Xaas.Actuation.run(Checkout, :borrow, params,
             idempotency_key: idempotency_key,
             actor: actor,
             authorize?: true,
             authority: %{kind: "a2a_next_read_user_agent", source: "checkout"}
           ) do
        {:ok, %{result: checkout}} ->
          {:reply, [A2A.Part.Text.new("Checked out book #{checkout.book_id} for user #{checkout.user_id} (checkout #{checkout.id}) [HDDL: receipt-sealed]")]}

        {:error, error} ->
          {:error, "checkout failed: #{inspect(error)}"}
      end
    end
  end
end
