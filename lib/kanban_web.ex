# ---
# Excerpted from "Engineering Elixir Applications",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material,
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose.
# Visit https://pragprog.com/titles/beamops for more book information.
# ---
defmodule KanbanWeb do
  @moduledoc """
  Entrypoint for the Phoenix web interface.

  Shared controller/component helpers stay intentionally small so transport,
  authorization, and Ash domain behavior remain explicit at their owning
  boundaries.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: KanbanWeb.Layouts]

      import Plug.Conn
      use Gettext, backend: KanbanWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {KanbanWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import KanbanWeb.CoreComponents
      use Gettext, backend: KanbanWeb.Gettext

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: KanbanWeb.Endpoint,
        router: KanbanWeb.Router,
        statics: KanbanWeb.static_paths()
    end
  end

  @doc "Dispatch to the requested web definition."
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
