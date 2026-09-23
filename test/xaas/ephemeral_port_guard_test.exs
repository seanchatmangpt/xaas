defmodule Xaas.EphemeralPortGuardTest do
  @moduledoc """
  Guard for a flake class found in `Xaas.ActuationOcelUndoTest` (SJ-009): real test listeners
  bound a hash-derived port (`42_777 + :erlang.phash2(self(), 500)`), so two listeners (another
  test, a concurrent `mix test`, a lingering socket) could land on the same port and the
  second `listen` failed with `:eaddrinuse`. The fix is port `0`, reading the OS-assigned
  port back (`ThousandIsland.listener_info/1`, `:ranch.get_port/1`, `:inet.port/1`).

  The first test exhibits the failure mode with real sockets. The second is a source lint over
  `test/` so the same shape cannot come back.
  """
  use ExUnit.Case, async: true

  test "a second listener on a taken port fails with :eaddrinuse; port 0 never collides" do
    {:ok, first} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
    {:ok, taken} = :inet.port(first)

    assert {:error, :eaddrinuse} = :gen_tcp.listen(taken, ip: {127, 0, 0, 1})

    {:ok, second} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
    {:ok, assigned} = :inet.port(second)

    assert assigned != taken

    :ok = :gen_tcp.close(first)
    :ok = :gen_tcp.close(second)
  end

  test "no test derives a listener port from :erlang.phash2" do
    offenders =
      "test/**/*.{ex,exs}"
      |> Path.wildcard()
      |> Enum.reject(&(&1 == __ENV__.file |> Path.relative_to_cwd()))
      |> Enum.flat_map(fn path ->
        path
        |> File.stream!()
        |> Stream.with_index(1)
        |> Enum.filter(fn {line, _no} -> hashed_port?(line) end)
        |> Enum.map(fn {line, no} -> "#{path}:#{no}: #{String.trim(line)}" end)
      end)

    assert offenders == []
  end

  # A port-named binding computed from :erlang.phash2.
  defp hashed_port?(line) do
    Regex.match?(~r/\w*port\w*\s*=.*:erlang\.phash2/, line)
  end
end
