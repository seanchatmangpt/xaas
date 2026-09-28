defmodule Xaas.Runtime.FOND.Policy do
 defstruct max_attempts: 8, timeout_ms: 30_000, retry_local?: true
 def new(opts \\ []), do: struct!(__MODULE__,opts)
 def allow_attempt?(p,n), do: n < p.max_attempts
end
