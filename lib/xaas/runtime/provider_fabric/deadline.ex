defmodule Xaas.Runtime.ProviderFabric.Deadline do
  @moduledoc "Provider fabric deadline primitive."
  defstruct expires_at: 0
  def new(ms,now \\ 0), do: %__MODULE__{expires_at: now+ms}
    def expired?(d,now), do: now>=d.expires_at
end
