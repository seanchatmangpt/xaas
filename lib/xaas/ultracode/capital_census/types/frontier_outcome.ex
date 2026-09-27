defmodule Xaas.Ultracode.CapitalCensus.Types.FrontierOutcome do
  use Ash.Type.Enum,
    values: [:blocked, :dispatch_refused, :worker_unclosed, :handed_off, :refused, :error]
end
