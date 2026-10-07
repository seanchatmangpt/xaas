defmodule XaasWeb.MarketplaceCatalogLive do
  @moduledoc """
  Marketplace catalog surface over `Xaas.Marketplace.Catalog` /
  `Xaas.Marketplace.Pack` (the ggen-marketplace consumer projection).

  Renders the pack table (name, version, class, readiness, digest) with a
  server-side search box. All reads go through the `Xaas.Marketplace.Catalog`
  context; the LiveView holds no second catalog.

  ## Catalog source

  `Xaas.Marketplace.Pack` uses `Ash.DataLayer.Ets` with `private? true`, so
  pack rows are process-local. The mount therefore ingests the catalog IN
  THIS PROCESS from the source configured at
  `Application.get_env(:xaas, :marketplace_catalog_source)` (a path, raw JSON
  binary, or decoded map; nil = skip ingest and render whatever the process
  already has). Ingest is an idempotent upsert keyed on pack name.

  ## ash_surface (π_LiveView) status

  TODO(ash_surface): the generated surface path is
  `AshSurface.Compiler.compile(Xaas.Marketplace)` -> one `%AshSurface.IR{}`
  per public action -> `AshSurface.Projectors.LiveView.project_ir/2` -> the
  ash-admin structure map this table hand-renders. The generation path is
  WITNESSED in dev (compiler returns 10 IRs over `Xaas.Marketplace`;
  `project_ir/2` folds them into an `ash_admin` view over 3 resources / 10
  actions). The original stated blocker — `ash_surface` pinned
  `only: [:dev, :test]` — is CLOSED: `mix.exs:115` now carries the path dep
  all-envs, and ash_surface itself compiles under `MIX_ENV=prod`
  (`_build/prod/lib/ash_surface/ebin` observed 2026-10-06). Remaining to
  wire: (1) full `MIX_ENV=prod mix compile` must first go green — currently
  red on unrelated files (`lib/xaas_web/a2a/next_read_ash_agent.ex`,
  `lib/xaas_web/live/witness_live.ex`) that reference `AshA2A.Protocol.Agent`,
  a module absent at the pinned ash_a2a ref `3325032` (no
  `lib/ash_a2a/protocol/` tree at that ref); (2) run `mix xaas.ash_surface`
  to write the projection of record into `priv/ash_surface/`
  (surface_contract.json / live_view.json / aria.json / client .mjs);
  (3) swap this hand-rendered table for the `live_view.json` structure map
  (a full render replacement, not a small read-only patch). Until (1)-(3)
  land, this hand-written surface is the projection of record and this
  module is the seam it replaces.

  Like the p-plan explorer precedent, data comes from the real context; no
  external CDN scripts.
  """

  use XaasWeb, :live_view

  alias Xaas.Marketplace.Catalog

  @digest_width 16

  @impl true
  def mount(_params, _session, socket) do
    socket = ingest_best_effort(socket, Application.get_env(:xaas, :marketplace_catalog_source))

    socket =
      socket
      |> assign(:search, "")
      |> assign(:packs, Catalog.list_packs())

    {:ok, socket}
  end

  defp ingest_best_effort(socket, nil), do: socket

  defp ingest_best_effort(socket, source) do
    # Best-effort: the surface renders, surfacing any typed refusal in the
    # UI rather than crashing mount. Catalog.ingest/1 returns
    # {:error, %Catalog.Error{}} for malformed catalogs, but per-pack Ash
    # validation failures raise; both become the same structured refusal
    # (machine-readable via the data-refusal / data-reason attributes).
    try do
      case Catalog.ingest(source) do
        {:ok, _count} ->
          socket

        {:error, %Catalog.Error{} = error} ->
          assign(socket, :ingest_refusal, %{
            refusal: :catalog_ingest,
            reason: error.reason,
            detail: error.detail
          })
      end
    rescue
      error ->
        assign(socket, :ingest_refusal, %{
          refusal: :catalog_ingest,
          reason: error.__struct__,
          detail: Exception.message(error)
        })
    end
  end

  # ------------------------------------------------------------------ events

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    packs =
      case String.trim(q) do
        "" -> Catalog.list_packs()
        term -> Catalog.search(term)
      end

    {:noreply, assign(socket, search: q, packs: packs)}
  end

  # ------------------------------------------------------------------ render

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl min-h-screen bg-slate-950 text-slate-100 p-6 space-y-6">
      <header>
        <h1 class="text-2xl font-bold">Marketplace Catalog</h1>
        <p id="catalog-summary" class="text-slate-400 text-sm mt-1">
          {length(@packs)} pack{if length(@packs) == 1, do: "", else: "s"}
          {if @search == "", do: "in the catalog", else: "matching “#{@search}”"}
        </p>
      </header>

      <section>
        <form id="pack-search-form" phx-change="search">
          <input
            type="text"
            name="q"
            value={@search}
            placeholder="Search packs by name or description..."
            class="w-full bg-slate-800 border border-slate-700 rounded px-3 py-2 text-sm"
          />
        </form>
      </section>

      <section>
        <table id="pack-table" class="w-full text-sm">
          <thead>
            <tr class="text-left text-slate-400 uppercase text-xs border-b border-slate-800">
              <th class="py-2">Name</th>
              <th class="py-2">Version</th>
              <th class="py-2">Class</th>
              <th class="py-2">Readiness</th>
              <th class="py-2">Digest</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={pack <- @packs}
              id={"pack-row-#{pack.name}"}
              class="border-b border-slate-800 hover:bg-slate-900"
            >
              <td class="py-2 font-medium" data-pack-name={pack.name}>
                {pack.name}
                <span :if={pack.deprecated} class="ml-2 text-xs text-amber-400">deprecated</span>
                <div class="text-xs text-slate-400 truncate max-w-md">{pack.description}</div>
              </td>
              <td class="py-2">{pack.version}</td>
              <td class="py-2">{pack.pack_class || "—"}</td>
              <td class="py-2 text-xs text-slate-300">{pack.readiness}</td>
              <td class="py-2 font-mono text-xs text-slate-400">{truncate_digest(pack.digest)}</td>
            </tr>
            <tr :if={@packs == []}>
              <td colspan="5" class="py-6 text-center text-slate-500">
                No packs match.
              </td>
            </tr>
            <tr :if={assigns[:ingest_refusal]}>
              <td
                colspan="5"
                class="py-3 text-center text-xs text-amber-500"
                id="ingest-refusal"
                data-refusal={"#{@ingest_refusal.refusal}"}
                data-reason={"#{@ingest_refusal.reason}"}
              >
                catalog ingest refused: {inspect(@ingest_refusal)}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
    """
  end

  defp truncate_digest(digest) when is_binary(digest) do
    if String.length(digest) > @digest_width do
      String.slice(digest, 0, @digest_width) <> "…"
    else
      digest
    end
  end

  defp truncate_digest(_), do: "—"
end
