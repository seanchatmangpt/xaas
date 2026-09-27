defmodule Xaas.Ultracode.SemanticDrive.Episode do
  @moduledoc """
  Prepares a no-LLM KNOWN episode (GC-26.9.23 GC23-4..GC23-8; PRD PR-009,
  ARD section 14): a deterministic format-drift SUBJECT in the ggen_igniter
  repository and the two-order sJira work graph that drives it.

  `prepare/1` does three things, all deterministic:

    1. SUBJECT -- creates branch `v23/episode-<name>` in the ggen_igniter
       repository at `<base>` + ONE commit that introduces format drift in
       one `.ex`/`.exs` file (`drift/1`: the first `defmodule X do` line
       becomes `defmodule  X  do`, which `mix format` restores byte-exactly).
       The commit is built with git plumbing only (a private index,
       `hash-object --no-filters`, `commit-tree` with a fixed identity and
       fixed dates), so no checkout, index or hook of the repository is
       touched and the same base + path always yields the same commit id.
       An existing branch is reused only when it already points at exactly
       that commit; any other value is refused (`branch_diverged`), never
       moved.
    2. WORK GRAPH -- `<out_dir>/work.json`, `{"work_orders": [EP-A, EP-B],
       "court_maps": {"EP-A": ...}}`: EP-A repairs the drift through
       capability `recipe:mix-format`; EP-B depends on EP-A
       (`requiresReceipt`, ALIVE). Every order carries the admitted sJira
       fields, the pinned `origin_authority/0`, plus the FRI-T1 tuple (`postcondition`,
       `requires_capability`, `evidence_horizon`, `exclusions`,
       `consequence_class`, `authority_ceiling`, `successor_policy`). The
       court map binds EP-A's acceptance and falsifier IRIs to the
       `ggen-igniter-format` suite's `exit_status` receipt step (`format`).
       The graph side reads `work_orders` and ignores `court_maps`.
    3. LEDGER -- `<out_dir>/ledger.ndjson`, empty (a fresh standing ledger).

  Nothing here executes the subject, runs a model, or grants authority.
  """

  @namespace "https://ggen-igniter.dev/sjira/v26.9.23#"
  @repository "seanchatmangpt/ggen_igniter"
  @capability "recipe:mix-format"
  # Origin authority (G1, v26.9.25 post-tag hardening): both episode orders are
  # code work, so they originate from the canonical ggen_igniter objective
  # `sj:objective-code-work-authority`, pinned by
  # `sj:trust-root-objective-code-work-authority` in the canonical
  # semantic-jira-pack ontology (ggen_igniter 647db5f2). A module constant: the
  # episode never declares its own authority.
  @origin_authority "https://ggen-igniter.dev/ontology/semantic-jira#objective-code-work-authority"
  @suite_step "format"
  @name ~r/\A[a-z0-9][a-z0-9-]{0,31}\z/
  @sha ~r/\A[0-9a-f]{40}\z/
  @zero "0000000000000000000000000000000000000000"
  @drift_site ~r/^defmodule ([A-Za-z0-9_.]+) do$/m
  @fixed_date "2026-09-23T00:00:00+0000"
  @git_identity [
    {"GIT_AUTHOR_NAME", "xaas-episode"},
    {"GIT_AUTHOR_EMAIL", "episode@xaas.invalid"},
    {"GIT_AUTHOR_DATE", @fixed_date},
    {"GIT_COMMITTER_NAME", "xaas-episode"},
    {"GIT_COMMITTER_EMAIL", "episode@xaas.invalid"},
    {"GIT_COMMITTER_DATE", @fixed_date}
  ]

  @doc "The episode branch for `name` (`v23/episode-<name>`)."
  @spec branch(String.t()) :: String.t()
  def branch(name), do: "v23/episode-" <> name

  @doc "The canonical objective every episode order originates from (pinned trust root)."
  @spec origin_authority() :: String.t()
  def origin_authority, do: @origin_authority

  @doc "The subject capability every episode order resolves (`recipe:mix-format`)."
  @spec capability() :: String.t()
  def capability, do: @capability

  @doc """
  The repository root that owns `dir`'s objects (the parent of its common
  git dir): a linked worktree resolves to its main checkout.
  """
  @spec repo_root(String.t()) :: {:ok, String.t()} | {:refused, map()}
  def repo_root(dir) do
    case git(dir, ["rev-parse", "--path-format=absolute", "--git-common-dir"]) do
      {out, 0} ->
        common = String.trim(out)

        root =
          if Path.basename(common) == ".git", do: Path.dirname(common), else: common

        {:ok, root}

      {out, code} ->
        refused("ggen_igniter_not_a_repository", "mu_on_O", %{
          "dir" => dir,
          "git" => "#{code}: #{out}"
        })
    end
  end

  @doc """
  Applies the deterministic drift to `content`: the first line that is
  exactly `defmodule <Alias> do` gains two spaces on each side of the alias.
  `{:ok, drifted}` or `:no_drift_site`.
  """
  @spec drift(String.t()) :: {:ok, String.t()} | :no_drift_site
  def drift(content) when is_binary(content) do
    case Regex.run(@drift_site, content, return: :index) do
      [{start, length}, {alias_start, alias_length}] ->
        alias_name = binary_part(content, alias_start, alias_length)
        before = binary_part(content, 0, start)
        rest = binary_part(content, start + length, byte_size(content) - start - length)
        {:ok, before <> "defmodule  " <> alias_name <> "  do" <> rest}

      nil ->
        :no_drift_site
    end
  end

  @doc """
  Prepares episode `name`. Options: `:repo` (the ggen_igniter repository or
  any of its worktrees), `:name`, `:base` (40-hex commit), `:drift` (repo-
  relative `.ex`/`.exs` path), `:out_dir`, `:repository` (identity, default
  `seanchatmangpt/ggen_igniter`).

  Returns `{:ok, facts}` (`branch`, `subject_sha`, `base`, `drift`,
  `work_graph`, `ledger`, `repo`) or `{:refused, typed}`.
  """
  @spec prepare(keyword()) :: {:ok, map()} | {:refused, map()}
  def prepare(opts) do
    name = Keyword.fetch!(opts, :name)
    base = Keyword.fetch!(opts, :base)
    path = Keyword.fetch!(opts, :drift)
    out_dir = Keyword.fetch!(opts, :out_dir)
    repository = Keyword.get(opts, :repository, @repository)

    with :ok <- check(Regex.match?(@name, name), "invalid_episode_name", %{"name" => name}),
         :ok <- check(Regex.match?(@sha, base), "invalid_base", %{"base" => base}),
         :ok <- check(drift_path?(path), "invalid_drift_path", %{"drift" => path}),
         {:ok, repo} <- repo_root(Keyword.fetch!(opts, :repo)),
         :ok <- commit_exists(repo, base),
         {:ok, mode} <- tracked_mode(repo, base, path),
         {:ok, content} <- show(repo, base, path),
         {:ok, drifted} <- drifted(content, path),
         {:ok, subject} <- drift_commit(repo, base, path, mode, drifted, name),
         :ok <- ensure_branch(repo, branch(name), subject) do
      graph = work_graph(name, subject, path, repository)
      File.mkdir_p!(out_dir)
      work_path = Path.join(out_dir, "work.json")
      ledger_path = Path.join(out_dir, "ledger.ndjson")
      File.write!(work_path, Jason.encode!(graph, pretty: true) <> "\n")
      File.write!(ledger_path, "")

      facts = %{
        "schema" => "xaas/semantic-drive-episode/v1",
        "name" => name,
        "repository" => repository,
        "repo" => repo,
        "branch" => branch(name),
        "base" => base,
        "subject_sha" => subject,
        "drift" => %{"path" => path, "kind" => "defmodule_spacing"},
        "work_graph" => work_path,
        "ledger" => ledger_path,
        "orders" => Enum.map(graph["work_orders"], & &1["identity"])
      }

      {:ok, facts}
    end
  end

  @doc """
  The two-order work graph of episode `name` over subject commit `subject`
  (see the moduledoc).
  """
  @spec work_graph(String.t(), String.t(), String.t(), String.t()) :: map()
  def work_graph(name, subject, path, repository \\ @repository) do
    court = @namespace <> "court-episode-#{name}-format"
    evidence = @namespace <> "evidence-episode-#{name}-format-check"
    acceptance = @namespace <> "EP-A-#{name}-acceptance-format-check"
    falsifier = @namespace <> "EP-A-#{name}-falsifier-drift-absent"
    acceptance_b = @namespace <> "EP-B-#{name}-acceptance-format-check"
    falsifier_b = @namespace <> "EP-B-#{name}-falsifier-drift-absent"

    tuple = %{
      "evidence_ceiling" => "repository-local",
      "authority_ceiling" => "CONSTRUCT",
      "authority_requirement" => "NONE",
      "origin_authority" => @origin_authority,
      "postcondition" => "`mix format --check-formatted` exits 0 at the candidate head",
      "requires_capability" => @capability,
      "evidence_horizon" =>
        "exact-head run of the ggen-igniter-format court (`mix format --check-formatted`, exit status) on the candidate SHA in a clean worktree",
      "exclusions" => [
        "no LLM provider on the KNOWN path",
        "no file outside path_scope changes",
        "no push, merge or publish"
      ],
      "consequence_class" => "postcondition",
      "successor_policy" =>
        "a format drift the recipe cannot repair is typed UNSUPPORTED and handed to successor v23:GC-26.9.24",
      "next_checkpoint" => "GC-26.9.23",
      "projections" => ~w(jira sa2a worker verification receipt replay),
      "path_scope" => [".formatter.exs", "config", "lib", "mix.exs", "test"],
      "required_courts" => [court],
      "required_evidence" => [evidence],
      "required_receipt_classes" => ["verification"],
      "repository" => repository,
      "base_sha" => subject,
      "standing" => "UNKNOWN"
    }

    ep_a =
      Map.merge(tuple, %{
        "identity" => "EP-A",
        "title" => "Repair the deterministic mix format drift of episode #{name}",
        "description" =>
          "The reference KNOWN class (format-drift repair) on subject #{branch(name)}: the drift commit #{subject} changes #{path}; the recipe provider restores `mix format --check-formatted` with no model on the path.",
        "subject" => "#{repository}@#{branch(name)}#EP-A",
        "promotion_rule" =>
          "EP-A leaves UNKNOWN only through a ledger transition whose XaaS receipt binds the candidate head descended from #{subject}: the ggen-igniter-format court must observe exit 0 at that head and a non-zero exit when the recipe commit is reverted.",
        "replay_identity" => "semantic-jira:v26.9.23:episode:#{name}:EP-A",
        "acceptance" => [acceptance],
        "falsifiers" => [falsifier],
        "dependencies" => []
      })

    ep_b =
      Map.merge(tuple, %{
        "identity" => "EP-B",
        "title" => "Dependent order of episode #{name}: eligible only after EP-A is ALIVE",
        "description" =>
          "Fenced by EP-A: the frontier must hold EP-B until EP-A's receipt re-enters the ledger, then admit it (PRD PR-012).",
        "subject" => "#{repository}@#{branch(name)}#EP-B",
        "promotion_rule" =>
          "EP-B is eligible only when the ledger holds an ALIVE transition of EP-A; its own promotion follows EP-A's court law.",
        "replay_identity" => "semantic-jira:v26.9.23:episode:#{name}:EP-B",
        "acceptance" => [acceptance_b],
        "falsifiers" => [falsifier_b],
        "dependencies" => [
          %{"upstream" => "EP-A", "type" => "requiresReceipt", "required_standing" => "ALIVE"}
        ]
      })

    %{
      "schema" => "xaas/semantic-drive-work-graph/v1",
      "episode" => name,
      "checkpoint" => @namespace <> "GC-26.9.23",
      "work_orders" => [ep_a, ep_b],
      "court_maps" => %{
        "EP-A" => court_map(court, acceptance, falsifier),
        "EP-B" => court_map(court, acceptance_b, falsifier_b)
      }
    }
  end

  defp court_map(court, acceptance, falsifier) do
    %{
      "acceptance" => %{acceptance => %{"test" => @suite_step}},
      "falsifiers" => %{falsifier => %{"test" => @suite_step}},
      "courts" => [court]
    }
  end

  # -- git plumbing -------------------------------------------------------------

  defp drift_path?(path) do
    is_binary(path) and Path.type(path) == :relative and not String.contains?(path, "..") and
      Path.extname(path) in [".ex", ".exs"]
  end

  defp commit_exists(repo, sha) do
    case git(repo, ["cat-file", "-e", sha <> "^{commit}"]) do
      {_, 0} ->
        :ok

      {out, code} ->
        refused("base_not_in_repo", "mu_on_O", %{"base" => sha, "git" => "#{code}: #{out}"})
    end
  end

  defp tracked_mode(repo, base, path) do
    case git(repo, ["ls-tree", base, "--", path]) do
      {line, 0} ->
        case Regex.run(~r/\A(100644|100755) blob [0-9a-f]{40}\t/, line) do
          [_, mode] -> {:ok, mode}
          nil -> refused("drift_path_not_a_file", "mu_on_O", %{"drift" => path, "tree" => line})
        end

      {out, code} ->
        refused("drift_path_not_a_file", "mu_on_O", %{"drift" => path, "git" => "#{code}: #{out}"})
    end
  end

  defp show(repo, base, path) do
    case System.cmd("git", ["-C", repo, "show", "#{base}:#{path}"]) do
      {content, 0} -> {:ok, content}
      {out, code} -> refused("drift_path_unreadable", "mu_on_O", %{"git" => "#{code}: #{out}"})
    end
  end

  defp drifted(content, path) do
    case drift(content) do
      {:ok, drifted} -> {:ok, drifted}
      :no_drift_site -> refused("no_drift_site", "mu_on_O", %{"drift" => path})
    end
  end

  defp drift_commit(repo, base, path, mode, drifted, name) do
    tmp = Path.join(System.tmp_dir!(), "xaas-episode-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    try do
      blob_file = Path.join(tmp, "blob")
      message_file = Path.join(tmp, "MSG")
      File.write!(blob_file, drifted)

      File.write!(message_file, """
      episode(#{name}): deterministic mix format drift in #{path}

      Subject of the GC-26.9.23 no-LLM KNOWN episode #{name}
      (xaas lane V23-D, PRD PR-009, ARD section 14).
      drift: defmodule_spacing
      base: #{base}
      """)

      index = [{"GIT_INDEX_FILE", Path.join(tmp, "index")}]

      with {blob, 0} <- git(repo, ["hash-object", "-w", "--no-filters", blob_file]),
           {_, 0} <- git(repo, ["read-tree", base], index),
           {_, 0} <-
             git(
               repo,
               ["update-index", "--cacheinfo", "#{mode},#{String.trim(blob)},#{path}"],
               index
             ),
           {tree, 0} <- git(repo, ["write-tree"], index),
           {commit, 0} <-
             git(
               repo,
               [
                 "commit-tree",
                 "--no-gpg-sign",
                 String.trim(tree),
                 "-p",
                 base,
                 "-F",
                 message_file
               ],
               @git_identity
             ) do
        {:ok, String.trim(commit)}
      else
        {out, code} ->
          refused("drift_commit_failed", "mu_unlawful", %{"git" => "#{code}: #{out}"})
      end
    after
      File.rm_rf(tmp)
    end
  end

  defp ensure_branch(repo, branch, subject) do
    ref = "refs/heads/" <> branch

    case git(repo, ["rev-parse", "--verify", "-q", ref]) do
      {existing, 0} ->
        if String.trim(existing) == subject,
          do: :ok,
          else:
            refused("branch_diverged", "mu_unlawful", %{
              "branch" => branch,
              "existing" => String.trim(existing),
              "subject" => subject
            })

      {_, _absent} ->
        case git(repo, ["update-ref", "-m", "xaas episode subject", ref, subject, @zero]) do
          {_, 0} ->
            :ok

          {out, code} ->
            refused("branch_create_failed", "mu_unlawful", %{"git" => "#{code}: #{out}"})
        end
    end
  end

  defp check(true, _reason, _detail), do: :ok
  defp check(false, reason, detail), do: refused(reason, "mu_on_O", detail)

  defp refused(reason, broken_term, detail) do
    {:refused,
     %{
       "standing" => "REFUSED(#{reason})",
       "reason" => reason,
       "broken_term" => broken_term,
       "hop" => "prepare",
       "detail" => detail
     }}
  end

  defp git(dir, args, env \\ []) do
    System.cmd("git", ["-C", dir | args], env: env, stderr_to_stdout: true)
  end
end
