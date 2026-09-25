defmodule ExNounVerbCli.Test.ComposingTaskFixture do
  @moduledoc """
  A real, throwaway `Igniter.Mix.Task` fixture that composes
  `Mix.Tasks.ExNounVerbCli` via `Igniter.compose_task/4`, used to prove real
  cross-task composition (not just direct invocation) per Igniter's own
  `compose_task`/group-namespacing contract -- see
  `test/mix/tasks/ex_noun_verb_cli_test.exs`'s
  "composed via Igniter.compose_task/4 by another real task" test.
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :composing_fixture,
      extra_args?: true
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.compose_task(igniter, Mix.Tasks.ExNounVerbCli, igniter.args.argv)
  end
end
