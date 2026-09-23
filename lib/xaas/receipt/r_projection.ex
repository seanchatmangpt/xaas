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

  alias Xaas.Ultracode.{SemanticReceipt, TargetSuites}

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
