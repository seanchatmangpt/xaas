defmodule Mix.Tasks.Xaas.Ultracode.Repos do
  @shortdoc "Lists (or registers) ultracode campaign target repositories"

  @moduledoc """
  The operator surface of the multi-repo registry (`Xaas.Ultracode.Repos`):
  which repositories the autonomic campaign may target (`--repo ALIAS`), and
  what each target is provisioned with.

      mix xaas.ultracode.repos

      mix xaas.ultracode.repos --register ALIAS --path /abs/clone \\
        [--sensing PROFILE] [--suite NAME] [--canonical-suite NAME] \\
        [--worktree-root PATH] [--refresh-before-sense] [--file PATH]

      mix xaas.ultracode.repos --refresh ALIAS|all

  With no `--register`, lists every registry entry (config baseline plus the
  durable registry file) with its validation status and registration gaps:
  a suite name reserved but not yet in `config :xaas,
  :ultracode_verifier_suites`, or a sensing profile without an
  implementation, is listed as a GAP -- the target is registered, and the
  dispatch path refuses it until the implementation lands.

  `--register` validates the entry under the registry law (alias format,
  existing git work tree at `--path`, name-format suite/profile, per-entry
  worktree root under the global root) and writes it to the durable registry
  file atomically. Existing file entries are preserved; a corrupt file is
  never clobbered. Defaults: `--sensing aps`, `--suite <alias>-dod`,
  `--canonical-suite <alias>-canonical`.

  `--refresh-before-sense` records `refresh: true` on the entry: the autonomic
  loop then fetches + fast-forwards that clone (`Repos.refresh/1`) before it
  pins `base_sha`. `--refresh ALIAS` runs that same step by hand; `--refresh
  all` runs it for every entry that opted in. Refresh is non-destructive
  (fetch + `merge --ff-only` only); a clone ahead of or diverged from its
  upstream is reported, never reset.

  This task is filesystem-only by law: it loads config (`loadconfig`) but
  never starts the application -- no Repo, no Oban, nothing beside a live
  campaign.
  """

  use Mix.Task

  alias Xaas.Ultracode.Repos

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          register: :string,
          path: :string,
          sensing: :string,
          suite: :string,
          canonical_suite: :string,
          worktree_root: :string,
          refresh: :string,
          refresh_before_sense: :boolean,
          file: :string
        ]
      )

    # Config WITHOUT app.start: the registry never boots a database or queue.
    Mix.Task.run("loadconfig")

    unless invalid == [] do
      Mix.raise("invalid arguments: #{inspect(invalid)}")
    end

    cond do
      opts[:register] -> register(opts)
      opts[:refresh] -> refresh(opts[:refresh])
      true -> list()
    end
  end

  # ------------------------------------------------------------------

  defp list do
    {results, warnings} = Repos.entries()

    for warning <- warnings do
      Mix.shell().error("WARNING: #{inspect(warning)}")
    end

    if results == %{} do
      Mix.shell().info("registry is empty (config :xaas, :ultracode_repos)")
    end

    results
    |> Enum.sort_by(fn {alias, _} -> alias end)
    |> Enum.each(fn {alias, result} ->
      case result do
        {:ok, entry} ->
          status = if Repos.ready?(entry), do: "ready", else: "reserved"

          Mix.shell().info(
            "#{alias}  [#{status}]  path=#{entry.path}  sensing=#{entry.sensing}  " <>
              "suite=#{entry.suite}  canonical=#{entry.canonical_suite || "-"}" <>
              if(entry.refresh, do: "  refresh=on", else: "")
          )

          case Repos.gaps(entry) do
            [] -> :ok
            gaps -> Mix.shell().info("  gaps: #{Enum.join(Enum.map(gaps, &to_string/1), ", ")}")
          end

        {:error, {:invalid_repo_entry, ^alias, reason}} ->
          Mix.shell().info("#{alias}  [INVALID]  #{inspect(reason)}")

        {:error, reason} ->
          Mix.shell().info("#{inspect(alias)}  [INVALID]  #{inspect(reason)}")
      end
    end)
  end

  defp register(opts) do
    alias = opts[:register] || Mix.raise("--register ALIAS is required")
    path = opts[:path] || Mix.raise("--path PATH is required with --register")

    raw = %{
      "path" => path,
      "sensing" => opts[:sensing] || "aps",
      "suite" => opts[:suite] || "#{alias}-dod",
      "canonical_suite" => opts[:canonical_suite] || "#{alias}-canonical",
      "worktree_root" => opts[:worktree_root],
      "refresh" => if(opts[:refresh_before_sense], do: true)
    }

    case Repos.register(%{alias => raw}, file: opts[:file]) do
      {:ok, [entry]} ->
        Mix.shell().info("registered #{entry.alias} -> #{entry.path}")

        Mix.shell().info(
          "sensing=#{entry.sensing} suite=#{entry.suite} canonical=#{entry.canonical_suite || "-"}" <>
            if(entry.refresh, do: " refresh=on", else: "")
        )

        case Repos.gaps(entry) do
          [] ->
            Mix.shell().info("status: ready (suite registered)")

          gaps ->
            Mix.shell().info(
              "status: reserved -- gaps (Run admission refuses until resolved): " <>
                Enum.join(Enum.map(gaps, &to_string/1), ", ")
            )
        end

      {:ok, other} ->
        Mix.raise("unexpected register result: #{inspect(other)}")

      {:error, reason} ->
        Mix.raise("registry refused #{alias}: #{format_error(reason)}")
    end
  end

  defp refresh("all") do
    {results, _warnings} = Repos.entries()

    aliases =
      for {alias, {:ok, %{refresh: true}}} <- results, do: alias

    if aliases == [] do
      Mix.shell().info("no registry entry opted in to refresh (--refresh-before-sense)")
    else
      # Every opted-in clone is attempted (one refusal never starves the
      # rest); the task fails at the end, naming each refusal.
      errors =
        aliases
        |> Enum.sort()
        |> Enum.flat_map(fn alias ->
          case refresh_one(alias) do
            :ok -> []
            {:error, message} -> [message]
          end
        end)

      if errors != [], do: Mix.raise(Enum.join(errors, "; "))
    end
  end

  defp refresh(alias) do
    case refresh_one(alias) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end

  defp refresh_one(alias) do
    case Repos.refresh(alias) do
      {:ok, %{status: status, upstream: upstream, from: from, head: head}} ->
        Mix.shell().info(
          "#{alias}  refresh=#{status}  upstream=#{upstream}  " <>
            "#{String.slice(from, 0, 12)} -> #{String.slice(head, 0, 12)}"
        )

      {:error, reason} ->
        {:error, "refresh refused #{alias}: #{format_error(reason)}"}
    end
  end

  defp format_error(reason) when is_tuple(reason) and is_atom(elem(reason, 0)),
    do: Enum.map_join(Tuple.to_list(reason), " ", &to_string/1)

  defp format_error(reason), do: inspect(reason)
end
