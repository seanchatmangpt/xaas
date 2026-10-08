defmodule Mix.Tasks.Xaas.ReleaseAudit do
  @shortdoc "Audits the repository-wide XaaS v26.8.21 release contract"
  @moduledoc """
  Performs deterministic, non-actuating release checks over every tracked source,
  configuration, migration, generated-client, and documentation surface that can
  be validated without external authority.

  The task intentionally fails closed. It does not deploy, mutate customer data,
  call cloud control planes, or repair findings automatically.
  """

  use Mix.Task

  @version File.read!("VERSION") |> String.trim()
  # W650k: constants advanced to the current capability surface. The original
  # seven-domain pins (Accounts/Billing/Governance/Ledger/Marketplace/
  # Operations/Platform, 70 resources total) predate the 12 later domains
  # (Library, A2a, Conference, Coupling, Generation, Graphlaw, Igniter, Ocel,
  # Security, TemporalMemory, Ultracode, Witness) that config/config.exs
  # already registers in `:ash_domains`. This is a re-pin to witnessed reality,
  # not a masking: the audit still verifies config == pin, per-domain counts,
  # uniqueness, and full bidirectional source<->domain registration.
  @domains [
    Xaas.Library,
    Xaas.Accounts,
    Xaas.A2a,
    Xaas.Billing,
    Xaas.Conference,
    Xaas.Coupling,
    Xaas.Generation,
    Xaas.Graphlaw,
    Xaas.Governance,
    Xaas.Igniter,
    Xaas.Ledger,
    Xaas.Marketplace,
    Xaas.Ocel,
    Xaas.Operations,
    Xaas.Platform,
    Xaas.Security,
    Xaas.TemporalMemory,
    Xaas.Ultracode,
    Xaas.Witness
  ]
  @resource_counts %{
    Xaas.Library => 7,
    Xaas.Accounts => 5,
    Xaas.A2a => 2,
    Xaas.Billing => 8,
    Xaas.Conference => 7,
    Xaas.Coupling => 1,
    Xaas.Generation => 1,
    Xaas.Graphlaw => 2,
    Xaas.Governance => 34,
    Xaas.Igniter => 2,
    Xaas.Ledger => 4,
    Xaas.Marketplace => 3,
    Xaas.Ocel => 5,
    Xaas.Operations => 21,
    Xaas.Platform => 7,
    Xaas.Security => 2,
    Xaas.TemporalMemory => 1,
    Xaas.Ultracode => 8,
    Xaas.Witness => 2
  }
  # Witnessed total across the 19 canonical domains (sum of @resource_counts).
  @resource_total Enum.sum(Map.values(@resource_counts))
  @text_extensions ~w(.css .env .ex .exs .hbs .heex .html .js .json .md .sh .sql .toml .ts .ttl .txt .yaml .yml)
  @stale_claims [
    {"legacy 69-resource total", ~r/\b69\s+(?:total|real)\s+resources\b/i},
    {"legacy route denominator", ~r/\b56\s+of\s+69\b/i},
    {"legacy Operations count", ~r/\bOperations\s*\|\s*17\b/i},
    {"legacy six-domain router claim", ~r/\ball\s+6\s+real\s+domains\b/i},
    {"legacy 49-resource API claim", ~r/\b(?:44\s+of\s+49|all\s+49\s+resources)\b/i},
    {"legacy single-Reactor claim", ~r/\bone\s+real\s+Reactor-orchestrated\s+workflow\b/i}
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    files = tracked_files!()

    failures =
      []
      |> check_version()
      |> check_version_tag()
      |> check_runtime_identity()
      |> check_domains()
      |> check_resource_registration()
      |> check_migration_uniqueness()
      |> check_text_integrity(files)
      |> check_json(files)
      |> check_shell(files)
      |> check_markdown_links(files)
      |> check_stale_claims(files)
      |> check_release_docs()
      |> check_rpc_alignment()

    case Enum.reverse(failures) do
      [] ->
        Mix.shell().info(
          "XAAS_RELEASE_AUDIT ALIVE version=#{@version} tracked_files=#{length(files)} ash_resources=#{@resource_total}"
        )

      failures ->
        Enum.each(failures, &Mix.shell().error(render_refusal({:release_audit, %{finding: &1}})))
        Mix.raise("v#{@version} release audit failed with #{length(failures)} finding(s)")
    end
  end

  @doc """
  Renders this task's typed-refusal line (Vector-2 §E): the machine-readable
  `REFUSED(<code>, detail: %{...})` form emitted alongside the human text on
  every refusal path. Refusal semantics are unchanged; output structure only.
  """
  def render_refusal({code, detail}) when is_atom(code) do
    "REFUSED(#{code}, detail: #{inspect(detail)})"
  end

  # W872: VERSION/.tool-versions/Dockerfile are REQUIRED release-audit inputs.
  # Their absence is not a soft finding — it is a loud typed refusal that
  # terminates the audit immediately (fail closed), unlike the scanned-doc
  # sites which record a typed finding and continue.
  defp required_input!(path) do
    case File.read(path) do
      {:ok, body} -> body
      {:error, reason} ->
        Mix.raise(
          "REFUSED(release_audit, detail: %{finding: \"required release-audit input " <>
            "#{path} unreadable: #{inspect(reason)}\"})"
        )
    end
  end

  defp check_version(failures) do
    version_file = required_input!("VERSION") |> String.trim()
    mix_version = Mix.Project.config()[:version]

    failures
    |> require_true(
      version_file == @version,
      "VERSION=#{inspect(version_file)} expected #{@version}"
    )
    |> require_true(
      mix_version == @version,
      "Mix version=#{inspect(mix_version)} expected #{@version}"
    )
  end

  # W612 (WP-5, OS-19): the audit validates the LIVE version baseline. The
  # newest vX.Y.Z git tag is the release identity; VERSION/mix.exs pins must
  # agree with it, and the tagged release's closure receipts must exist on
  # disk. Tag absent or pins diverged => typed finding (fail closed); the
  # W872/W896 court contracts above are untouched — this is an added leg.
  defp check_version_tag(failures) do
    case newest_release_tag() do
      {:ok, nil} ->
        [
          "no vX.Y.Z release tag present for VERSION baseline #{@version} — tag absent"
          | failures
        ]

      {:ok, tag} ->
        cond do
          tag != "v" <> @version ->
            [
              "release tag #{tag} does not match VERSION baseline #{@version} — pins diverged"
              | failures
            ]

          true ->
            Enum.reverse(closure_receipt_findings(@version), failures)
        end

      {:error, reason} ->
        ["git tag listing failed: #{inspect(reason)}" | failures]
    end
  end

  @doc """
  W612: newest `vX.Y.Z` tag in the repo of the current working directory, or
  `{:ok, nil}` when no such tag exists. `{:error, reason}` only on git
  transport failure.
  """
  def newest_release_tag do
    case System.cmd("git", ["tag", "--list", "v[0-9]*"], stderr_to_stdout: true) do
      {output, 0} ->
        tag =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&Regex.match?(~r/^v\d+\.\d+\.\d+$/, &1))
          |> case do
            [] ->
              nil

            tags ->
              # W650k fix: Elixir's Version.parse/1 rejects the "v" prefix, so
              # the previous mapper returned 0.0.0 for every tag and max_by
              # collapsed to the lexically-first listing (v26.10.6), making
              # the baseline check report a false divergence whenever the
              # true newest tag sorts after it. Strip the prefix before
              # parsing so versions compare numerically.
              Enum.max_by(tags, fn t ->
                case t |> String.trim_leading("v") |> Version.parse() do
                  {:ok, v} -> v
                  :error -> Version.parse!("0.0.0")
                end
              end, &(Version.compare(&1, &2) != :lt))
          end

        {:ok, tag}

      {output, status} ->
        {:error, "exit=#{status}: #{String.trim(output)}"}
    end
  end

  @doc """
  W612: fail-closed findings validating the tagged release's closure-receipt
  surface: `_CLOSURE_PLAN.md` present, receipt corpus non-empty, and every
  explicit `docs/sjira/<version>/plans/...` reference in the closure plan
  resolves to >=1 file on disk (glob references expanded).
  """
  def closure_receipt_findings(version) do
    plan_path = "docs/sjira/v#{version}/_CLOSURE_PLAN.md"
    plans_dir = "docs/sjira/v#{version}/plans"

    receipt_count =
      if File.dir?(plans_dir),
        do: Path.wildcard(Path.join(plans_dir, "*.md")) |> length(),
        else: 0

    plan_source =
      case File.read(plan_path) do
        {:ok, source} -> source
        {:error, _} -> ""
      end

    []
    |> require_true(
      plan_source != "",
      "closure plan missing for tagged release v#{version}: #{plan_path}"
    )
    |> require_true(
      receipt_count > 0,
      "closure receipt corpus empty for tagged release v#{version}: #{plans_dir}"
    )
    |> then(fn failures ->
      if plan_source == "" do
        failures
      else
        Enum.reduce(unresolved_plan_refs(plan_source, version), failures, fn ref, acc ->
          ["closure plan reference does not resolve on disk: #{ref}" | acc]
        end)
      end
    end)
  end

  defp unresolved_plan_refs(plan_source, version) do
    ~r{(docs/sjira/v#{version}/plans/[A-Za-z0-9_\-\.\*\[\]\{\}]+\.md)}
    |> Regex.scan(plan_source, capture: :all_but_first)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
    |> Enum.reject(&(Path.wildcard(&1) != []))
  end

  defp check_runtime_identity(failures) do
    tool_versions = required_input!(".tool-versions")
    dockerfile = required_input!("Dockerfile")

    failures
    |> require_true(
      String.contains?(tool_versions, "elixir 1.20.2-otp-28"),
      ".tool-versions must pin Elixir 1.20.2 for OTP 28"
    )
    |> require_true(
      String.contains?(tool_versions, "erlang 28.5.0.2"),
      ".tool-versions must pin OTP 28.5.0.2"
    )
    |> require_true(
      String.contains?(dockerfile, "ARG ELIXIR_VERSION=1.20.2"),
      "Dockerfile Elixir identity is not aligned"
    )
    |> require_true(
      String.contains?(dockerfile, "ARG OTP_VERSION=28.5.0.2"),
      "Dockerfile OTP identity is not aligned"
    )
  end

  defp check_domains(failures) do
    configured = Application.fetch_env!(:xaas, :ash_domains)
    actual_counts = Map.new(@domains, &{&1, length(Ash.Domain.Info.resources(&1))})
    resources = Enum.flat_map(@domains, &Ash.Domain.Info.resources/1)

    failures
    |> require_true(
      configured == @domains,
      "configured Ash domains differ from canonical nineteen-domain order"
    )
    |> require_true(
      actual_counts == @resource_counts,
      "Ash resource counts drifted: #{inspect(actual_counts)}"
    )
    |> require_true(
      length(resources) == @resource_total,
      "expected #{@resource_total} domain resources, observed #{length(resources)}"
    )
    |> require_true(
      length(Enum.uniq(resources)) == length(resources),
      "one or more Ash resources are registered in multiple domains"
    )
  end

  defp check_resource_registration(failures) do
    registered =
      @domains
      |> Enum.flat_map(&Ash.Domain.Info.resources/1)
      |> MapSet.new()

    {source_module_list, absent_findings} =
      Path.wildcard("lib/xaas/**/*.ex")
      |> Enum.flat_map_reduce([], fn path, acc ->
        case File.read(path) do
          {:ok, source} ->
            modules =
              if resource_definition_file?(source) do
                case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, source, capture: :all_but_first) do
                  [module] -> [Module.concat([module])]
                  _ -> []
                end
              else
                []
              end

            {modules, acc}

          # Typed finding instead of a raise: a tracked-but-deleted-in-worktree
          # file is an audit finding, not a crash (same pattern as the rpc
          # check's :enoent arm below).
          {:error, :enoent} ->
            {[], ["tracked source file absent in worktree: #{path}" | acc]}
        end
      end)

    source_modules =
      source_module_list
      |> MapSet.new()
      # Xaas.Resource is the shared base resource (config `base_resources`),
      # deliberately outside every domain — not an orphan.
      |> MapSet.delete(Xaas.Resource)

    failures = Enum.reverse(absent_findings, failures)

    missing = MapSet.difference(source_modules, registered) |> MapSet.to_list()

    registered_names = MapSet.new(registered, &inspect/1)

    absent_source =
      registered
      |> MapSet.difference(source_modules)
      |> MapSet.to_list()
      # AshPaperTrail (`include_versions?(true)`) generates `<Resource>.Version`
      # modules at compile time and registers them into the domain; the
      # generator, not a hand-written file, still resolves the parent resource
      # on disk. Reject only when the parent resource is itself registered.
      |> Enum.reject(fn module ->
        name = inspect(module)

        String.ends_with?(name, ".Version") and
          name
          |> String.split(".")
          |> Enum.drop(-1)
          |> Enum.join(".")
          |> then(&MapSet.member?(registered_names, &1))
      end)

    failures
    |> require_true(
      missing == [],
      "Xaas.Resource modules missing from domains: #{inspect(missing)}"
    )
    |> require_true(
      absent_source == [],
      "domain resources missing canonical source modules: #{inspect(absent_source)}"
    )
  end

  # W650k: a canonical resource-definition source is a file whose FIRST
  # `defmodule` uses `Xaas.Resource` or directly uses `Ash.Resource` (with the
  # option-list comma). The comma disambiguates from `use Ash.Resource.Change`
  # / `use Ash.Resource.Validation` in changes/validations files. Previously
  # only `use Xaas.Resource` counted, which hid real resource sources such as
  # `Xaas.Accounts.Token.RevokeNonce` (uses `Ash.Resource` directly because
  # `Xaas.Resource` + a required `:expires_at` attribute conflicts with
  # AshOnetime's reserved verification-input names -- see its moduledoc).
  defp resource_definition_file?(source) do
    String.contains?(source, "use Xaas.Resource") or
      Regex.match?(~r/use Ash\.Resource,/, source)
  end

  defp check_migration_uniqueness(failures) do
    {declarations, absent_findings} =
      Path.wildcard("priv/repo/migrations/*.exs")
      |> Enum.flat_map_reduce([], fn path, acc ->
        case File.read(path) do
          {:ok, source} ->
            up_source = String.split(source, "def down do", parts: 2) |> hd()

            tables =
              Regex.scan(~r/create\s+table\(:([a-zA-Z0-9_]+)/, up_source, capture: :all_but_first)
              |> Enum.map(fn [table] -> {table, path} end)

            {tables, acc}

          # Typed finding instead of a raise on absent-in-worktree migrations.
          {:error, :enoent} ->
            {[], ["tracked migration absent in worktree: #{path}" | acc]}
        end
      end)

    failures = Enum.reverse(absent_findings, failures)

    duplicates =
      declarations
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_table, paths} -> length(Enum.uniq(paths)) > 1 end)

    require_true(
      failures,
      duplicates == [],
      "duplicate migration table creates: #{inspect(duplicates)}"
    )
  end

  defp check_text_integrity(failures, files) do
    files
    |> Enum.filter(&text_file?/1)
    |> Enum.reduce(failures, fn path, acc ->
      case File.read(path) do
        {:ok, content} ->
          acc
          |> require_true(
            not String.contains?(content, "\0"),
            "NUL byte in tracked text file #{path}"
          )
          |> require_true(
            not Regex.match?(~r/^<<<<<<< |^=======$|^>>>>>>> /m, content),
            "merge-conflict marker in #{path}"
          )

        {:error, reason} ->
          ["cannot read tracked text file #{path}: #{inspect(reason)}" | acc]
      end
    end)
  end

  defp check_json(failures, files) do
    files
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.reduce(failures, fn path, acc ->
      case File.read(path) do
        {:ok, body} ->
          case Jason.decode(body) do
            {:ok, _} -> acc
            {:error, error} -> ["invalid JSON #{path}: #{Exception.message(error)}" | acc]
          end

        # Typed finding instead of a raise on absent-in-worktree JSON files.
        {:error, :enoent} ->
          ["tracked JSON file absent in worktree: #{path}" | acc]
      end
    end)
  end

  defp check_shell(failures, files) do
    files
    |> Enum.filter(&String.ends_with?(&1, ".sh"))
    |> Enum.reduce(failures, fn path, acc ->
      case System.cmd("bash", ["-n", path], stderr_to_stdout: true) do
        {_output, 0} ->
          acc

        {output, status} ->
          ["bash -n failed #{path} exit=#{status}: #{String.trim(output)}" | acc]
      end
    end)
  end

  defp check_markdown_links(failures, files) do
    files
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.reduce(failures, fn path, acc ->
      case File.read(path) do
        {:ok, source} ->
          scan_markdown_links(path, source, acc)

        # Typed finding instead of a raise on absent-in-worktree markdown.
        {:error, :enoent} ->
          ["tracked markdown file absent in worktree: #{path}" | acc]
      end
    end)
  end

  defp scan_markdown_links(path, source, acc) do
    Regex.scan(~r/\[[^\]]*\]\(([^)]+)\)/, source, capture: :all_but_first)
    |> Enum.reduce(acc, fn [raw_target], inner_acc ->
        target =
          raw_target
          |> String.trim()
          |> String.trim_leading("<")
          |> String.trim_trailing(">")
          |> String.split(~r/\s+["']/, parts: 2)
          |> hd()

        if external_or_anchor?(target) do
          inner_acc
        else
          relative = target |> String.split(~r/[?#]/, parts: 2) |> hd() |> URI.decode()
          resolved = Path.expand(relative, Path.dirname(path))
          root = File.cwd!()

          inner_acc
          |> require_true(
            String.starts_with?(resolved, root),
            "Markdown link escapes repository in #{path}: #{target}"
          )
          |> require_true(File.exists?(resolved), "broken Markdown link in #{path}: #{target}")
        end
      end)
  end

  defp check_stale_claims(failures, files) do
    files
    |> Enum.filter(&text_file?/1)
    |> Enum.reject(&(&1 == "lib/mix/tasks/xaas.release_audit.ex"))
    |> Enum.reduce(failures, fn path, acc ->
      case File.read(path) do
        {:ok, source} ->
          Enum.reduce(@stale_claims, acc, fn {label, pattern}, inner_acc ->
            require_true(inner_acc, not Regex.match?(pattern, source), "#{label} remains in #{path}")
          end)

        # Typed finding instead of a raise on absent-in-worktree files: the
        # stale-claim contract for that path cannot be checked, so the audit
        # fails closed on a typed finding rather than crashing (W814 F1).
        {:error, :enoent} ->
          ["stale-claim scan: tracked file absent in worktree: #{path}" | acc]
      end
    end)
  end

  defp check_release_docs(failures) do
    prd = "docs/PRD-v26.8.21.md"
    architecture = "docs/claude/diataxis/explanation/architecture-overview.md"

    failures
    |> require_true(File.exists?(prd), "missing #{prd}")
    |> require_true(
      File.exists?(prd) and String.contains?(File.read!(prd), "XaaS v26.8.21"),
      "PRD does not identify XaaS v26.8.21"
    )
    |> then(&append_architecture_finding(&1, architecture))
  end

  # W872: the architecture overview is a SCANNED doc, not a required input —
  # its absence is a typed audit finding feeding the fail-closed refusal
  # path, never a File.Error crash (same pattern as the rpc check).
  defp append_architecture_finding(failures, architecture) do
    case File.read(architecture) do
      {:ok, source} ->
        require_true(
          failures,
          String.contains?(source, "**#{@resource_total}**"),
          "architecture overview does not carry the canonical #{@resource_total}-resource total"
        )

      {:error, reason} ->
        ["cannot read #{architecture}: #{inspect(reason)}" | failures]
    end
  end

  defp check_rpc_alignment(failures) do
    # Typed finding instead of a raise when the tracked config is absent in
    # the worktree (same pattern as the router arm below).
    {config, config_findings} =
      case File.read("config/config.exs") do
        {:ok, config} -> {config, []}
        {:error, :enoent} -> {"", ["tracked config absent in worktree: config/config.exs"]}
      end

    failures =
      Enum.reverse(config_findings, failures)
      |> require_true(
        String.contains?(config, ~s(run_endpoint: "/internal-api/rpc/run")),
        "AshTypescript run endpoint is not canonical"
      )
      |> require_true(
        String.contains?(config, ~s(validate_endpoint: "/internal-api/rpc/validate")),
        "AshTypescript validate endpoint is not canonical"
      )

    # c5f127cc renamed kanban_web -> xaas_web; the audit reference follows.
    case File.read("lib/xaas_web/router.ex") do
      {:ok, router} ->
        failures
        |> require_true(
          # Match the argument list, tolerating both `post "..."` and
          # `post("...")` Phoenix spellings (the live router uses parens).
          String.contains?(router, ~s("/rpc/run", AshTypescriptRpcController, :run)),
          "Phoenix router does not mount the generated run endpoint"
        )
        |> require_true(
          String.contains?(router, ~s("/rpc/validate", AshTypescriptRpcController, :validate)),
          "Phoenix router does not mount the generated validate endpoint"
        )

      {:error, :enoent} ->
        # Typed finding instead of a raise: the audit fails closed on the
        # finding, it does not crash on the absent reference.
        [
          "rpc alignment: lib/xaas_web/router.ex absent — reference stale or module never landed"
          | failures
        ]
    end
  end

  defp tracked_files! do
    case System.cmd("git", ["ls-files", "-z"], stderr_to_stdout: true) do
      {output, 0} -> String.split(output, "\0", trim: true)
      {output, status} -> Mix.raise("git ls-files failed exit=#{status}: #{String.trim(output)}")
    end
  end

  defp text_file?(path) do
    Path.extname(path) in @text_extensions or Path.basename(path) in ["Dockerfile", "VERSION"]
  end

  defp external_or_anchor?(target) do
    target == "" or
      String.starts_with?(target, ["#", "/", "http://", "https://", "mailto:", "tel:", "data:"])
  end

  defp require_true(failures, true, _message), do: failures
  defp require_true(failures, false, message), do: [message | failures]
end
