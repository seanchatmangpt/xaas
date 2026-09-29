defmodule Xaas.Ultracode.LogLock do
  @moduledoc """
  A kernel-arbitrated, cross-OS-process mutual-exclusion lock over one
  transition-log directory, for the check-then-append admission decision of
  `Xaas.Ultracode.SemanticJiraBridge`.

  `:global.trans/4` serializes admissions inside one BEAM node only. A second OS
  process (a `mix` task, a second node, a replaying CLI) appending to the same log
  directory is invisible to it, and two racing admissions of different receipts
  for one work order would both pass the frontier check and both append.

  The lock is an `flock(2)` advisory lock held by a small helper process
  (`perl`, present wherever xaas runs) that owns the lock file's descriptor
  until told to release. Because the KERNEL holds the lock on behalf of that
  process, it is released when the helper exits, whether the holder released
  normally or was killed: there is no stale lock file to steal, no owner PID to
  probe, and no rename race. A holder that dies leaves the lock free for the next
  waiter.

  Hand-written residue: no ggen pack manufactures OS-level locking, so this is
  recorded as `UNSUPPORTED(generator-capability)`. Refuses (typed) when `perl`
  is missing, the lock cannot be taken within the timeout, or the helper fails.
  """

  @lock_file ".bridge.lock"

  # Opens (creating) the lock file, takes an exclusive flock, reports "locked",
  # and holds it until stdin delivers a line (release) or closes (owner died).
  @helper ~S"""
  use Fcntl qw(:flock);
  open(my $fh, ">>", $ARGV[0]) or die "open: $!\n";
  flock($fh, LOCK_EX) or die "flock: $!\n";
  $| = 1;
  print "locked\n";
  my $line = <STDIN>;
  exit 0;
  """

  @release_wait_ms 5_000

  @doc "The lock file name inside a log directory (ignored by `TransitionLog.read/1`)."
  @spec lock_file() :: String.t()
  def lock_file, do: @lock_file

  @doc """
  Runs `fun` while holding the exclusive lock of `dir`. Returns `{:ok, result}`
  or `{:error, reason}` (`:perl_unavailable`, `:lock_timeout`,
  `{:lock_failed, exit_status}`); `fun` does not run on an error.
  """
  @spec with_lock(Path.t(), timeout(), (-> result)) :: {:ok, result} | {:error, term()}
        when result: term()
  def with_lock(dir, timeout_ms \\ 120_000, fun) when is_function(fun, 0) do
    File.mkdir_p!(dir)

    case acquire(Path.join(dir, @lock_file), timeout_ms) do
      {:ok, port} ->
        try do
          {:ok, fun.()}
        after
          release(port)
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp acquire(path, timeout_ms) do
    case System.find_executable("perl") do
      nil ->
        {:error, :perl_unavailable}

      perl ->
        port =
          Port.open({:spawn_executable, perl}, [
            :binary,
            :exit_status,
            :use_stdio,
            args: ["-e", @helper, path]
          ])

        receive do
          {^port, {:data, "locked\n"}} ->
            {:ok, port}

          {^port, {:exit_status, status}} ->
            {:error, {:lock_failed, status}}
        after
          timeout_ms ->
            close(port)
            {:error, :lock_timeout}
        end
    end
  end

  defp release(port) do
    Port.command(port, "release\n")

    receive do
      {^port, {:exit_status, _status}} -> :ok
    after
      @release_wait_ms -> close(port)
    end
  rescue
    ArgumentError -> :ok
  end

  defp close(port) do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end
end
