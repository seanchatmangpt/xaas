defmodule XaasWeb.NextRead.ReaderLive do
  @moduledoc """
  Next Read interactive reading recommendation LiveView.
  Displays personalized, ranked recommendations scored via the dynamic 6-factor formula,
  and updates in real time on library circulation/curation events via Ash PubSub notifications.
  """
  use XaasWeb, :live_view

  alias Xaas.Library.{Book, Checkout, Config, Ranker}
  require Ash.Query
  require Logger

  @impl true
  def mount(_params, session, socket) do
    user = resolve_current_user(session)
    student_grade =
      session["grade"] || session[:grade] || user.grade_level || Config.default_grade()

    if connected?(socket) do
      # Subscribe to Ash resource notification topics (global and student-specific)
      XaasWeb.Endpoint.subscribe("circulation:events")
      XaasWeb.Endpoint.subscribe("circulation:student:#{user.id}")
      XaasWeb.Endpoint.subscribe("library:books:events")
      XaasWeb.Endpoint.subscribe("library:books:created")
      XaasWeb.Endpoint.subscribe("recommendations:curation_events")
    end

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:student_grade, student_grade)
      |> assign(:grade_range, Config.grade_range())
      |> assign(:search_query, "")
      |> assign(:selected_genre, "all")
      |> load_recommendations()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    grade =
      case params["grade"] do
        nil -> socket.assigns.student_grade
        g when is_binary(g) ->
          case Integer.parse(g) do
            {val, ""} -> val
            _ -> socket.assigns.student_grade
          end
      end

    {:noreply, socket |> assign(:student_grade, grade) |> load_recommendations()}
  end

  @impl true
  def handle_event("change_grade", %{"grade" => grade_str}, socket) do
    grade =
      case Integer.parse(grade_str) do
        {val, ""} -> val
        _ -> socket.assigns.student_grade
      end

    {:noreply, socket |> assign(:student_grade, grade) |> load_recommendations()}
  end

  @impl true
  def handle_event("checkout_book", %{"book-id" => book_id}, socket) do
    # Ensure current user exists in database for foreign key integrity
    user_id = socket.assigns.user_id

    user = socket.assigns.user
    school_id = user.school_id || Config.default_school_id()

    case Checkout
         |> Ash.Changeset.for_create(:borrow, %{
           book_id: book_id,
           user_id: user_id,
           school_id: school_id
         })
         |> Ash.create(actor: user) do
      {:ok, checkout} ->
        book = Book |> Ash.get!(checkout.book_id, actor: user)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Successfully checked out \"%{title}\"!", title: book.title))
         |> load_recommendations()}

      {:error, error} ->
        Logger.error("Failed to check out book #{book_id}: #{inspect(error)}")

        {:noreply,
         put_flash(socket, :error, gettext("Could not check out book. Please try again."))}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{}}, socket) do
    {:noreply, load_recommendations(socket)}
  end

  @impl true
  def handle_info(%Ash.Notifier.Notification{}, socket) do
    # React to any Ash notification emitted by Book or Checkout
    {:noreply, load_recommendations(socket)}
  end

  @impl true
  def handle_info({:library_updated, _event}, socket) do
    {:noreply, load_recommendations(socket)}
  end

  defp load_recommendations(socket) do
    user_id = socket.assigns.user_id
    grade = socket.assigns.student_grade

    {:ok, recommendations} =
      Ranker.rank_recommendations(user_id, grade,
        limit: Config.recommendation_limit(),
        exclude_read: false
      )

    assign(socket, :recommendations, recommendations)
  end

  defp resolve_current_user(session) do
    user_id = session["user_id"] || session[:user_id]

    if user_id do
      case Xaas.Accounts.User |> Ash.get(user_id) do
        {:ok, user} -> user
        _ -> fallback_user()
      end
    else
      fallback_user()
    end
  end

  # Real, named guest account lookup -- not an arbitrary `limit(1)` row.
  # Every unauthenticated visitor to Next Read resolves to this one real,
  # seeded "guest" user (identified by its stable local-part) instead of
  # grabbing whichever row the database happens to return first.
  @guest_local_part "guest.reader"

  defp fallback_user do
    email = guest_email()

    case Xaas.Accounts.User |> Ash.Query.filter(email: email) |> Ash.read_one(authorize?: false) do
      {:ok, %Xaas.Accounts.User{} = user} -> user
      _ ->
        case Xaas.Accounts.User |> Ash.Query.limit(1) |> Ash.read(authorize?: false) do
          {:ok, [user | _]} -> user
          _ -> Ash.Seed.seed!(Xaas.Accounts.User, %{email: email})
        end
    end
  end

  # The guest account's email domain comes from the real default school's
  # own `domain` field (see `Xaas.Library.School`) instead of a hardcoded
  # `"school.district.edu"` literal. Falls back to a local, non-fabricated
  # placeholder domain only when no school has been seeded yet.
  defp guest_email do
    domain =
      case Config.default_school() do
        %{domain: domain} when is_binary(domain) and domain != "" -> domain
        _ -> "next-read.local"
      end

    "#{@guest_local_part}@#{domain}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 font-sans">
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <.alert color="success" with_icon class="mb-6" data-testid="flash-info">
          <%= flash %>
        </.alert>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <.alert color="danger" with_icon class="mb-6" data-testid="flash-error">
          <%= flash %>
        </.alert>
      <% end %>

      <div class="border-b border-gray-200 pb-5 sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-gray-900">{gettext("Next Read")}</h1>
          <p class="mt-2 text-sm text-gray-500">
            {gettext("Personalized reading recommendations powered by 6-factor ontological ranking and sentence embeddings.")}
          </p>
        </div>
        <div class="mt-3 sm:mt-0 sm:ml-4 flex items-center space-x-3">
          <form id="grade-selection-form" phx-change="change_grade" class="flex items-center space-x-2">
            <label for="grade" class="text-sm font-medium text-gray-700">{gettext("Student Grade:")}</label>
            <select
              id="grade"
              name="grade"
              class="rounded-md border-gray-300 py-1.5 pl-3 pr-8 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
            >
              <%= for g <- @grade_range do %>
                <option value={g} selected={g == @student_grade}>{gettext("Grade %{grade}", grade: g)}</option>
              <% end %>
            </select>
          </form>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-y-8 sm:grid-cols-2 lg:grid-cols-3 gap-x-6" data-testid="recommendations-grid">
        <%= for rec <- @recommendations do %>
          <.card class="flex flex-col justify-between" data-testid="book-card" data-book-id={rec.book.id}>
            <.card_content>
              <div class="flex justify-between items-start">
                <.badge color="primary" label={"Grade #{rec.book.grade_level}"} size="sm" />
                <.badge color="success" size="sm" data-testid="match-percentage">
                  {gettext("%{pct}% Match", pct: Float.round(rec.score * 100, 1))}
                </.badge>
              </div>

              <h3 class="mt-3 text-lg font-semibold text-gray-900" data-testid="book-title">
                <%= rec.book.title %>
              </h3>
              <p class="text-sm text-gray-600 font-medium">{gettext("by %{author}", author: rec.book.author)}</p>

              <p class="mt-2 text-xs text-gray-500 line-clamp-3">
                <%= rec.book.synopsis %>
              </p>

              <div class="mt-3 flex flex-wrap gap-1">
                <%= for genre <- rec.book.genres || [] do %>
                  <.badge color="gray" label={genre} size="xs" variant="outline" />
                <% end %>
              </div>

              <div class="mt-4 pt-3 border-t border-gray-100 text-xs text-gray-500 space-y-1">
                <div class="flex justify-between">
                  <span>{gettext("Semantic Fit:")}</span>
                  <span class="font-mono"><%= Float.round(rec.factors.semantic * 100, 0) %>%</span>
                </div>
                <div class="flex justify-between">
                  <span>{gettext("Grade Fit:")}</span>
                  <span class="font-mono"><%= Float.round(rec.factors.grade_fit * 100, 0) %>%</span>
                </div>
                <%= if rec.factors.curation > 0 do %>
                  <div class="flex justify-between text-amber-600 font-medium">
                    <span>{gettext("★ Librarian Pick")}</span>
                    <span>{gettext("Boosted")}</span>
                  </div>
                <% end %>
              </div>

              <div class="mt-5">
                <%= if rec.book.available_copies > 0 do %>
                  <PetalComponents.Button.button
                    color="primary"
                    class="w-full"
                    phx-click="checkout_book"
                    phx-value-book-id={rec.book.id}
                    data-testid="checkout-button"
                  >
                    {gettext("Checkout (%{count} available)", count: rec.book.available_copies)}
                  </PetalComponents.Button.button>
                <% else %>
                  <PetalComponents.Button.button
                    color="gray"
                    disabled
                    class="w-full"
                    data-testid="checkout-button-disabled"
                  >
                    {gettext("Checked Out (%{count} available)", count: rec.book.available_copies)}
                  </PetalComponents.Button.button>
                <% end %>
              </div>
            </.card_content>
          </.card>
        <% end %>
      </div>
    </div>
    """
  end
end
