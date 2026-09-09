defmodule XaasWeb.A2A.NextReadUserAgent do
  @moduledoc """
  Real A2A (Agent-to-Agent, https://google.github.io/A2A/) server agent that
  simulates a Next Read end user (a student persona borrowing/browsing
  books). Built so an MCP-speaking LLM (or any A2A client) can drive
  `Xaas.Library` the same way a human reader would through
  `XaasWeb.NextRead.ReaderLive` -- real Ash reads/creates, not a stub.

  ## Why this exists (per explicit user direction)

  MCP tools (`Xaas.Library`'s `tools do` block, wired at `/mcp`) expose a
  fixed, pre-declared set of read-only actions to a single calling agent.
  A2A is complementary: it lets multiple *simulated user personas* converse
  with the app turn-by-turn (multi-turn `A2A.Agent` tasks), each resolving
  to its own actor, so "ultracode" driving several personas at once can
  exercise Next Read's real flows (browse -> recommend -> checkout) the
  way concurrent real students would, not just one fixed tool call.

  ## Real actor resolution -- and a disclosed, unresolved authorization gap

  Every message must open with `as:<user_id>` naming a real
  `Xaas.Accounts.User` id (or the literal `as:guest` for an unauthenticated
  browse-only persona). `resolve_actor/1` loads that user via
  `Ash.get(..., authorize?: false)` and threads it through every Ash call
  as `actor:` -- Ash's own policies on `Book`/`Checkout`/`Curation`
  (currently `authorize_if always()` for every action type, see those
  resources' own `policies do` blocks) are what actually decide what the
  resolved actor can do; this agent adds no privilege of its own beyond
  what those policies already grant to every actor.

  DISCLOSED GAP (real finding, this session's adversarial ERRC review):
  `as:<user_id>` is a bare, self-asserted claim with **no verification
  that the A2A caller is actually authorized to act as that user** -- any
  holder of the shared `INTERNAL_API_TOKEN` bearer token can impersonate
  any `Xaas.Accounts.User` id it can guess or enumerate. This is a real
  security gap for a production-facing surface, not a documentation nit.
  It is tolerable ONLY under this agent's actual intended use --
  ultracode-driven simulated personas in a dev/test context, exercising
  Next Read's flows the way concurrent real students would -- and is NOT
  safe to expose as-is to an untrusted caller population. A real fix would
  bind the A2A caller's own authenticated identity to the actor it may
  assert (analogous to closing `ResolveOrgActor`'s caller-asserted-not-
  authenticated `X-Org-Id` gap, which carries the identical disclosed
  limitation -- see that plug's own moduledoc). Not fixed in this pass;
  named here so it is not silently relied upon as safe.

  `Checkout.borrow` (used by the `checkout` command below) is routed
  through `Xaas.Actuation.run/4`, the same receipted, idempotency-keyed
  admission path used by `Xaas.Marketplace.Provider.actuate_status`. The
  idempotency key is deterministic (`checkout:<book_id>:<user_id>:
  <school_id>`), so a retried or duplicated A2A checkout message replays
  the sealed receipt instead of double-decrementing `Book.available_copies`.

  ## Supported commands (plain-text, one per message)

  - `as:<user_id> browse grade:<n>` -- list books via `Book.by_grade_band`
    (n-1..n+1) as that actor.
  - `as:<user_id> recommend grade:<n>` -- same as browse, phrased as a
    recommendation ask (routes through the same real `by_grade_band` read;
    Next Read's own ranker at `lib/xaas/library/ranker.ex` is the richer
    scoring path used by the LiveView itself).
  - `as:<user_id> checkout book:<book_id> school:<school_id>` -- real
    `Checkout.borrow` create action, admitted through `Xaas.Actuation.run/4`
    (decrements shelf inventory via `Xaas.Library.Changes
    .DecrementBookInventory`, same as the LiveView's checkout button).
  - `as:guest ...` -- any command with an unresolvable/guest actor still
    runs with `actor: nil`, exercising the same `authorize_if always()`
    read policies unauthenticated browsing already gets.

  Malformed commands return `{:input_required, ...}` asking for the
  correct shape rather than guessing -- multi-turn, per `A2A.Agent`'s own
  task lifecycle.
  """

  use A2A.Agent,
    name: "next-read-user",
    description: "Simulates a Next Read reader (student) persona for end-to-end multi-agent testing",
    skills: [
      %{
        id: "browse",
        name: "Browse books",
        description: "List books for a grade band as a given user actor",
        tags: ["next-read", "library"]
      },
      %{
        id: "checkout",
        name: "Checkout a book",
        description: "Borrow a book as a given user actor (real Ash create action)",
        tags: ["next-read", "library"]
      }
    ]

  alias Xaas.Library.{Book, Checkout}

  @impl A2A.Agent
  def handle_message(message, _context) do
    text = A2A.Message.text(message) || ""

    case parse(text) do
      {:ok, actor, command} -> run(actor, command)
      :error -> {:input_required, [A2A.Part.Text.new(usage())]}
    end
  end

  defp usage do
    "Expected: \"as:<user_id|guest> browse grade:<n>\" | " <>
      "\"as:<user_id|guest> recommend grade:<n>\" | " <>
      "\"as:<user_id> checkout book:<book_id> school:<school_id>\""
  end

  defp parse(text) do
    with [_, actor_ref, rest] <- Regex.run(~r/^as:(\S+)\s+(.+)$/, text) do
      {:ok, resolve_actor(actor_ref), rest}
    else
      _ -> :error
    end
  end

  defp resolve_actor("guest"), do: nil

  defp resolve_actor(user_id) do
    case Ash.get(Xaas.Accounts.User, user_id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
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
      {:reply, [A2A.Part.Text.new("checkout requires a real as:<user_id> actor, not guest")]}
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
          {:reply, [A2A.Part.Text.new("Checked out book #{checkout.book_id} for user #{checkout.user_id} (checkout #{checkout.id})")]}

        {:error, error} ->
          {:error, "checkout failed: #{inspect(error)}"}
      end
    end
  end
end
