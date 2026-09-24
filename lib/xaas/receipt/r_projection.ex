defmodule Xaas.Receipt.RProjection do
  @moduledoc """
  Projects a sealed XaaS receipt into the fleet R schema
  (`~/.claude/dfcm/receipt.schema.json`, validated by
  `~/.claude/dfcm/validate_receipt.py`):

      identity    {subject, repo, subject_sha, base_sha}
      authority   {ceiling, grant, actor}
      consequence {commits, files_changed, remote_effects}
      replay      {commands: [{cmd, cwd, exit, summary}], durable_location}
      standing    {value, derived_from, broken_term when BLOCKED/BUILD_BROKEN/REFUSED}

  `write/2` reads the native receipt JSON and writes `<stem>.r.json` next to
  it. The native receipt is the semantic export
  (`Xaas.Ultracode.SemanticReceipt.export/1`, `mix xaas.semantic.receipt`).
  Nothing is promoted: every field comes from what the fabric sealed, from
  the real repository (`git rev-list` / `git diff`), or from an explicit
  option; a field the fabric did not observe is omitted and the standing
  says which R term it breaks.

  ## Seal

  The export's `receipt_digest` is an unkeyed sha256, so it proves the
  content was not altered after digesting -- never that the fabric sealed
  it (anyone can recompute it). A native receipt is therefore *sealed* only
  when (1) it carries a digest, (2) that digest recomputes over its own
  content, and (3) the fabric's own re-export of the same epoch
  (`Xaas.Ultracode.SemanticReceipt.sealed/1`, read from `Xaas.Repo`) carries
  the same digest. Every check fails closed: an absent digest, a mismatch,
  an epoch the fabric does not hold, or a re-export that differs is a typed
  REFUSED standing, never a default pass. A lease-close evidence map (no
  digest, no epoch) is refused the same way.

  ## Field sources

    * identity -- `subject` = the bridge's work-order `identity` (or
      `:subject`); `repo` = `:repo` (a local path makes the validator check
      `subject_sha` is a real commit) or the bridge's `repository`;
      `subject_sha` = the sealed `final_head` (or `fabric_verifier.head`);
      `base_sha` = the bridge's `base_sha` (or `:base_sha`).
    * authority -- ceiling `CONSTRUCT` (a lease commits in its own epoch
      worktree; publish/merge/deploy are outside the fabric's authority);
      grant = `xaas-lease:epoch:<epoch_id>`; actor = `:actor`, the native
      `executor`, else `xaas-fabric` (the sealer).
    * consequence -- the commits and files between `base_sha` and
      `subject_sha` in the local repository; with no local repository, the
      sealed `final_head` alone (`consequence.observed_from` records which).
      `remote_effects` is always `[]`: the fabric holds no remote authority.
    * replay -- one command per verifier step (court-alias rows that name a
      required court IRI are not commands). `cmd` is the registered suite
      step's argv (shell-quoted) when the suite is known, else a
      `xaas-verifier <suite>:<step>` label. For a sealed receipt the steps
      and their `exit` codes are read from the fabric's sealed closing
      evidence (the verifier's observed exit, never derived from a status).
      A step with no observed exit (timeout, spawn error) and every step of
      an unsealed receipt projects `exit` -1 with the summary saying the
      exit was not observed.
    * standing -- `ALIVE` only for outcome `alive` with `head_verified`, a
      passing verifier and every replay exit 0; `PARTIAL_ALIVE` for
      `partial_alive`; `BUILD_BROKEN` (`mu_unlawful`) for `build_broken`;
      `BLOCKED:<reason>` (`mu_on_O`) for `blocked`; otherwise `UNKNOWN`.
      Refusals come first: an incomplete identity is
      `REFUSED(R_missing_identity)`, no lease grant is
      `REFUSED(R_missing_authority)`, an unsealed receipt (see Seal) is
      `REFUSED(receipt_digest_absent)`, `REFUSED(receipt_digest_mismatch)` or
      `REFUSED(receipt_not_fabric_sealed)` (all `R_missing_identity`), no
      replay step is `REFUSED(R_missing_replay)`, an `alive` claim without
      its witnesses is `REFUSED(alive_unwitnessed)` (`admission_vacuous`).
  """

  alias Xaas.Ultracode.{SemanticReceipt, TargetSuites, Verifier}

  @sha ~r/\A[0-9a-f]{40}\z/

  @doc "Path of the R projection written next to `native_path` (`<stem>.r.json`)."
  @spec r_path(Path.t()) :: Path.t()
  def r_path(native_path), do: Path.rootname(native_path) <> ".r.json"

  @doc """
  Reads the native receipt at `native_path`, projects it (see `project/2`)
  with `durable_location` defaulting to `native_path`, and writes
  `r_path(native_path)`. Returns `{:ok, r_path, r}` or a typed error.
  """
  @spec write(Path.t(), keyword()) :: {:ok, Path.t(), map()} | {:error, term()}
  def write(native_path, opts \\ []) when is_binary(native_path) do
    with {:ok, body} <- read(native_path),
         {:ok, native} <- decode(body),
         {:ok, r} <- project(native, Keyword.put_new(opts, :durable_location, native_path)) do
      path = r_path(native_path)
      File.write!(path, Jason.encode!(r, pretty: true) <> "\n")
      {:ok, path, r}
    end
  end

  @doc """
  Projects a native XaaS receipt map into an R map. Options: `:repo`
  (local repository path or slug), `:repo_path` (local repository for the
  consequence diff when `:repo` is a slug), `:subject`, `:base_sha`,
  `:suite`, `:actor`, `:cwd` (replay cwd), `:durable_location`, `:suites`
  (suite declarations for argv resolution; default = configured verifier
  suites merged with `Xaas.Ultracode.TargetSuites.devs/0`).
  """
  @spec project(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def project(native, opts \\ [])

  def project(%{} = native, opts) do
    bridge = map_or_empty(native["bridge"])
    verifier = map_or_empty(native["fabric_verifier"])
    court = map_or_empty(verifier["court_receipt"])

    identity = identity(native, bridge, verifier, opts)
    repo_path = repo_path(identity["repo"], opts)
    authority = authority(native, opts)
    suite = opts[:suite] || verifier["suite"] || get_in(court, ["binding", "suite"])
    cwd = opts[:cwd] || repo_path || identity["repo"] || "."
    seal = seal(native)
    commands = commands(seal, verifier, bridge, suite, cwd, opts)

    replay =
      compact(%{"commands" => commands, "durable_location" => opts[:durable_location]})

    r =
      compact(%{
        "identity" => identity,
        "authority" => authority,
        "consequence" => consequence(repo_path, identity),
        "replay" => replay,
        "standing" => standing(native, seal, verifier, identity, authority, commands),
        "native" => native_provenance(native),
        "court" => court_projection(court)
      })

    {:ok, r}
  end

  def project(_other, _opts), do: {:error, {:r_projection_refused, :not_a_map}}

  # -- consistency (the GC23-7 court law; lane R1-X-COURTS) -----------------

  @doc """
  Judges an R projection `r` for internal consistency against the order it
  claims and the real subject repository (PRD GC23-7 "the episode produces
  conformant durable evidence"; ARD section 12; PR-011). The fleet validator
  checks the R schema, ALIVE replay exits and that `subject_sha` is a
  commit; it has no rule tying the five fields to each other, so an R that
  says ALIVE over a false acceptance, a consequence that is not the
  subject's, an out-of-scope change or a trivial replay command is ADMITTED
  by it. This function refuses each of those.

  Options: `:order` (required) -- the work-graph row the receipt is for
  (`identity`, `base_sha`, `path_scope`, `acceptance`, `falsifiers`,
  `required_courts`); `:repo` (required) -- the local subject repository
  the commits are read from (never the path the receipt names); `:suites`
  -- suite declarations (default: `Xaas.Ultracode.TargetSuites.devs/0`
  merged with the configured verifier suites).

  Laws, in order (first failure wins; every refusal is typed with a Chatman
  broken term):

    1. identity: `identity.subject` is the order and `identity.base_sha` its
       `base_sha` -- `REFUSED(receipt_not_for_order)` (`R_missing_identity`);
       `subject_sha` is a commit of `:repo` -- else
       `BLOCKED:subject_unreachable` (`mu_on_O`: the court cannot witness);
       `base_sha` is an ancestor of it -- `REFUSED(subject_not_descended)`
       (`R_missing_identity`).
    2. acceptance (ALIVE only): every order acceptance IRI is `true`, every
       order falsifier `"survived"`, every required court `passed` -- else
       `REFUSED(alive_acceptance_false)` (`admission_vacuous`).
    3. consequence: `consequence.commits` non-empty and each one in
       `git rev-list base_sha..subject_sha` -- `REFUSED(consequence_not_subject)`
       (`R_missing_consequence`); every recorded and every observed
       (`git diff --name-only base_sha subject_sha`) changed file is inside
       the order's `path_scope` (a scope entry `p` covers `p` and `p/...`) --
       `REFUSED(consequence_outside_path_scope)` (`R_missing_authority`); every
       recorded file was observed -- `REFUSED(consequence_not_observed)`
       (`R_missing_consequence`).
    4. replay: the court binding (`court.binding`: suite, step_id, head,
       argv_sha256) is on `subject_sha`, every court result carries the same
       binding, the registered suite's declaration still hashes to
       `argv_sha256` (`Xaas.Ultracode.Verifier.argv_digest/1`) and every
       replay command is that declaration's command for one of its steps,
       the bound step among them -- `REFUSED(replay_command_unbound)`
       (`R_missing_replay`). A command the court never ran (e.g. `true`)
       can never replay the evidence.

  `{:ok, facts}` (standing, subject, observed commits/files, the bound
  command) when every law holds.
  """
  @spec consistency(map(), keyword()) :: {:ok, map()} | {:refused, map()}
  def consistency(%{} = r, opts) do
    order = Keyword.fetch!(opts, :order)
    repo = Keyword.fetch!(opts, :repo)
    standing = get_in(r, ["standing", "value"])
    identity = map_or_empty(r["identity"])

    with :ok <- for_order(identity, order),
         :ok <- subject_reachable(repo, identity),
         :ok <- acceptance_witnessed(standing, map_or_empty(r["court"]), order),
         {:ok, observed} <- consequence_of_subject(repo, identity, r["consequence"], order),
         {:ok, command} <- replay_bound(r, identity, opts) do
      {:ok,
       %{
         "standing" => "CONSISTENT",
         "r_standing" => standing,
         "subject" => identity["subject"],
         "subject_sha" => identity["subject_sha"],
         "commits" => observed.commits,
         "files" => observed.files,
         "path_scope" => List.wrap(order["path_scope"]),
         "replay_command" => command
       }}
    end
  end

  def consistency(_other, _opts),
    do: inconsistent("receipt_not_for_order", "R_missing_identity", %{"reason" => "not a map"})

  defp for_order(identity, order) do
    cond do
      identity["subject"] != order["identity"] ->
        inconsistent("receipt_not_for_order", "R_missing_identity", %{
          "field" => "identity.subject",
          "expected" => order["identity"],
          "observed" => identity["subject"]
        })

      identity["base_sha"] != order["base_sha"] or not sha?(identity["base_sha"]) ->
        inconsistent("receipt_not_for_order", "R_missing_identity", %{
          "field" => "identity.base_sha",
          "expected" => order["base_sha"],
          "observed" => identity["base_sha"]
        })

      not is_list(order["path_scope"]) or order["path_scope"] == [] ->
        inconsistent("receipt_not_for_order", "R_missing_identity", %{
          "field" => "order.path_scope",
          "reason" => "the order declares no path scope to judge the consequence against"
        })

      true ->
        :ok
    end
  end

  defp subject_reachable(repo, %{"subject_sha" => head, "base_sha" => base}) do
    cond do
      not (sha?(head) and git_ok?(repo, ["cat-file", "-e", head <> "^{commit}"])) ->
        {:refused,
         %{
           "standing" => "BLOCKED:subject_unreachable",
           "reason" => "subject_unreachable",
           "broken_term" => "mu_on_O",
           "hop" => "receipt",
           "detail" => %{"subject_sha" => head, "repo" => repo}
         }}

      not git_ok?(repo, ["merge-base", "--is-ancestor", base, head]) ->
        inconsistent("subject_not_descended", "R_missing_identity", %{
          "base_sha" => base,
          "subject_sha" => head
        })

      true ->
        :ok
    end
  end

  defp subject_reachable(repo, identity),
    do:
      inconsistent("subject_not_descended", "R_missing_identity", %{
        "repo" => repo,
        "subject_sha" => identity["subject_sha"]
      })

  defp acceptance_witnessed("ALIVE", court, order) do
    acceptance = map_or_empty(court["acceptance_results"])
    falsifiers = map_or_empty(court["falsifier_results"])
    courts = map_or_empty(court["court_results"])

    unwitnessed =
      Enum.flat_map(List.wrap(order["acceptance"]), fn iri ->
        if acceptance[iri] == true,
          do: [],
          else: [%{"acceptance" => iri, "result" => acceptance[iri]}]
      end) ++
        Enum.flat_map(Map.to_list(acceptance), fn {iri, value} ->
          if value == true, do: [], else: [%{"acceptance" => iri, "result" => value}]
        end) ++
        Enum.flat_map(List.wrap(order["falsifiers"]), fn iri ->
          if falsifiers[iri] in ["survived", true],
            do: [],
            else: [%{"falsifier" => iri, "result" => falsifiers[iri]}]
        end) ++
        Enum.flat_map(List.wrap(order["required_courts"]), fn iri ->
          if get_in(courts, [iri, "passed"]) == true,
            do: [],
            else: [%{"court" => iri, "result" => courts[iri]}]
        end)

    cond do
      List.wrap(order["acceptance"]) == [] ->
        inconsistent("alive_acceptance_false", "admission_vacuous", %{
          "reason" => "the order declares no acceptance to witness ALIVE"
        })

      unwitnessed != [] ->
        inconsistent("alive_acceptance_false", "admission_vacuous", %{
          "unwitnessed" => Enum.uniq(unwitnessed)
        })

      true ->
        :ok
    end
  end

  defp acceptance_witnessed(_standing, _court, _order), do: :ok

  defp consequence_of_subject(repo, identity, consequence, order) do
    consequence = map_or_empty(consequence)
    base = identity["base_sha"]
    head = identity["subject_sha"]
    recorded_commits = consequence["commits"]
    recorded_files = consequence["files_changed"]
    scope = order["path_scope"]

    with {:ok, commits} <- git_lines(repo, ["rev-list", "--reverse", "#{base}..#{head}"]),
         {:ok, files} <- git_lines(repo, ["diff", "--name-only", base, head]) do
      outside = fn paths -> Enum.reject(paths, &in_scope?(&1, scope)) end

      cond do
        not (is_list(recorded_commits) and recorded_commits != [] and
                 Enum.all?(recorded_commits, &(&1 in commits))) ->
          inconsistent("consequence_not_subject", "R_missing_consequence", %{
            "recorded" => recorded_commits,
            "subject_commits" => commits
          })

        not (is_list(recorded_files) and Enum.all?(recorded_files, &is_binary/1)) ->
          inconsistent("consequence_not_observed", "R_missing_consequence", %{
            "recorded" => recorded_files
          })

        (bad = outside.(recorded_files ++ files)) != [] ->
          inconsistent("consequence_outside_path_scope", "R_missing_authority", %{
            "outside" => Enum.uniq(bad),
            "path_scope" => scope
          })

        (unseen = recorded_files -- files) != [] ->
          inconsistent("consequence_not_observed", "R_missing_consequence", %{
            "unobserved" => unseen,
            "observed" => files
          })

        true ->
          {:ok, %{commits: commits, files: files}}
      end
    else
      :error ->
        inconsistent("consequence_not_subject", "R_missing_consequence", %{
          "reason" => "git could not read #{base}..#{head} in #{repo}"
        })
    end
  end

  # A scope entry names a file or a directory (git's literal pathspec for
  # a path without glob characters): `lib` covers `lib` and `lib/...`.
  defp in_scope?(path, scope) do
    Enum.any?(scope, fn entry ->
      entry = String.trim_trailing(entry, "/")
      entry != "" and (path == entry or String.starts_with?(path, entry <> "/"))
    end)
  end

  defp replay_bound(r, identity, opts) do
    court = map_or_empty(r["court"])
    binding = map_or_empty(court["binding"])
    commands = get_in(r, ["replay", "commands"])
    suite = binding["suite"]

    declaration =
      if is_binary(suite) do
        opts
        |> Keyword.get_lazy(:suites, fn ->
          configured = Application.get_env(:xaas, :ultracode_verifier_suites, %{}) || %{}
          Map.merge(TargetSuites.devs(), configured)
        end)
        |> Map.get(suite)
      end

    steps = if is_map(declaration), do: List.wrap(Map.get(declaration, :steps)), else: []
    bound = Enum.find(steps, &(to_string(Map.get(&1, :id)) == binding["step_id"]))
    allowed = Enum.map(steps, &step_command/1)
    bound_command = bound && step_command(bound)

    unbound = fn reason, detail ->
      inconsistent(
        "replay_command_unbound",
        "R_missing_replay",
        Map.merge(%{"reason" => reason, "binding" => binding}, detail)
      )
    end

    cond do
      binding == %{} or not is_binary(suite) ->
        unbound.("no court binding records the command that produced the evidence", %{})

      binding["head"] != identity["subject_sha"] ->
        unbound.("the court binding judged another head", %{
          "subject_sha" => identity["subject_sha"]
        })

      Enum.any?(Map.values(map_or_empty(court["court_results"])), fn result ->
        not is_map(result) or
            Map.take(result, ~w(suite step_id head argv_sha256)) !=
              Map.take(binding, ~w(suite step_id head argv_sha256))
      end) ->
        unbound.("a court result carries another binding", %{})

      is_nil(declaration) ->
        unbound.("the bound suite is not declared", %{})

      Verifier.argv_digest(declaration) != binding["argv_sha256"] ->
        unbound.("the declared suite no longer hashes to the bound argv_sha256", %{
          "declared_argv_sha256" => Verifier.argv_digest(declaration)
        })

      is_nil(bound_command) ->
        unbound.("the bound step is not declared", %{})

      not (is_list(commands) and commands != []) ->
        unbound.("no replay command", %{})

      Enum.any?(commands, &(not is_map(&1) or &1["cmd"] not in allowed)) ->
        unbound.("a replay command is not the court-recorded command", %{
          "recorded" => Enum.map(List.wrap(commands), &(is_map(&1) && &1["cmd"])),
          "court_commands" => allowed
        })

      not Enum.any?(commands, &(&1["cmd"] == bound_command)) ->
        unbound.("the bound step's command is not replayed", %{"bound" => bound_command})

      true ->
        {:ok, bound_command}
    end
  end

  # The command a declared step runs, rendered exactly as `project/2`
  # renders replay commands (`step_cmd/3`).
  defp step_command(step) do
    case Map.get(step, :argv) do
      [_ | _] = argv -> Enum.map_join(argv, " ", &shell_quote/1)
      _ -> nil
    end
  end

  defp git_ok?(repo, args) do
    match?({_, 0}, System.cmd("git", ["-C", repo | args], stderr_to_stdout: true))
  end

  defp inconsistent(reason, term, detail) do
    {:refused,
     %{
       "standing" => "REFUSED(#{reason})",
       "reason" => reason,
       "broken_term" => term,
       "hop" => "receipt",
       "detail" => detail
     }}
  end

  # -- identity / authority -------------------------------------------------

  defp identity(native, bridge, verifier, opts) do
    compact(%{
      "subject" => opts[:subject] || bridge["identity"] || native["work_order_iri"],
      "repo" => opts[:repo] || bridge["repository"] || native["repository_identity"],
      "subject_sha" => native["final_head"] || verifier["head"],
      "base_sha" => opts[:base_sha] || bridge["base_sha"] || native["base_sha"]
    })
  end

  defp identity_complete?(identity) do
    is_binary(identity["subject"]) and identity["subject"] != "" and
      is_binary(identity["repo"]) and identity["repo"] != "" and
      sha?(identity["subject_sha"]) and sha?(identity["base_sha"])
  end

  defp authority(native, opts) do
    grant =
      case native["epoch_id"] do
        id when is_binary(id) and id != "" -> "xaas-lease:epoch:" <> id
        _ -> "NONE"
      end

    %{
      "ceiling" => "CONSTRUCT",
      "grant" => grant,
      "actor" => opts[:actor] || string_or_nil(native["executor"]) || "xaas-fabric"
    }
  end

  # -- consequence ----------------------------------------------------------

  defp repo_path(repo, opts) do
    Enum.find([opts[:repo_path], repo], fn path -> is_binary(path) and File.dir?(path) end)
  end

  defp consequence(repo_path, identity) do
    base = identity["base_sha"]
    head = identity["subject_sha"]

    case git_consequence(repo_path, base, head) do
      {:ok, commits, files} ->
        %{
          "commits" => commits,
          "files_changed" => files,
          "remote_effects" => [],
          "observed_from" => "git:" <> repo_path
        }

      :unobserved ->
        commits = if sha?(head) and head != base, do: [head], else: []

        %{
          "commits" => commits,
          "files_changed" => [],
          "remote_effects" => [],
          "observed_from" => "sealed-final-head"
        }
    end
  end

  defp git_consequence(repo_path, base, head) when is_binary(repo_path) do
    if sha?(base) and sha?(head) do
      with {:ok, commits} <- git_lines(repo_path, ["rev-list", "--reverse", "#{base}..#{head}"]),
           {:ok, files} <- git_lines(repo_path, ["diff", "--name-only", base, head]) do
        {:ok, commits, files}
      else
        _ -> :unobserved
      end
    else
      :unobserved
    end
  end

  defp git_consequence(_repo_path, _base, _head), do: :unobserved

  defp git_lines(dir, args) do
    case System.cmd("git", ["-C", dir | args], stderr_to_stdout: true) do
      {out, 0} -> {:ok, String.split(out, "\n", trim: true)}
      {_out, _code} -> :error
    end
  end

  # -- replay ---------------------------------------------------------------

  # Sealed: the steps (with their observed exits) come from the fabric's
  # sealed closing evidence. Unsealed: the native's steps, and no exit is
  # taken from them -- the standing is REFUSED either way.
  defp commands(seal, verifier, bridge, suite, cwd, opts) do
    aliases = MapSet.new(List.wrap(get_in(bridge, ["requires", "courts"])))
    declared = suite_steps(suite, opts)

    steps =
      case seal do
        {:sealed, sealed_verifier} -> sealed_verifier["steps"]
        {:refused, _reason} -> verifier["steps"]
      end

    for %{"id" => id} = step <- List.wrap(steps),
        is_binary(id),
        not MapSet.member?(aliases, id) do
      {exit_code, observed?} = step_exit(seal, step)

      %{
        "cmd" => step_cmd(declared, suite, id),
        "cwd" => cwd,
        "exit" => exit_code,
        "summary" => step_summary(suite, id, step["status"], observed?)
      }
    end
  end

  defp suite_steps(suite, opts) when is_binary(suite) do
    suites =
      Keyword.get_lazy(opts, :suites, fn ->
        configured = Application.get_env(:xaas, :ultracode_verifier_suites, %{}) || %{}
        Map.merge(TargetSuites.devs(), configured)
      end)

    case Map.get(suites, suite) do
      %{steps: steps} when is_list(steps) -> steps
      _ -> []
    end
  end

  defp suite_steps(_suite, _opts), do: []

  defp step_cmd(declared, suite, id) do
    case Enum.find(declared, &(to_string(Map.get(&1, :id)) == id)) do
      %{argv: [_ | _] = argv} -> Enum.map_join(argv, " ", &shell_quote/1)
      _ -> "xaas-verifier #{suite || "unknown-suite"}:#{id}"
    end
  end

  defp step_exit({:sealed, _}, %{"exit" => code}) when is_integer(code), do: {code, true}
  defp step_exit(_seal, _step), do: {-1, false}

  defp step_summary(suite, id, status, true),
    do: "#{suite || "unknown-suite"}/#{id}: status=#{status}"

  defp step_summary(suite, id, status, false),
    do:
      "#{suite || "unknown-suite"}/#{id}: status=#{status} " <>
        "(exit not observed in fabric-sealed verifier evidence)"

  defp shell_quote(arg) do
    if arg =~ ~r/\A[A-Za-z0-9_@%+=:,.\/{}-]+\z/,
      do: arg,
      else: "'" <> String.replace(arg, "'", ~S('"'"')) <> "'"
  end

  # -- standing -------------------------------------------------------------

  defp standing(native, seal, verifier, identity, authority, commands) do
    status = verifier["status"]
    outcome = native["outcome"]

    derived =
      "xaas receipt #{native["receipt_id"] || "?"} (#{seal_label(seal)}, " <>
        "outcome=#{outcome || "?"}, head_verified=#{inspect(native["head_verified"])}, " <>
        "verifier=#{status || "none"}) at #{identity["subject_sha"] || "?"}; " <>
        "replay: #{length(commands)} verifier step(s)"

    cond do
      not identity_complete?(identity) ->
        refused("R_missing_identity", "R_missing_identity", derived)

      authority["grant"] == "NONE" ->
        refused("R_missing_authority", "R_missing_authority", derived)

      match?({:refused, _}, seal) ->
        refused(elem(seal, 1), "R_missing_identity", derived)

      commands == [] ->
        refused("R_missing_replay", "R_missing_replay", derived)

      true ->
        outcome_standing(outcome, native, status, commands, derived)
    end
  end

  defp outcome_standing("alive", native, status, commands, derived) do
    if native["head_verified"] == true and status == "pass" and
         Enum.all?(commands, &(&1["exit"] == 0)) do
      %{"value" => "ALIVE", "derived_from" => derived}
    else
      refused("alive_unwitnessed", "admission_vacuous", derived)
    end
  end

  defp outcome_standing("partial_alive", _native, _status, _commands, derived),
    do: %{"value" => "PARTIAL_ALIVE", "derived_from" => derived}

  defp outcome_standing("build_broken", _native, _status, _commands, derived),
    do: %{"value" => "BUILD_BROKEN", "derived_from" => derived, "broken_term" => "mu_unlawful"}

  defp outcome_standing("blocked", native, _status, _commands, derived) do
    reason = string_or_nil(native["refusal_reason"]) || "worker_reported_blocked"
    %{"value" => "BLOCKED:" <> reason, "derived_from" => derived, "broken_term" => "mu_on_O"}
  end

  defp outcome_standing(_other, _native, _status, _commands, derived),
    do: %{"value" => "UNKNOWN", "derived_from" => derived}

  defp refused(reason, term, derived),
    do: %{"value" => "REFUSED(#{reason})", "derived_from" => derived, "broken_term" => term}

  # See the moduledoc's Seal section: integrity (the digest recomputes over
  # the native content) AND provenance (the fabric's re-export of the same
  # epoch carries the same digest). No branch defaults to sealed.
  defp seal(%{"receipt_digest" => digest} = native) when is_binary(digest) do
    if SemanticReceipt.receipt_digest(native) == digest,
      do: fabric_seal(native["epoch_id"], digest),
      else: {:refused, "receipt_digest_mismatch"}
  end

  defp seal(_native), do: {:refused, "receipt_digest_absent"}

  defp fabric_seal(epoch_id, digest) when is_binary(epoch_id) and epoch_id != "" do
    case SemanticReceipt.sealed(epoch_id) do
      {:ok, %{"receipt_digest" => ^digest}, sealed_verifier} ->
        {:sealed, map_or_empty(sealed_verifier)}

      {:ok, _differs, _sealed_verifier} ->
        {:refused, "receipt_not_fabric_sealed"}

      {:error, _unsealed} ->
        {:refused, "receipt_not_fabric_sealed"}
    end
  end

  defp fabric_seal(_epoch_id, _digest), do: {:refused, "receipt_not_fabric_sealed"}

  defp seal_label({:sealed, _}), do: "fabric-sealed"
  defp seal_label({:refused, reason}), do: "unsealed: " <> reason

  # -- provenance -----------------------------------------------------------

  defp native_provenance(native) do
    native
    |> Map.take(~w(receipt_id epoch_id run_id receipt_digest outcome head_verified))
    |> case do
      empty when map_size(empty) == 0 -> nil
      taken -> taken
    end
  end

  defp court_projection(court) do
    case Map.take(court, ~w(acceptance_results falsifier_results court_results binding)) do
      empty when map_size(empty) == 0 -> nil
      taken -> taken
    end
  end

  # -- helpers --------------------------------------------------------------

  defp read(path) do
    case File.read(path) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, {:r_projection_refused, {:unreadable, reason}}}
    end
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, %{} = native} -> {:ok, native}
      {:ok, _other} -> {:error, {:r_projection_refused, :not_a_map}}
      {:error, _} -> {:error, {:r_projection_refused, :invalid_json}}
    end
  end

  defp sha?(value), do: is_binary(value) and Regex.match?(@sha, value)

  defp string_or_nil(value) when is_binary(value) and value != "", do: value
  defp string_or_nil(_), do: nil

  defp map_or_empty(%{} = map), do: map
  defp map_or_empty(_), do: %{}

  defp compact(map), do: map |> Enum.reject(fn {_k, v} -> is_nil(v) end) |> Map.new()
end
