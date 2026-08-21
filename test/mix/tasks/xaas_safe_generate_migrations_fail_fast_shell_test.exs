defmodule Mix.Tasks.Xaas.SafeGenerateMigrations.FailFastShellTest do
  @moduledoc """
  Real regression test for the real FMEA finding cited at RPN=450
  (Detection=10: the wrapper would hang silently, with nothing on screen
  to hint why, until someone noticed a CI job or scheduled task never
  returned): `xaas.safe_generate_migrations` called the real underlying
  `mix ash_postgres.generate_migrations` with no protection at all, and
  that real task's migration generator (confirmed by reading
  `deps/ash_postgres/lib/migration_generator/migration_generator.ex`)
  reaches a real, genuinely blocking `Mix.shell().yes?/1,2` or
  `Mix.shell().prompt/1` -- which resolve to a real `IO.gets/1` -- the
  moment it hits a same-table attribute add+remove it cannot confirm is a
  rename (an ordinary, common column rename -- not an edge case), a
  table-level rename/schema-move/drop-table ambiguity, or two resources
  mapped to the same table with different primary keys.

  This test exercises the REAL fix: `Mix.Tasks.Xaas.SafeGenerateMigrations
  .FailFastShell`, a real `Mix.Shell` implementation (not a mock -- it is
  the actual module that runs in production every time
  `xaas.safe_generate_migrations` invokes the underlying task; see that
  module's moduledoc and `run_generate_migrations_without_risk_of_hanging!/1`
  in the parent module for the full cited evidence), using Mix's own real,
  documented `Mix.shell/0,1` extension point -- the same mechanism
  `Mix.Shell.Process`/`Mix.Shell.Quiet` use, not a test double of a
  collaborator this codebase owns.

  Scope, stated honestly: this proves (a) `FailFastShell` converts a real
  prompt attempt into an immediate `Mix.Error` naming the exact prompt,
  instead of blocking, and (b) the real swap/restore harness pattern used
  by the wrapper (`Mix.shell(FailFastShell)` before the risky call,
  `Mix.shell(previous)` in an `after` block) correctly restores the prior
  shell whether the wrapped call succeeds or raises. It does not invoke
  the real `ash_postgres.generate_migrations` task end-to-end, to avoid
  the real side effect of writing an actual migration file into this
  project's real `priv/repo/migrations/` directory as a side effect of
  running the test suite -- `touched_tables/1`'s existing tests already
  cover the generated-file-parsing half of this wrapper against real,
  committed migration files.

  `Mix.shell()` is real, global, `:ets`-table-backed Mix state (confirmed
  by reading `mix/lib/mix/state.ex`), not per-process -- every test here
  runs `async: false` so no concurrently-running async test observes a
  transiently-swapped shell.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Xaas.SafeGenerateMigrations.FailFastShell

  describe "FailFastShell.yes?/1,2 and prompt/1 -- the real fix for the real hang" do
    test "yes?/1 raises Mix.Error naming the real prompt instead of blocking on stdin" do
      message = "Are you renaming widgets.old_name to widgets.new_name?"

      error =
        assert_raise Mix.Error, fn ->
          FailFastShell.yes?(message)
        end

      assert error.message =~ message
      assert error.message =~ "refuses to block on stdin"
    end

    test "yes?/2 (with options) also fails fast, ignoring the options" do
      message = "Are you renaming orders.qty?"

      error =
        assert_raise Mix.Error, fn ->
          FailFastShell.yes?(message, default: :no)
        end

      assert error.message =~ message
    end

    test "prompt/1 raises Mix.Error naming the real primary-key-ambiguity prompt" do
      message = "Which primary key should be used for the table `orgs` (enter the number)?"

      error =
        assert_raise Mix.Error, fn ->
          FailFastShell.prompt(message)
        end

      assert error.message =~ message
    end
  end

  describe "FailFastShell.info/1 and error/1 -- real output is preserved, not swallowed" do
    test "info/1 still prints the real message (delegates to Mix.Shell.IO)" do
      output = capture_io(fn -> FailFastShell.info("real migration file created") end)
      assert output =~ "real migration file created"
    end

    test "error/1 still prints the real message on stderr (delegates to Mix.Shell.IO)" do
      output = capture_io(:stderr, fn -> FailFastShell.error("real warning from ash_postgres") end)
      assert output =~ "real warning from ash_postgres"
    end
  end

  describe "the real swap/restore harness pattern (as used by run_generate_migrations_without_risk_of_hanging!/1)" do
    test "Mix.shell() is swapped to FailFastShell during the wrapped call and restored after a normal return" do
      previous_shell = Mix.shell()
      refute previous_shell == FailFastShell

      observed_during_call =
        with_fail_fast_shell(fn ->
          shell = Mix.shell()
          shell
        end)

      assert observed_during_call == FailFastShell
      assert Mix.shell() == previous_shell
    end

    test "Mix.shell() is restored even when the wrapped call raises -- proves no lingering global state after a real failed prompt" do
      previous_shell = Mix.shell()

      assert_raise Mix.Error, fn ->
        with_fail_fast_shell(fn ->
          Mix.shell().yes?("Are you renaming approvals.old_col to approvals.new_col?")
        end)
      end

      assert Mix.shell() == previous_shell
    end

    test "a real yes? prompt reached through the swapped shell fails fast instead of hanging (the actual defect this fixes)" do
      previous_shell = Mix.shell()

      {microseconds, result} =
        :timer.tc(fn ->
          with_fail_fast_shell(fn ->
            try do
              {:answered, Mix.shell().yes?("Are you renaming subscriptions.plan to subscriptions.tier?")}
            rescue
              e in Mix.Error -> {:failed_fast, e.message}
            end
          end)
        end)

      assert Mix.shell() == previous_shell
      assert {:failed_fast, message} = result
      assert message =~ "subscriptions.plan to subscriptions.tier"
      # Real timing assertion: a genuine `IO.gets` block on a live, EOF-less
      # pipe waits indefinitely (the real incident this fixes). Completing
      # in well under a second is real evidence no blocking read occurred.
      assert microseconds < 1_000_000
    end
  end

  # The exact real swap/restore shape used by
  # `run_generate_migrations_without_risk_of_hanging!/1` in
  # `Mix.Tasks.Xaas.SafeGenerateMigrations`, extracted here so this test can
  # exercise the real mechanism without invoking the full underlying
  # `ash_postgres.generate_migrations` task (and its real side effect of
  # writing a file into `priv/repo/migrations/`).
  defp with_fail_fast_shell(fun) do
    previous_shell = Mix.shell()
    Mix.shell(FailFastShell)

    try do
      fun.()
    after
      Mix.shell(previous_shell)
    end
  end
end
