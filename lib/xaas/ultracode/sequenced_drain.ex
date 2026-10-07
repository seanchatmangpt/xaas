defmodule Xaas.Ultracode.SequencedDrain do
  @moduledoc """
  In-process sequencing of ultracode waves with merge-before-next-wave.

  One batch is a real `Reactor` DAG (same style as `Xaas.Ultracode.EpochReactor`):

      refresh -> select -> wave -> integration -> merge -> verify

  A batch is not complete until its integration branch is merged into the canonical
  checkout and the merge verifies. `drain/1` loops batches until no open ticket matches,
  a ticket is stuck (tried twice without landing), or any step refuses. Refusals are typed
  and STOP the drain; there is no auto-resolution, reset or force (fix forward only).

  Compensation: a conflicted merge is aborted (`git merge --abort`) by the `:merge` step's
  `undo/4`. A merge that landed but failed verification is NOT undone (commits are
  immutable here); the drain halts `BUILD_BROKEN`/`TESTS_FAILED` for a fix-forward.

  Honest scope: the worker leg still crosses the `xaas-execution` MCP fabric (plain Ash
  Lease actions); only the `actuate` tool reaches the Ash.Reactor `Xaas.Actuation.run/4`.
  This module is a plain `Reactor` (not `Ash.Reactor`): the main-checkout merge is a local
  coordinator transition, not a provider DO.
  """

  use Reactor

  alias Xaas.Ultracode.{Campaign, Repos, Sensing}

  input(:repo_alias)
  input(:canonical)
  input(:pattern)
  input(:batch_size)
  input(:exclude)
  input(:wave_opts)

  step :refresh do
    argument(:repo_alias, input(:repo_alias))

    run(fn %{repo_alias: alias_}, _ctx ->
      case Repos.refresh(alias_) do
        {:ok, r} -> {:ok, r}
        {:error, e} -> {:error, {:refresh, e}}
      end
    end)
  end

  step :select do
    argument(:refresh, result(:refresh))
    argument(:repo_alias, input(:repo_alias))
    argument(:pattern, input(:pattern))
    argument(:batch_size, input(:batch_size))
    argument(:exclude, input(:exclude))

    run(fn args, _ctx ->
      with {:ok, entry} <- Repos.resolve(args.repo_alias),
           {:ok, profile} <- Sensing.profile(entry.sensing),
           {:ok, derived} <- Sensing.derive(profile, entry.path) do
        items = derived["items"] || derived[:items] || []
        ids = Enum.map(items, & &1["id"])

        case pick(ids, args.pattern, args.exclude, args.batch_size) do
          [] -> {:ok, %{ids: [], open: ids}}
          batch -> {:ok, %{ids: batch, open: ids}}
        end
      else
        {:error, e} -> {:error, {:select, e}}
      end
    end)
  end

  step :wave do
    argument(:sel, result(:select))
    argument(:repo_alias, input(:repo_alias))
    argument(:wave_opts, input(:wave_opts))

    run(fn
      %{sel: %{ids: []}}, _ctx ->
        {:ok, %{receipt: nil, skipped: :nothing_open}}

      %{sel: %{ids: ids}, repo_alias: alias_, wave_opts: wo}, _ctx ->
        opts =
          [
            capacity: length(ids),
            duration: wo[:duration] || "2h",
            wave_interval: wo[:wave_interval] || "10m",
            max_waves: 1,
            repo: alias_,
            only: ids,
            goal: "sequenced drain: #{Enum.join(ids, ",")}"
          ]

        case Campaign.start(opts) do
          {:ok, summary} ->
            wave = List.first(Map.get(summary, :waves, []))

            {:ok,
             %{
               receipt: wave && wave.receipt,
               standing: wave && wave.standing,
               run_id: summary.run_id
             }}

          {:error, e} ->
            {:error, {:wave, e}}
        end
    end)
  end

  step :integration do
    argument(:wave, result(:wave))

    run(fn
      %{wave: %{receipt: nil}}, _ctx ->
        {:ok, nil}

      %{wave: %{receipt: path}}, _ctx ->
        with {:ok, bytes} <- File.read(path),
             {:ok, doc} <- JSON.decode(bytes) do
          case doc["integration"] do
            %{"branch" => b, "head" => h} -> {:ok, %{branch: b, head: h}}
            _ -> {:ok, nil}
          end
        else
          e -> {:error, {:integration, e}}
        end
    end)
  end

  step :merge do
    argument(:integ, result(:integration))
    argument(:sel, result(:select))
    argument(:repo_alias, input(:repo_alias))
    argument(:canonical, input(:canonical))

    run(fn
      %{integ: nil}, _ctx ->
        {:ok, %{merged: false}}

      %{integ: %{branch: br}, sel: %{ids: ids}, repo_alias: alias_, canonical: main}, _ctx ->
        with {:ok, entry} <- Repos.resolve(alias_),
             :ok <- clean?(main),
             {_, 0} <- git(main, ["fetch", "-q", entry.path, "#{br}:refs/remotes/clone/#{br}"]),
             {_, 0} <-
               git(main, [
                 "merge",
                 "--no-ff",
                 "-m",
                 "merge: ultracode sequenced drain #{br} (#{Enum.join(ids, ",")})",
                 "refs/remotes/clone/#{br}"
               ]) do
          {:ok, %{merged: true, branch: br, head: rev(main)}}
        else
          {out, code} when is_integer(code) ->
            {:error, {:merge_conflict_or_fetch, code, String.slice(out, -300, 300)}}

          {:error, e} ->
            {:error, e}
        end
    end)

    undo(fn _res, %{canonical: main}, _ctx ->
      _ = git(main, ["merge", "--abort"])
      :ok
    end)
  end

  step :verify do
    argument(:merge, result(:merge))
    argument(:canonical, input(:canonical))

    run(fn
      %{merge: %{merged: false}}, _ctx ->
        {:ok, :nothing_to_verify}

      %{canonical: main}, _ctx ->
        env = [{"MIX_ENV", "test"}]
        changed = changed_tests(main)

        with {_, 0} <- cmd("mix", ["compile"], main, [{"MIX_ENV", "test"}]),
             :ok <- run_tests(changed, main, env) do
          {:ok, %{verified: true, tests: changed, head: rev(main)}}
        else
          {out, code} when is_integer(code) ->
            {:error, {:build_broken, code, String.slice(out, -400, 400)}}

          {:tests_failed, out} ->
            {:error, {:tests_failed, changed, String.slice(out, -400, 400)}}
        end
    end)
  end

  return(:verify)

  # -- public loop -----------------------------------------------------------------------------

  @doc """
  Drains open tickets matching `:pattern` for `:repo_alias`, one verified merge per batch.

  Options: `:repo_alias` ("xaas"), `:canonical` (path of the canonical checkout), `:pattern`
  (regex string), `:batch_size` (3), `:max_batches` (12), `:wave_opts`.
  """
  def drain(opts \\ []) do
    state = %{
      repo_alias: Keyword.get(opts, :repo_alias, "xaas"),
      canonical: Keyword.fetch!(opts, :canonical),
      pattern: Keyword.get(opts, :pattern, "jira-xa-30[0-9][0-9]-"),
      batch_size: Keyword.get(opts, :batch_size, 3),
      wave_opts: Keyword.get(opts, :wave_opts, []),
      tries: %{}
    }

    loop(state, Keyword.get(opts, :max_batches, 12), [])
  end

  defp loop(_state, 0, acc), do: {:ok, {:max_batches, Enum.reverse(acc)}}

  defp loop(state, n, acc) do
    exclude = for {id, t} <- state.tries, t >= 2, do: id

    inputs = %{
      repo_alias: state.repo_alias,
      canonical: state.canonical,
      pattern: state.pattern,
      batch_size: state.batch_size,
      exclude: exclude,
      wave_opts: state.wave_opts
    }

    case Reactor.run(__MODULE__, inputs, %{}, async?: false) do
      {:ok, _} ->
        # re-sense decides what is still open; ids attempted are counted so a ticket that
        # never lands is excluded after two tries (no infinite loop).
        batch = last_batch(inputs)

        case batch do
          [] ->
            {:ok, {:drained, Enum.reverse(acc)}}

          ids ->
            # W659 dual-safe: absent key seeds 1 (no fun call — otp-28
            # Map.update/4 semantics preserved), present key increments.
            tries =
              Enum.reduce(ids, state.tries, fn id, t ->
                case Map.fetch(t, id) do
                  {:ok, n} -> Map.put(t, id, n + 1)
                  :error -> Map.put(t, id, 1)
                end
              end)
            loop(%{state | tries: tries}, n - 1, [ids | acc])
        end

      {:error, reason} ->
        {:error, {:halted, reason, Enum.reverse(acc)}}
    end
  end

  defp last_batch(inputs) do
    with {:ok, entry} <- Repos.resolve(inputs.repo_alias),
         {:ok, profile} <- Sensing.profile(entry.sensing),
         {:ok, derived} <- Sensing.derive(profile, entry.path) do
      ids = Enum.map(derived["items"] || derived[:items] || [], & &1["id"])
      pick(ids, inputs.pattern, inputs.exclude, inputs.batch_size)
    else
      _ -> []
    end
  end

  # -- pure helpers (unit-tested) --------------------------------------------------------------

  @doc "Pure batch selection: matching, not excluded, first `n` in sorted order."
  def pick(ids, pattern, exclude, n) do
    re = Regex.compile!(pattern)

    ids
    |> Enum.filter(&Regex.match?(re, &1))
    |> Enum.reject(&(&1 in exclude))
    |> Enum.sort()
    |> Enum.take(n)
  end

  defp clean?(main) do
    case git(main, ["status", "--porcelain", "--untracked-files=no"]) do
      {"", 0} -> :ok
      {out, _} -> {:error, {:dirty_canonical, String.slice(out, 0, 200)}}
    end
  end

  defp changed_tests(main) do
    {out, _} = git(main, ["diff", "--name-only", "HEAD~1", "HEAD", "--", "test"])
    out |> String.split("\n", trim: true) |> Enum.filter(&String.ends_with?(&1, "_test.exs"))
  end

  defp run_tests([], _main, _env), do: :ok

  defp run_tests(files, main, env) do
    case cmd("mix", ["test" | files], main, env) do
      {_, 0} -> :ok
      {out, _} -> {:tests_failed, out}
    end
  end

  defp rev(main), do: main |> git(["rev-parse", "HEAD"]) |> elem(0) |> String.trim()
  defp git(dir, args), do: System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
  defp cmd(c, args, dir, env), do: System.cmd(c, args, cd: dir, env: env, stderr_to_stdout: true)
end
