defmodule Xaas.Verifiers.PythonCourtsTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Runs the real Python unittest suites for the APS definition-of-done court and
  backlog generator (`priv/verifiers/tests/`), which themselves drive real git
  repositories, real subprocesses and a real APS clone. Tagged `:subprocess`
  (about a minute; excluded from the default run) and skipped by name when
  python3 or the APS clone is unavailable.
  """

  @moduletag :subprocess
  @moduletag timeout: 600_000

  test "the court and backlog suites pass" do
    python = System.find_executable("python3")

    if is_nil(python) do
      flunk("python3 not on PATH")
    end

    {output, status} =
      System.cmd(python, ["-m", "unittest", "discover", "-s", "priv/verifiers/tests"],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ ~r/Ran \d+ tests?/
    assert output =~ "OK"
  end
end
