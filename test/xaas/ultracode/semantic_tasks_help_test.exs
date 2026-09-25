defmodule Xaas.Ultracode.SemanticTasksHelpTest do
  @moduledoc """
  SJ-001's runnable check ends in `mix xaas.semantic.materialize --help`; both
  semantic mix tasks must answer `--help` with their real usage text and exit
  cleanly instead of demanding their required option. Real task modules, real
  Mix shell capture; no application boot is involved on the help path.
  """

  use ExUnit.Case, async: false

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  test "materialize --help prints usage and does not require --descriptor" do
    Mix.Task.reenable("xaas.semantic.materialize")
    assert :ok = Mix.Tasks.Xaas.Semantic.Materialize.run(["--help"])

    assert_received {:mix_shell, :info, [usage]}
    assert usage =~ "mix xaas.semantic.materialize --descriptor"
    assert usage =~ "--ticket-file"
  end

  test "receipt --help prints usage and does not require --epoch" do
    Mix.Task.reenable("xaas.semantic.receipt")
    assert :ok = Mix.Tasks.Xaas.Semantic.Receipt.run(["--help"])

    assert_received {:mix_shell, :info, [usage]}
    assert usage =~ "mix xaas.semantic.receipt --epoch"
  end

  test "without --help the required option is still enforced" do
    assert_raise Mix.Error, ~r/--descriptor PATH is required/, fn ->
      Mix.Tasks.Xaas.Semantic.Materialize.run([])
    end

    assert_raise Mix.Error, ~r/--epoch EPOCH_ID is required/, fn ->
      Mix.Tasks.Xaas.Semantic.Receipt.run([])
    end
  end
end
