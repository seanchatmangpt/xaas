defmodule Xaas.Runtime.FOND.Deadline do
  def new(ms), do: System.monotonic_time(:millisecond) + ms
  def remaining(d), do: max(d - System.monotonic_time(:millisecond), 0)
  def expired?(d), do: remaining(d) == 0
end
