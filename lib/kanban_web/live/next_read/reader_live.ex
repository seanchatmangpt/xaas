defmodule KanbanWeb.NextRead.ReaderLive do
  @moduledoc """
  Next Read interactive reading recommendation LiveView.
  Displays personalized, ranked recommendations scored via the 6-factor formula,
  and updates in real time on library circulation/curation events via PubSub.
  """
  use KanbanWeb, :live_view

  alias Xaas.Library.{Book, Checkout, Ranker}
  require Ash.Query

  @pubsub_topic "library:recommendations"

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kanban.PubSub, @pubsub_topic)
    end

    user_id = session["user_id"] || session[:user_id] || default_user_id()
    student_grade = session["grade"] || session[:grade] || 6

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:student_grade, student_grade)
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
        g when is_binary(g) -> String.to_integer(g)
      end

    {:noreply, socket |> assign(:student_grade, grade) |> load_recommendations()}
  end

  @impl true
  def handle_event("change_grade", %{"grade" => grade_str}, socket) do
    grade = String.to_integer(grade_str)
    {:noreply, socket |> assign(:student_grade, grade) |> load_recommendations()}
  end

  @impl true
  def handle_event("checkout_book", %{"book-id" => book_id}, socket) do
    # Create checkout record
    case Checkout
         |> Ash.Changeset.for_create(:create, %{
           book_id: book_id,
           user_id: socket.assigns.user_id,
           status: :borrowed
         })
         |> Ash.create(authorize?: false) do
      {:ok, _checkout} ->
        # Decrement available copies on Book
        book = Book |> Ash.get!(book_id, authorize?: false)
        if book.available_copies > 0 do
          Book
          |> Ash.Changeset.for_update(:update, %{
            available_copies: book.available_copies - 1
          })
          |> Ash.update(authorize?: false)
        end

        # Broadcast update to PubSub
        Phoenix.PubSub.broadcast(Kanban.PubSub, @pubsub_topic, {:library_updated, :checkout})

        {:noreply,
         socket
         |> put_flash(:info, "Successfully checked out \"#{book.title}\"!")
         |> load_recommendations()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not check out book: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_info({:library_updated, _event}, socket) do
    {:noreply, load_recommendations(socket)}
  end

  defp load_recommendations(socket) do
    user_id = socket.assigns.user_id
    grade = socket.assigns.student_grade

    {:ok, recommendations} = Ranker.rank_recommendations(user_id, grade, limit: 12)

    assign(socket, :recommendations, recommendations)
  end

  defp default_user_id do
    case Xaas.Accounts.User |> Ash.Query.limit(1) |> Ash.read(authorize?: false) do
      {:ok, [user | _]} -> user.id
      _ -> "00000000-0000-0000-0000-000000000001"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 font-sans">
      <div class="border-b border-gray-200 pb-5 sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 class="text-3xl font-bold tracking-tight text-gray-900">Next Read</h1>
          <p class="mt-2 text-sm text-gray-500">
            Personalized reading recommendations powered by 6-factor ontological ranking and sentence embeddings.
          </p>
        </div>
        <div class="mt-3 sm:mt-0 sm:ml-4 flex items-center space-x-3">
          <form phx-change="change_grade" class="flex items-center space-x-2">
            <label for="grade" class="text-sm font-medium text-gray-700">Student Grade:</label>
            <select
              id="grade"
              name="grade"
              class="rounded-md border-gray-300 py-1.5 pl-3 pr-8 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
            >
              <%= for g <- 1..12 do %>
                <option value={g} selected={g == @student_grade}>Grade <%= g %></option>
              <% end %>
            </select>
          </form>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-y-8 sm:grid-cols-2 lg:grid-cols-3 gap-x-6">
        <%= for rec <- @recommendations do %>
          <div class="relative bg-white border border-gray-200 rounded-lg shadow-sm flex flex-col justify-between p-6 hover:shadow-md transition duration-150">
            <div>
              <div class="flex justify-between items-start">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                  Grade <%= rec.book.grade_level %>
                </span>
                <span class="text-xs font-semibold px-2 py-0.5 rounded bg-emerald-100 text-emerald-800">
                  <%= Float.round(rec.score * 100, 1) %>% Match
                </span>
              </div>

              <h3 class="mt-3 text-lg font-semibold text-gray-900">
                <%= rec.book.title %>
              </h3>
              <p class="text-sm text-gray-600 font-medium">by <%= rec.book.author %></p>

              <p class="mt-2 text-xs text-gray-500 line-clamp-3">
                <%= rec.book.synopsis %>
              </p>

              <div class="mt-3 flex flex-wrap gap-1">
                <%= for genre <- rec.book.genres || [] do %>
                  <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-normal bg-gray-100 text-gray-600">
                    <%= genre %>
                  </span>
                <% end %>
              </div>

              <div class="mt-4 pt-3 border-t border-gray-100 text-xs text-gray-500 space-y-1">
                <div class="flex justify-between">
                  <span>Semantic Fit:</span>
                  <span class="font-mono"><%= Float.round(rec.factors.semantic * 100, 0) %>%</span>
                </div>
                <div class="flex justify-between">
                  <span>Grade Fit:</span>
                  <span class="font-mono"><%= Float.round(rec.factors.grade_fit * 100, 0) %>%</span>
                </div>
                <%= if rec.factors.curation > 0 do %>
                  <div class="flex justify-between text-amber-600 font-medium">
                    <span>★ Librarian Pick</span>
                    <span>Boosted</span>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="mt-5">
              <%= if rec.book.available_copies > 0 do %>
                <button
                  phx-click="checkout_book"
                  phx-value-book-id={rec.book.id}
                  class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  Checkout (<%= rec.book.available_copies %> available)
                </button>
              <% else %>
                <button
                  disabled
                  class="w-full inline-flex justify-center items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-400 bg-gray-50 cursor-not-allowed"
                >
                  Checked Out (0 available)
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
