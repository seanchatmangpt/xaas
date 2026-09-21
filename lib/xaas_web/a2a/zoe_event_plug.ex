defmodule XaasWeb.A2A.ZoeEventPlug do
  @moduledoc """
  Thin `A2A.Plug` wrapper so the ZOE event-simulation agent can be forwarded
  separately from the Next Read agent (Phoenix allows one `forward` per plug
  module).
  """
  @behaviour Plug

  @impl true
  def init(opts), do: A2A.Plug.init(opts)

  @impl true
  def call(conn, opts), do: A2A.Plug.call(conn, opts)
end
