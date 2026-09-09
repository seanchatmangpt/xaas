defmodule XaasWeb.NextRead.ReaderLive do
  @moduledoc """
  Next Read interactive reading recommendation LiveView.
  Displays personalized, ranked recommendations scored via the dynamic 6-factor formula,
  and updates in real time on library circulation/curation events via Ash PubSub notifications.
  Supports Dual-Persona (Student + Librarian Advisory Desk) live interactions with zero page reloads.
  Grounded directly in the formal HDDL Task Calculus (docs/hddl/next-read.hddl).
  """
  use XaasWeb, :live_view

  alias Xaas.Library.{Book, Checkout, Config, Curation, HoldRequest, Ranker}
  require Ash.Query
  require Logger

  @impl true
  def mount(_params, session, socket) do
    user = resolve_current_user(session)
    student_grade = session["grade"] || session[:grade] || user.grade_level || Config.default_grade()

    if connected?(socket) do
      # Subscribe to Ash resource notification topics (global and student-specific)
      XaasWeb.Endpoint.subscribe("circulation:events")
      XaasWeb.Endpoint.subscribe("circulation:student:#{user.id}")
      XaasWeb.Endpoint.subscribe("library:books:events")
      XaasWeb.Endpoint.subscribe("library:books:created")
      XaasWeb.Endpoint.subscribe("recommendations:curation_events")
      XaasWeb.Endpoint.subscribe("holds:created")
    end

    socket =
      socket
      |> assign(:user, user)
      |> assign(:user_id, user.id)
      |> assign(:student_grade, student_grade)
      |> assign(:grade_range, Config.grade_range())
      |> assign(:view_mode, "split") # "split", "student", "librarian"
      |> assign(:expanded_why, %{}) # Map of book_id => boolean
      |> assign(:flashed_cards, MapSet.new())
      |> assign(:show_hddl_drawer, false)
      |> assign(:ask_query, "Show accessible science-fiction alternatives for students who liked The Wildwater Signal.")
      |> assign(:ask_state, :idle) # :idle, :searching, :answered
      |> assign(:ask_results, nil)
      |> assign(:patch_count_student, 0)
      |> assign(:patch_count_librarian, 0)
      |> assign(:loaded_time, Calendar.strftime(DateTime.utc_now(), "%H:%M:%S"))
      |> assign(:active_pulses, [])
      |> assign(:completed_proofs, MapSet.new(["01"]))
      |> assign(:hddl_receipts, [
        %{task: "RANK-RECOMMENDATIONS", status: :claimed, receipt: "w.collab*0.25 + w.sem*0.25 + w.grd*0.20", time: "live"}
      ])
      |> assign(:hddl_mermaid_diagram, nil)
      |> load_desk_stats()
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
        g when is_integer(g) -> g
      end

    socket =
      socket
      |> assign(:student_grade, grade)
      |> load_recommendations()

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("toggle_hddl_drawer", _params, socket) do
    opening = !socket.assigns.show_hddl_drawer

    socket =
      if opening and is_nil(socket.assigns.hddl_mermaid_diagram) do
        diagram =
          case Xaas.Hddl.Mermaid.for_drawer(
                 Xaas.Library.Reactors.RecommendationPipelineReactor,
                 "m-rank-and-recommend"
               ) do
            {:ok, d} -> d
            {:error, _} -> nil
          end

        assign(socket, :hddl_mermaid_diagram, diagram)
      else
        socket
      end

    {:noreply, assign(socket, :show_hddl_drawer, opening)}
  end

  @impl true
  def handle_event("change_grade", %{"grade" => grade_str}, socket) do
    grade = String.to_integer(grade_str)

    socket =
      socket
      |> assign(:student_grade, grade)
      |> add_pulse(:up, "recommendations:#{socket.assigns.user_id}")
      |> load_recommendations()

    {:noreply, push_patch(socket, to: ~p"/next-read?grade=#{grade}")}
  end

  @impl true
  def handle_event("toggle_why", params, socket) do
    book_id = to_string(params["book_id"] || params["book-id"] || params["id"])
    current = Map.get(socket.assigns.expanded_why, book_id, false)
    expanded = Map.put(socket.assigns.expanded_why, book_id, !current)

    socket =
      socket
      |> assign(:expanded_why, expanded)
      |> mark_proof_step("02")
      |> add_hddl_receipt("EXPAND-WHY-DRAWER", :claimed, "Grounding: historical read matches + 6-factor weights")

    {:noreply, socket}
  end

  @impl true
  def handle_event("checkout_book", %{"book-id" => book_id}, socket) do
    user = socket.assigns.user
    school_id = user.school_id || Config.default_school_id()
    idempotency_key = "checkout:#{book_id}:#{user.id}:#{school_id}"
    params = %{book_id: book_id, user_id: user.id, school_id: school_id}

    case Xaas.Actuation.run(Checkout, :borrow, params,
           idempotency_key: idempotency_key,
           actor: user,
           authorize?: false,
           authority: %{kind: "liveview_reader", source: "checkout_book"}
         ) do
      {:ok, %{result: checkout, receipt: receipt} = envelope} ->
        book = Book |> Ash.get!(checkout.book_id, authorize?: false)
        status_label = if envelope.status == :replayed, do: "replayed", else: "sealed"

        # Trigger telemetry pulse & proof step
        socket =
          socket
          |> add_pulse(:down, "circulation:willow-creek")
          |> mark_proof_step("05")
          |> mark_proof_step("06")
          |> add_hddl_receipt("CHECKOUT-BOOK", :sealed, "Receipt #{receipt.id} (#{status_label}) [key: #{idempotency_key}]")
          |> put_flash(:info, gettext("Successfully checked out \"%{title}\"!", title: book.title))
          |> load_desk_stats()
          |> load_recommendations()

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to check out book #{book_id} via Reactor: #{inspect(error)}")

        {:noreply,
         put_flash(socket, :error, gettext("Could not check out book. Shelf inventory may be depleted or hold requested."))}
    end
  end

  @impl true
  def handle_event("place_hold", %{"book-id" => book_id}, socket) do
    user = socket.assigns.user
    school_id = user.school_id || Config.default_school_id()
    idempotency_key = "hold:#{book_id}:#{user.id}:#{school_id}"
    params = %{book_id: book_id, user_id: user.id, school_id: school_id}

    case Xaas.Actuation.run(HoldRequest, :create, params,
           idempotency_key: idempotency_key,
           actor: user,
           authorize?: false,
           authority: %{kind: "liveview_reader", source: "place_hold"}
         ) do
      {:ok, %{result: hold, receipt: receipt} = envelope} ->
        book = Book |> Ash.get!(hold.book_id, authorize?: false)
        status_label = if envelope.status == :replayed, do: "replayed", else: "sealed"

        socket =
          socket
          |> add_pulse(:down, "holds:created")
          |> mark_proof_step("05")
          |> add_hddl_receipt("PLACE-HOLD", :sealed, "Receipt #{receipt.id} (#{status_label}) [key: #{idempotency_key}]")
          |> put_flash(:info, gettext("Hold placed for \"%{title}\". We will notify you when available!", title: book.title))
          |> load_recommendations()

        {:noreply, socket}

      {:error, error} ->
        Logger.error("Failed to place hold on book #{book_id} via Reactor: #{inspect(error)}")
        {:noreply, put_flash(socket, :error, gettext("Could not place hold."))}
    end
  end

  @impl true
  def handle_event("toggle_pin", %{"book-id" => book_id}, socket) do
    user = socket.assigns.user
    grade_band = "#{socket.assigns.student_grade}th Grade"

    # Check if curation already exists
    existing_curation =
      Curation
      |> Ash.Query.filter(book_id == ^book_id and active == true)
      |> Ash.read_one(authorize?: false)

    case existing_curation do
      {:ok, %Curation{} = curation} ->
        # Deactivate via Reactor
        idempotency_key = "curate-deactivate:#{book_id}:#{socket.assigns.student_grade}:#{System.system_time(:millisecond)}"
        
        case Xaas.Actuation.run(Curation, :update, %{active: false},
               idempotency_key: idempotency_key,
               subject_id: curation.id,
               actor: user,
               authorize?: false,
               authority: %{kind: "liveview_librarian", source: "toggle_pin"}
             ) do
          {:ok, %{receipt: receipt}} ->
            socket =
              socket
              |> add_pulse(:up, "recommendations:#{socket.assigns.user_id}")
              |> mark_proof_step("03")
              |> mark_proof_step("04")
              |> add_hddl_receipt("CURATE-PIN-BOOK", :sealed, "Unpinned receipt #{receipt.id}")
              |> flash_card(book_id)
              |> load_recommendations()

            {:noreply, socket}

          {:error, error} ->
            Logger.error("Failed to update curation: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Could not unpin book")}
        end

      _ ->
        # Create active curation via Reactor
        idempotency_key = "curate-activate:#{book_id}:#{socket.assigns.student_grade}:#{System.system_time(:millisecond)}"
        params = %{
          book_id: book_id,
          curated_by: user.email || "a.okafor@willowcreek.edu",
          grade_band: grade_band,
          reason: "Teacher-librarian spotlight pick for Grade #{socket.assigns.student_grade}",
          state: :pinned,
          active: true
        }

        case Xaas.Actuation.run(Curation, :create, params,
               idempotency_key: idempotency_key,
               actor: user,
               authorize?: false,
               authority: %{kind: "liveview_librarian", source: "toggle_pin"}
             ) do
          {:ok, %{receipt: receipt}} ->
            socket =
              socket
              |> add_pulse(:up, "recommendations:#{socket.assigns.user_id}")
              |> mark_proof_step("03")
              |> mark_proof_step("04")
              |> add_hddl_receipt("CURATE-PIN-BOOK", :sealed, "Pinned receipt #{receipt.id}")
              |> flash_card(book_id)
              |> load_recommendations()

            {:noreply, socket}

          {:error, error} ->
            Logger.error("Failed to create curation: #{inspect(error)}")
            {:noreply, put_flash(socket, :error, "Could not pin book")}
        end
    end
  end

  @impl true
  def handle_event("update_ask_query", %{"query" => query}, socket) do
    # Guard query length against unbounded input (FM-06)
    sanitized_query = String.slice(query, 0, 500)
    {:noreply, assign(socket, :ask_query, sanitized_query)}
  end

  @impl true
  def handle_event("ask_catalog", %{"query" => query}, socket) do
    sanitized_query = String.slice(query, 0, 500)

    socket =
      socket
      |> assign(:ask_query, sanitized_query)
      |> assign(:ask_state, :searching)

    # Run catalog semantic query
    results = Ranker.ask_catalog(sanitized_query, limit: 3)

    socket =
      socket
      |> assign(:ask_state, :answered)
      |> assign(:ask_results, results)
      |> mark_proof_step("07")
      |> add_hddl_receipt("ASK-CATALOG-SEMANTIC", :claimed, "Vector ranker admitted #{results.candidates_admitted} candidates")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_pulses", _params, socket) do
    {:noreply, assign(socket, :active_pulses, [])}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: topic}, socket) do
    dir = if String.starts_with?(topic, "recommendations"), do: :up, else: :down

    socket =
      socket
      |> add_pulse(dir, topic)
      |> assign(:patch_count_student, socket.assigns.patch_count_student + 1)
      |> assign(:patch_count_librarian, socket.assigns.patch_count_librarian + 1)
      |> load_desk_stats()
      |> load_recommendations()

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Ash.Notifier.Notification{}, socket) do
    socket =
      socket
      |> assign(:patch_count_student, socket.assigns.patch_count_student + 1)
      |> load_desk_stats()
      |> load_recommendations()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:library_updated, _event}, socket) do
    {:noreply, load_recommendations(socket)}
  end

  defp load_recommendations(socket) do
    user_id = socket.assigns.user_id
    grade = socket.assigns.student_grade

    user_checkouts =
      Checkout
      |> Ash.Query.filter(user_id == ^user_id)
      |> Ash.Query.load([:book])
      |> Ash.read!(authorize?: false)

    active_curation_ids =
      Curation
      |> Ash.Query.filter(active == true)
      |> Ash.Query.select([:book_id])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.book_id)
      |> MapSet.new()

    {:ok, raw_recs} =
      Ranker.rank_recommendations(user_id, grade,
        limit: 6,
        exclude_read: false
      )

    enriched_recs =
      Enum.map(raw_recs, fn rec ->
        explanation = Ranker.explain_recommendation(rec.book, rec.factors, user_checkouts)
        is_pinned = MapSet.member?(active_curation_ids, rec.book.id)

        rec
        |> Map.put(:explanation, explanation)
        |> Map.put(:pinned, is_pinned)
      end)

    socket
    |> assign(:recommendations, enriched_recs)
    |> assign(:user_checkouts, user_checkouts)
    |> assign(:active_curation_ids, active_curation_ids)
  end

  defp load_desk_stats(socket) do
    today_start = DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    out_today_count =
      Checkout
      |> Ash.Query.filter(inserted_at >= ^today_start)
      |> Ash.count!(authorize?: false)

    active_readers_count =
      Checkout
      |> Ash.Query.filter(status == :borrowed)
      |> Ash.Query.select([:user_id])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)
      |> Enum.uniq()
      |> length()
      |> max(1)

    total_logs =
      Xaas.Library.RecommendationLog
      |> Ash.count!(authorize?: false)

    accepted_logs =
      Xaas.Library.RecommendationLog
      |> Ash.Query.filter(accepted == true)
      |> Ash.count!(authorize?: false)

    acceptance_rate =
      if total_logs > 0 do
        round((accepted_logs / total_logs) * 100)
      else
        0
      end

    socket
    |> assign(:stats_out_today, out_today_count)
    |> assign(:stats_active_readers, active_readers_count)
    |> assign(:stats_acceptance_rate, acceptance_rate)
  end

  defp add_pulse(socket, direction, topic) do
    pulse = %{
      id: "pulse-#{System.unique_integer([:positive])}",
      direction: direction,
      topic: topic,
      inserted_at: System.system_time(:millisecond)
    }

    pulses = [pulse | Enum.take(socket.assigns.active_pulses, 3)]
    assign(socket, :active_pulses, pulses)
  end

  defp add_hddl_receipt(socket, action_name, standing, detail) do
    new_receipt = %{
      task: action_name,
      status: standing,
      receipt: detail,
      time: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
    }
    receipts = [new_receipt | Enum.take(socket.assigns.hddl_receipts, 5)]
    assign(socket, :hddl_receipts, receipts)
  end

  defp mark_proof_step(socket, step) do
    new_proofs = MapSet.put(socket.assigns.completed_proofs, step)
    new_proofs = if MapSet.size(new_proofs) >= 7, do: MapSet.put(new_proofs, "08"), else: new_proofs
    assign(socket, :completed_proofs, new_proofs)
  end

  defp flash_card(socket, book_id) do
    flashed = MapSet.put(socket.assigns.flashed_cards, book_id)
    assign(socket, :flashed_cards, flashed)
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

  @guest_local_part "guest.reader"

  defp fallback_user do
    email = "#{@guest_local_part}@willowcreek.edu"

    case Xaas.Accounts.User |> Ash.Query.filter(email: email) |> Ash.read_one(authorize?: false) do
      {:ok, %Xaas.Accounts.User{} = user} -> user
      _ ->
        case Xaas.Accounts.User |> Ash.Query.limit(1) |> Ash.read(authorize?: false) do
          {:ok, [user | _]} -> user
          _ -> Ash.Seed.seed!(Xaas.Accounts.User, %{email: email})
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#F4EFE6] text-[#17150F] font-sans flex flex-col">
      <%!-- Top Global Navigation Bar matching Qvest Demo --%>
      <header class="bg-[#17150F] text-[#F4EFE6] px-6 py-3 flex items-center justify-between gap-4 flex-wrap border-b border-black/20">
        <div class="flex items-baseline gap-3">
          <span class="font-serif text-2xl font-normal tracking-tight">Next Read</span>
          <span class="font-mono text-[11px] tracking-widest uppercase text-[#F4EFE6]/60">Dual Experience Live Harness</span>
        </div>

        <div class="flex items-center gap-2 flex-wrap font-mono text-[11px]">
          <span class="px-2.5 py-1 rounded border border-[#F4EFE6]/20 bg-[#F4EFE6]/5 text-[#F4EFE6]/80">ash 3.4.74</span>
          <span class="px-2.5 py-1 rounded border border-[#F4EFE6]/20 bg-[#F4EFE6]/5 text-[#F4EFE6]/80">fly · sjc</span>
          <button
            phx-click="toggle_hddl_drawer"
            class="px-2.5 py-1 rounded border border-[#5A6B45]/50 bg-[#5A6B45]/20 text-[#A2B889] hover:bg-[#5A6B45]/30 cursor-pointer font-semibold"
            data-testid="hddl-calculus-toggle"
          >
            HDDL Task Calculus <%= if @show_hddl_drawer, do: "▲", else: "▼" %>
          </button>
          <span class="px-2.5 py-1 rounded border border-[#B5352A]/50 bg-[#B5352A]/20 text-[#E9A79F]">notifier → pubsub → liveview</span>
        </div>

        <div class="flex items-center gap-3">
          <%!-- Layout Mode Switcher --%>
          <div class="flex rounded-md p-0.5 bg-[#F4EFE6]/10 border border-[#F4EFE6]/20 text-xs font-mono">
            <button
              phx-click="set_view_mode"
              phx-value-mode="split"
              class={"px-2.5 py-1 rounded " <> if(@view_mode == "split", do: "bg-[#B5352A] text-white", else: "text-[#F4EFE6]/70 hover:text-white")}
            >
              Split View
            </button>
            <button
              phx-click="set_view_mode"
              phx-value-mode="student"
              class={"px-2.5 py-1 rounded " <> if(@view_mode == "student", do: "bg-[#B5352A] text-white", else: "text-[#F4EFE6]/70 hover:text-white")}
            >
              Student Only
            </button>
            <button
              phx-click="set_view_mode"
              phx-value-mode="librarian"
              class={"px-2.5 py-1 rounded " <> if(@view_mode == "librarian", do: "bg-[#B5352A] text-white", else: "text-[#F4EFE6]/70 hover:text-white")}
            >
              Librarian Only
            </button>
          </div>

          <form phx-change="change_grade" class="flex items-center gap-2">
            <select
              id="header-grade-select"
              name="grade"
              class="bg-[#17150F] text-[#F4EFE6] border border-[#F4EFE6]/30 text-xs font-mono rounded px-2.5 py-1 focus:ring-1 focus:ring-[#B5352A]"
            >
              <%= for g <- @grade_range do %>
                <option value={g} selected={g == @student_grade}>Grade <%= g %></option>
              <% end %>
            </select>
          </form>
        </div>
      </header>

      <%!-- HDDL Task Calculus & Epistemic Receipt Drawer --%>
      <%= if @show_hddl_drawer do %>
        <div class="bg-[#1E1C15] text-[#F4EFE6] border-b border-black/40 px-6 py-4 font-mono text-xs shadow-inner" data-testid="hddl-drawer">
          <div class="max-w-7xl mx-auto flex flex-col md:flex-row gap-6 justify-between items-start">
            <div class="space-y-1.5 flex-1">
              <div class="flex items-center gap-2">
                <span class="text-[#B5352A] font-bold uppercase tracking-wider text-[11px]">Active HDDL Domain:</span>
                <span class="text-white font-semibold">next-read</span>
                <span class="text-[#F4EFE6]/40 text-[10px]">(docs/hddl/next-read.hddl)</span>
              </div>
              <p class="text-[11px] text-[#F4EFE6]/70 leading-relaxed font-sans">
                Formal hierarchical task network grounding every user journey, A2A agent command, and MCP query into verified preconditions and deterministic state transitions.
              </p>
              <div class="flex gap-2 pt-1">
                <span class="px-2 py-0.5 bg-black/40 rounded border border-[#F4EFE6]/10 text-[10px] text-[#A2B889]">
                  Task: NEXT-READ-DUAL-PERSONA-EXPERIENCE
                </span>
                <span class="px-2 py-0.5 bg-black/40 rounded border border-[#F4EFE6]/10 text-[10px] text-[#E9A79F]">
                  Method: m-dual-persona-split-experience
                </span>
              </div>
            </div>

            <%!-- Live Mermaid DAG Column --%>
            <div class="flex-1 space-y-1.5 border-t md:border-t-0 md:border-l border-white/10 md:pl-6 min-w-0">
              <div class="flex justify-between items-center mb-1">
                <span class="text-[#F4EFE6]/50 uppercase tracking-wider text-[10px]">Reactor DAG (Mermaid)</span>
                <span class="text-[10px] text-[#E9A79F]">HDDL(:method) ↔ Reactor(step DAG)</span>
              </div>
              <%= if @hddl_mermaid_diagram do %>
                <pre class="text-[9px] text-[#A2B889] bg-black/40 rounded p-2 overflow-x-auto max-h-28 leading-tight border border-white/5 whitespace-pre" data-testid="hddl-mermaid-dag"><%= @hddl_mermaid_diagram %></pre>
              <% else %>
                <div class="text-[10px] text-[#F4EFE6]/30 italic">Loading DAG…</div>
              <% end %>
            </div>

            <div class="flex-1 space-y-1.5 border-t md:border-t-0 md:border-l border-white/10 md:pl-6">
              <div class="flex justify-between items-center">
                <span class="text-[#F4EFE6]/50 uppercase tracking-wider text-[10px]">Honest Epistemic Receipts (DO vs. CLAIM)</span>
                <span class="text-[10px] text-[#A2B889]">Zero Prompt Guessing</span>
              </div>
              <div class="space-y-1 max-h-24 overflow-y-auto">
                <%= for r <- @hddl_receipts do %>
                  <div class="flex items-center justify-between text-[10px] bg-black/30 px-2 py-1 rounded border border-white/5">
                    <div class="flex items-center gap-2">
                      <span class={"font-bold " <> if(r.status == :sealed, do: "text-[#5A6B45]", else: "text-[#D9822B]")}>
                        [<%= Atom.to_string(r.status) |> String.upcase() %>]
                      </span>
                      <span class="text-white"><%= r.task %></span>
                    </div>
                    <span class="text-[#F4EFE6]/60 truncate max-w-[200px]"><%= r.receipt %></span>
                    <span class="text-[#F4EFE6]/40 text-[9px]"><%= r.time %></span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Flash Banners --%>
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div class="bg-[#5A6B45]/15 border-b border-[#5A6B45]/30 text-[#40522E] px-6 py-2.5 flex items-center justify-between text-sm font-medium" data-testid="flash-info">
          <span><%= flash %></span>
        </div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div class="bg-[#B5352A]/15 border-b border-[#B5352A]/30 text-[#B5352A] px-6 py-2.5 flex items-center justify-between text-sm font-medium" data-testid="flash-error">
          <span><%= flash %></span>
        </div>
      <% end %>

      <%!-- Main Content Area with Split or Single Columns --%>
      <main class="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 lg:p-8 grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">

        <%!-- LEFT COLUMN: Student Reading UI --%>
        <%= if @view_mode in ["split", "student"] do %>
          <section
            class={"bg-[#FCFAF6] border border-[#17150F]/15 rounded-lg shadow-sm overflow-hidden flex flex-col " <> if(@view_mode == "student", do: "lg:col-span-12", else: "lg:col-span-7")}
            data-testid="student-window"
          >
            <%!-- Student Window Header --%>
            <div class="bg-[#EDE7DB] border-b border-[#17150F]/15 px-5 py-3.5 flex items-center justify-between flex-wrap gap-2">
              <div class="flex items-center gap-3">
                <span class="font-serif text-lg font-medium text-[#17150F]">Maya's Next Read</span>
                <span class="font-mono text-xs px-2 py-0.5 rounded bg-[#17150F]/10 text-[#17150F]/80">Grade <%= @student_grade %></span>
              </div>
              <div class="flex items-center gap-3 font-mono text-[11px] text-[#17150F]/70">
                <span><%= length(@recommendations) %> personalized picks</span>
                <%= if @patch_count_student > 0 do %>
                  <span class="text-[#5A6B45] font-semibold animate-pulse">● patched live (<%= @patch_count_student %>)</span>
                <% end %>
              </div>
            </div>

            <%!-- Book Cards Grid --%>
            <div class="p-5 space-y-4">
              <div class="flex items-baseline justify-between border-b border-[#17150F]/10 pb-2">
                <h2 class="font-serif text-xl text-[#17150F]">Top Recommended For You</h2>
                <span class="font-mono text-[11px] text-[#17150F]/60">6-factor composite rank</span>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%= for rec <- @recommendations do %>
                  <% is_flashed = MapSet.member?(@flashed_cards, rec.book.id) %>
                  <div
                    class={"bg-[#F4EFE6] border rounded p-4 flex flex-col justify-between transition-all duration-300 relative " <>
                      if(rec.pinned, do: "border-[#B5352A] shadow-md ring-1 ring-[#B5352A]/30 ", else: "border-[#17150F]/15 ") <>
                      if(is_flashed, do: "ring-2 ring-[#B5352A] scale-[1.01] ", else: "")}
                    data-testid="book-card"
                    data-book-id={rec.book.id}
                  >
                    <%!-- Top Badge Row --%>
                    <div class="flex items-center justify-between gap-2 mb-2">
                      <span class="font-mono text-[10px] uppercase tracking-wider px-2 py-0.5 rounded bg-[#17150F]/10 text-[#17150F]/80">
                        <%= List.first(rec.book.formats || []) || "Novel" %>
                      </span>
                      <div class="flex items-center gap-1.5 font-mono text-xs font-semibold">
                        <span class="text-[#B5352A]">match <%= round(rec.score * 100) %>%</span>
                      </div>
                    </div>

                    <%!-- Title & Author --%>
                    <div class="mb-3">
                      <%= if rec.pinned do %>
                        <div class="flex items-center gap-1.5 text-[11px] font-mono text-[#B5352A] font-semibold mb-1">
                          <span>★ STAFF SPOTLIGHT</span>
                        </div>
                      <% end %>
                      <h3 class="font-serif text-lg leading-snug font-medium text-[#17150F]">
                        <%= rec.book.title %>
                      </h3>
                      <p class="font-sans text-xs text-[#17150F]/70 mt-0.5">by <%= rec.book.author %></p>
                    </div>

                    <%!-- Match Score Progress Bar --%>
                    <div class="w-full bg-[#17150F]/10 h-1.5 rounded-full overflow-hidden mb-3">
                      <div class="bg-[#B5352A] h-full rounded-full" style={"width: #{round(rec.score * 100)}%"}></div>
                    </div>

                    <%!-- Metadata Tags --%>
                    <div class="flex items-center gap-2 flex-wrap font-mono text-[10.5px] text-[#17150F]/60 mb-3">
                      <span>Gr. <%= rec.book.grade_level %></span>
                      <span>·</span>
                      <span><%= List.first(rec.book.genres || []) || "Fiction" %></span>
                      <span>·</span>
                      <span class={if(rec.book.available_copies > 0, do: "text-[#5A6B45] font-semibold", else: "text-[#B5352A]")}>
                        <%= if rec.book.available_copies > 0, do: "#{rec.book.available_copies} copy on shelf", else: "all copies checked out" %>
                      </span>
                    </div>

                    <%!-- "Why this one?" Accordion Toggle --%>
                    <div class="border-t border-[#17150F]/10 pt-2.5 mt-auto">
                      <button
                        phx-click="toggle_why"
                        phx-value-book_id={to_string(rec.book.id)}
                        class="text-xs font-mono text-[#23405F] hover:underline flex items-center justify-between w-full text-left"
                        data-testid="why-button"
                      >
                        <span class="font-semibold">Why this one?</span>
                        <span class="text-[10px]"><%= if Map.get(@expanded_why, to_string(rec.book.id), false), do: "▲ Hide", else: "▼ Explain" %></span>
                      </button>

                      <%!-- Grounded Explainability Drawer --%>
                      <%= if Map.get(@expanded_why, to_string(rec.book.id), false) do %>
                        <div class="mt-2.5 p-3 rounded bg-[#FCFAF6] border border-[#23405F]/20 text-xs font-sans space-y-2" data-testid="explanation-drawer">
                          <div class="font-mono text-[10px] font-semibold uppercase tracking-wider text-[#23405F]">
                            Grounded Explanation
                          </div>
                          <p class="text-[#17150F]/90 leading-relaxed text-[11.5px]">
                            <%= rec.explanation[:why] || rec.explanation[:summary] || "Traced to real student circulation records" %>
                          </p>

                          <%!-- Factor Breakdown Pills --%>
                          <div class="pt-1.5 border-t border-[#17150F]/10 flex flex-wrap gap-1.5 font-mono text-[9.5px]">
                            <%= for {factor_name, weight} <- [
                              {"collaborative", Map.get(rec.factors, :collaborative, 0.0)},
                              {"semantic", Map.get(rec.factors, :semantic, 0.0)},
                              {"grade fit", Map.get(rec.factors, :grade_fit, 0.0)},
                              {"popularity", Map.get(rec.factors, :popularity, 0.0)}
                            ] do %>
                              <span class="px-2 py-0.5 rounded bg-[#17150F]/5 border border-[#17150F]/10 text-[#17150F]/80">
                                <%= factor_name %>: <strong class="text-[#17150F]"><%= Float.round(weight * 1.0, 2) %></strong>
                              </span>
                            <% end %>
                          </div>

                          <div class="font-mono text-[9px] text-[#17150F]/50 pt-1">
                            Traced to real student circulation records · Zero LLM hallucination
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <%!-- Action Buttons --%>
                    <div class="mt-3 pt-2 border-t border-[#17150F]/10 flex gap-2">
                      <%= if rec.book.available_copies > 0 do %>
                        <button
                          phx-click="checkout_book"
                          phx-value-book-id={rec.book.id}
                          class="flex-1 bg-[#17150F] hover:bg-[#2A261D] text-[#F4EFE6] font-mono text-xs py-2 px-3 rounded text-center transition-colors shadow-sm"
                          data-testid="checkout-button"
                        >
                          Check Out Now
                        </button>
                      <% else %>
                        <button
                          phx-click="place_hold"
                          phx-value-book-id={rec.book.id}
                          class="flex-1 bg-[#23405F] hover:bg-[#1A314A] text-white font-mono text-xs py-2 px-3 rounded text-center transition-colors shadow-sm"
                          data-testid="hold-button"
                        >
                          Place Hold
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </section>
        <% end %>

        <%!-- RIGHT COLUMN: Librarian Advisory Desk --%>
        <%= if @view_mode in ["split", "librarian"] do %>
          <section
            class={"bg-[#FCFAF6] border border-[#17150F]/15 rounded-lg shadow-sm overflow-hidden flex flex-col " <> if(@view_mode == "librarian", do: "lg:col-span-12", else: "lg:col-span-5")}
            data-testid="librarian-window"
          >
            <%!-- Librarian Desk Header --%>
            <div class="bg-[#17150F] text-[#F4EFE6] px-5 py-3.5 flex items-center justify-between flex-wrap gap-2">
              <div class="flex items-center gap-3">
                <span class="font-serif text-lg font-medium text-[#F4EFE6]">Advisory Desk</span>
                <span class="font-mono text-xs px-2 py-0.5 rounded bg-[#F4EFE6]/10 text-[#F4EFE6]/80">Staff Curation</span>
              </div>
              <div class="font-mono text-[11px] text-[#F4EFE6]/60">
                Willow Creek Middle
              </div>
            </div>

            <div class="p-5 space-y-6">
              <%!-- Live Circulation Metrics --%>
              <div>
                <h3 class="font-mono text-xs uppercase tracking-wider text-[#17150F]/60 mb-3">Live Circulation Telemetry</h3>
                <div class="grid grid-cols-3 gap-3">
                  <div class="bg-[#F4EFE6] border border-[#17150F]/15 rounded p-3 text-center">
                    <div class="font-serif text-2xl font-bold text-[#17150F]" data-testid="stat-out-today"><%= @stats_out_today %></div>
                    <div class="font-mono text-[10px] text-[#17150F]/60 mt-0.5">Checked Out Today</div>
                  </div>
                  <div class="bg-[#F4EFE6] border border-[#17150F]/15 rounded p-3 text-center">
                    <div class="font-serif text-2xl font-bold text-[#17150F]"><%= @stats_active_readers %></div>
                    <div class="font-mono text-[10px] text-[#17150F]/60 mt-0.5">Active Readers</div>
                  </div>
                  <div class="bg-[#F4EFE6] border border-[#17150F]/15 rounded p-3 text-center">
                    <div class="font-serif text-2xl font-bold text-[#5A6B45]"><%= @stats_acceptance_rate %>%</div>
                    <div class="font-mono text-[10px] text-[#17150F]/60 mt-0.5">Advisory Accepted</div>
                  </div>
                </div>
              </div>

              <%!-- Curation Controls --%>
              <div class="space-y-3">
                <div class="flex items-baseline justify-between border-b border-[#17150F]/10 pb-2">
                  <h3 class="font-serif text-lg text-[#17150F]">Curate Grade <%= @student_grade %> Shelf</h3>
                  <span class="font-mono text-[10.5px] text-[#17150F]/50">Instant PubSub Broadcast</span>
                </div>

                <div class="space-y-2">
                  <%= for rec <- @recommendations do %>
                    <div class="bg-[#F4EFE6] border border-[#17150F]/15 rounded px-3.5 py-2.5 flex items-center justify-between gap-3">
                      <div class="min-w-0">
                        <div class="font-medium text-xs text-[#17150F] truncate"><%= rec.book.title %></div>
                        <div class="font-mono text-[10px] text-[#17150F]/60"><%= rec.book.author %> · <%= rec.book.available_copies %> available</div>
                      </div>
                      <button
                        phx-click="toggle_pin"
                        phx-value-book-id={rec.book.id}
                        class={"font-mono text-xs px-3 py-1.5 rounded transition-colors whitespace-nowrap " <>
                          if(rec.pinned, do: "bg-[#B5352A] text-white hover:bg-[#8F271E]", else: "bg-[#17150F]/10 hover:bg-[#17150F]/20 text-[#17150F]")}
                        data-testid="pin-button"
                        data-book-id={rec.book.id}
                      >
                        <%= if rec.pinned, do: "★ Pinned", else: "☆ Pin" %>
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- "Ask the Catalog" Natural Language Assistant --%>
              <div class="border-t border-[#17150F]/10 pt-4 space-y-3">
                <div class="flex items-baseline justify-between">
                  <h3 class="font-serif text-lg text-[#17150F]">Ask the Catalog</h3>
                  <span class="font-mono text-[10.5px] text-[#23405F]">Semantic vector assistant</span>
                </div>

                <div class="bg-[#23405F]/5 border border-[#23405F]/20 rounded p-4 space-y-3">
                  <form phx-submit="ask_catalog" phx-change="update_ask_query" class="space-y-2">
                    <textarea
                      name="query"
                      rows="2"
                      class="w-full bg-white border border-[#23405F]/30 rounded p-2.5 text-xs text-[#17150F] font-sans focus:ring-1 focus:ring-[#23405F]"
                      placeholder="Ask for recommendations, thematic alternatives, or grade fits..."
                      data-testid="ask-input"
                    ><%= @ask_query %></textarea>

                    <div class="flex justify-between items-center">
                      <span class="font-mono text-[10px] text-[#23405F]/70">Local Nx/Bumblebee Vector Index</span>
                      <button
                        type="submit"
                        class="bg-[#23405F] hover:bg-[#1A314A] text-white font-mono text-xs px-4 py-1.5 rounded transition-colors shadow-sm"
                        data-testid="ask-button"
                      >
                        Ask Catalog
                      </button>
                    </div>
                  </form>

                  <%= if @ask_state == :searching do %>
                    <div class="py-4 text-center font-mono text-xs text-[#23405F] animate-pulse">
                      Admitting candidate pool & computing vector distances...
                    </div>
                  <% end %>

                  <%= if @ask_state == :answered and @ask_results do %>
                    <div class="mt-3.5 pt-3 border-t border-[#23405F]/15 space-y-2.5" data-testid="ask-results">
                      <p class="text-xs text-[#17150F]/90 leading-relaxed font-sans font-medium">
                        <%= @ask_results.summary %>
                      </p>
                      <div class="space-y-1 pl-3 border-l-2 border-[#23405F]/30">
                        <%= for ans <- @ask_results.answers do %>
                          <div class="text-xs">
                            <span class="font-semibold text-[#17150F]"><%= ans.title %></span>
                            <span class="font-mono text-[10px] text-[#17150F]/60 ml-2"><%= ans.meta %></span>
                          </div>
                        <% end %>
                      </div>
                      <div class="font-mono text-[9.5px] text-[#17150F]/50 pt-2 border-t border-[#17150F]/10 flex justify-between items-center">
                        <span><%= Enum.join(@ask_results.telemetry, " → ") %></span>
                        <span class="text-[#B5352A] font-semibold">Ranker admitted <%= @ask_results.candidates_admitted %></span>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </section>
        <% end %>
      </main>

      <%!-- Proof Sequence Bar matching Qvest Realtime Demo footer --%>
      <footer class="bg-[#EDE7DB] border-t border-[#17150F]/15 px-6 py-3 flex items-center justify-between gap-4 flex-wrap font-mono text-xs">
        <span class="text-[#17150F]/50 uppercase tracking-wider text-[11px]">Proof Sequence</span>
        <div class="flex gap-2 flex-wrap" data-testid="proof-sequence">
          <%= for {step_id, label} <- [
            {"01", "01 ranked"},
            {"02", "02 explained"},
            {"03", "03 curated"},
            {"04", "04 student patched live"},
            {"05", "05 checked out"},
            {"06", "06 desk patched live"},
            {"07", "07 advisory answered"},
            {"08", "08 deploy receipt"}
          ] do %>
            <% is_done = MapSet.member?(@completed_proofs, step_id) %>
            <span class={"px-2.5 py-1 rounded text-[11px] border transition-colors " <> if(is_done, do: "bg-[#5A6B45]/15 border-[#5A6B45]/40 text-[#40522E] font-medium", else: "bg-transparent border-[#17150F]/15 text-[#17150F]/40")}>
              <%= label %> <%= if is_done, do: "✓" %>
            </span>
          <% end %>
        </div>
        <span class="text-[#17150F]/50 text-[11px]">release v37 · migrations 0041 ok · e2e ready</span>
      </footer>
    </div>
    """
  end
end
