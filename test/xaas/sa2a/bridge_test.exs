defmodule Xaas.Sa2a.BridgeTest do
  @moduledoc """
  Real, Chicago-style coverage for `Xaas.Sa2a.Bridge` -- closes the gap
  documented in HANDWRITTEN.md and `Xaas.Application`'s supervision tree:
  this GenServer was never started anywhere, so every sa2a-bridge-pack edge
  (`validate/1`, `admit/2`, `plan/2`, `execute/2`, `replay/2`) was dead code
  at runtime, calling `GenServer.call` on a process that had never been
  started.

  No test doubles of any kind -- this file uses only real OTP primitives
  (GenServer, Supervisor, ExUnit's own start_supervised) against the real
  Xaas.Sa2a.Bridge module. Two real, honestly-distinct branches,
  chosen at run time by `Xaas.Sa2a.Bridge.available?/0` -- the exact same
  `System.find_executable("autofde")` check `Xaas.Application` uses to gate
  the supervision-tree child spec:

    * `autofde` IS on PATH: start the real GenServer under a real
      `start_supervised!/1`, call `validate/1` against it, and assert a
      real response decoded from the real `autofde beam-bridge` subprocess
      over a real Port.
    * `autofde` is NOT on PATH (the environment this was authored and run
      in -- confirmed via `System.find_executable("autofde") == nil` and
      `which autofde` exiting non-zero): assert the real, honest startup
      failure `Xaas.Sa2a.Bridge.init/1`'s guard now returns, both directly
      via `start_link/1` and under a real `Supervisor.start_link/2` --
      never a silently-passing no-op.
  """
  use ExUnit.Case, async: false

  alias Xaas.Sa2a.Bridge

  describe "supervision-tree gate parity" do
    test "available?/0 agrees with a real System.find_executable/1 call for the real command" do
      # Real assertion, not a description: prove the helper Xaas.Application
      # relies on to decide whether to add this child at all is wired to the
      # real OS PATH lookup, not a hardcoded true/false.
      assert Bridge.available?() == (System.find_executable("autofde") != nil)
    end
  end

  describe "validate/1 against the real GenServer" do
    @tag :requires_autofde
    test "real round trip when autofde is on PATH" do
      if Bridge.available?() do
        pid = start_supervised!({Bridge, []})
        assert Process.alive?(pid)

        assert {:ok, %{"ok" => true}} = Bridge.validate([])
      else
        # Environment-dependent: absent-path behavior is covered by the
        # unconditional test below; nothing to round-trip without the binary.
        assert Bridge.available?() == false
      end
    end
  end

  describe "autofde absent from PATH" do
    # PATH is process-global; restore in on_exit. Not async-safe, so this
    # module runs serially (see `use ExUnit.Case` above).
    setup do
      original = System.get_env("PATH")

      empty =
        System.tmp_dir!() |> Path.join("bridge_test_empty_#{System.unique_integer([:positive])}")

      File.mkdir_p!(empty)
      System.put_env("PATH", empty)

      on_exit(fn ->
        if original, do: System.put_env("PATH", original), else: System.delete_env("PATH")
        File.rm_rf(empty)
      end)

      :ok
    end

    test "available?/0 is false and start fails with executable_not_found" do
      refute Bridge.available?()

      # init/1 {:stop, reason} on a linked start can kill the caller; trap exits.
      Process.flag(:trap_exit, true)

      assert {:error, {:executable_not_found, "autofde"}} = Bridge.start_link([])

      assert {:error, {:shutdown, {:failed_to_start_child, Bridge, reason}}} =
               Supervisor.start_link([{Bridge, []}], strategy: :one_for_one)

      assert reason == {:executable_not_found, "autofde"}
      assert {:error, _reason} = start_supervised({Bridge, []})
    end
  end
end
