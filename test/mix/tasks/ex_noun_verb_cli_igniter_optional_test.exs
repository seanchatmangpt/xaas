defmodule Mix.Tasks.ExNounVerbCliIgniterOptionalTest do
  use ExUnit.Case, async: false

  # `:igniter` is an `optional: true` dependency, and the adapter at
  # `lib/mix/tasks/ex_noun_verb_cli.ex` `use`s `Igniter.Mix.Task` at
  # compile time -- so this repo's own suite (which always has :igniter)
  # can never prove the optional-dep contract by compiling itself the
  # normal way. This guard compiles `lib/` with `elixirc` with ONLY
  # :jason on the load path, reproducing an igniter-less consumer's
  # compile: the core must compile clean and the adapter module must be
  # skipped (defined behind `Code.ensure_loaded?(Igniter.Mix.Task)`),
  # exactly the failure `examples/greet-cli`-style consumers hit before
  # the guard existed ("module Igniter.Mix.Task is not loaded and could
  # not be found", 2026-09-15).

  test "lib/ compiles without :igniter on the load path; adapter module is skipped" do
    tmp = Path.join(System.tmp_dir!(), "exnv_no_igniter_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    on_exit(fn -> File.rm_rf!(tmp) end)

    root = File.cwd!()
    sources = Path.wildcard(Path.join(root, "lib/**/*.ex"))
    jason_ebin = Path.join(root, "_build/#{Mix.env()}/lib/jason/ebin")

    assert sources != [], "expected lib/**/*.ex sources to exist"
    assert File.dir?(jason_ebin), "expected :jason compiled at #{jason_ebin}"

    {output, exit_code} =
      System.cmd("elixirc", ["--warnings-as-errors", "-pa", jason_ebin, "-o", tmp] ++ sources,
        stderr_to_stdout: true
      )

    assert exit_code == 0, """
    lib/ must compile without :igniter on the load path (optional-dep
    contract); elixirc exited #{exit_code}:

    #{output}
    """

    assert File.exists?(Path.join(tmp, "Elixir.ExNounVerbCli.Dispatcher.beam")),
           "core modules must still be compiled"

    refute File.exists?(Path.join(tmp, "Elixir.Mix.Tasks.ExNounVerbCli.beam")),
           "the Igniter adapter module must be skipped when Igniter is not loadable"
  end
end
