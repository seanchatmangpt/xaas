defmodule Xaas.Chicago.PresencePinTest do
  @moduledoc """
  Pin test for _CLOSURE_PLAN.md §1 row 8 (W353 disposition: RESOLVE-BY-TEST).

  `Xaas.Chicago` and `Xaas.Chicago.View` are core own modules that live in-tree
  (`lib/xaas/chicago.ex`, `lib/xaas/chicago/view.ex`). The `Code.ensure_loaded?/1`
  soft-gates in `lib/xaas_web/live/system/command_center_adapter.ex:81` and
  `lib/xaas_web/live/chicago/drill_down_live.ex:68,408` guard against these
  modules being absent — a premise from when L4 owned them ("compile-safe while
  Xaas.Chicago has not landed"). They have landed, so the `{:refused, ...}`
  fallback branches are dead code unless the modules are removed.

  Negative shape (falsifier): deleting or renaming either module makes the
  corresponding assertions below fail, forcing the soft-gates to be revisited
  rather than silently degraded. If the modules are ever extracted to an
  external dep (out of the same OTP app), this disposition flips to
  degraded-mode-legitimate and the guards become lawful again.
  """

  use ExUnit.Case, async: true

  test "Xaas.Chicago is loaded and exports its projection surface" do
    assert Code.ensure_loaded?(Xaas.Chicago)
    assert function_exported?(Xaas.Chicago, :subject, 0)
    assert function_exported?(Xaas.Chicago, :layers, 0)
    assert function_exported?(Xaas.Chicago, :cases, 0)
  end

  test "Xaas.Chicago.View is loaded and exports drill_down/0" do
    assert Code.ensure_loaded?(Xaas.Chicago.View)
    assert function_exported?(Xaas.Chicago.View, :drill_down, 0)
  end
end
