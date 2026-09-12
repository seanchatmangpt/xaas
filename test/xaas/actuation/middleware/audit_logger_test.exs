defmodule Xaas.Actuation.Middleware.AuditLoggerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Xaas.Actuation.Middleware.AuditLogger

  defmodule HaltingStep do
    @moduledoc false
    use Reactor.Step

    @impl true
    def run(_arguments, _context, _options) do
      {:halt, :deliberate_test_halt}
    end
  end

  defmodule HaltingReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware AuditLogger
    end

    step :halt_here, HaltingStep
  end

  test "halt/1 logs a reactor-level halt warning with duration, and event/3 logs the real halt reason" do
    log =
      capture_log(fn ->
        assert {:halted, _reactor} = Reactor.run(HaltingReactor, %{})
      end)

    assert log =~ "[Reactor.Audit] Reactor halted after"
    assert log =~ "µs"
    assert log =~ "[Reactor.Audit] Step :halt_here requested halt, reason: :deliberate_test_halt"
  end
end
