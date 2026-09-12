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

  @version "26.8.21"
  @domains [
    Xaas.Accounts,
    Xaas.Billing,
    Xaas.Governance,
    Xaas.Ledger,
    Xaas.Marketplace,
    Xaas.Operations,
    Xaas.Platform
  ]
  @resource_counts %{
    Xaas.Accounts => 5,
    Xaas.Billing => 7,
    Xaas.Governance => 27,
    Xaas.Ledger => 4,
    Xaas.Marketplace => 2,
    Xaas.Operations => 18,
    Xaas.Platform => 7
  }
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
          "XAAS_RELEASE_AUDIT ALIVE version=#{@version} tracked_files=#{length(files)} ash_resources=70"
        )

      failures ->
        Enum.each(failures, &Mix.shell().error("REFUSED[RELEASE_AUDIT] #{&1}"))
        Mix.raise("v#{@version} release audit failed with #{length(failures)} finding(s)")
    end
  end

  defp check_version(failures) do
    version_file = File.read!("VERSION") |> String.trim()
    mix_version = Mix.Project.config()[:version]

    failures
    |> require_true(version_file == @version, "VERSION=#{inspect(version_file)} expected #{@version}")
    |> require_true(mix_version == @version, "Mix version=#{inspect(mix_version)} expected #{@version}")
  end

  defp check_runtime_identity(failures) do
    tool_versions = File.read!(".tool-versions")
    dockerfile = File.read!("Dockerfile")

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
    configured = Application.fetch_env!(:kanban, :ash_domains)
    actual_counts = Map.new(@domains, &{&1, length(Ash.Domain.Info.resources(&1))})
    resources = Enum.flat_map(@domains, &Ash.Domain.Info.resources/1)

    failures
    |> require_true(configured == @domains, "configured Ash domains differ from canonical seven-domain order")
    |> require_true(actual_counts == @resource_counts, "Ash resource counts drifted: #{inspect(actual_counts)}")
    |> require_true(length(resources) == 70, "expected 70 domain resources, observed #{length(resources)}")
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

    source_modules =
      Path.wildcard("lib/xaas/**/*.ex")
      |> Enum.flat_map(fn path ->
        source = File.read!(path)

        if String.contains?(source, "use Xaas.Resource") do
          case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, source, capture: :all_but_first) do
            [module] -> [Module.concat([module])]
            _ -> []
          end
        else
          []
        end
      end)
      |> MapSet.new()

    missing = MapSet.difference(source_modules, registered) |> MapSet.to_list()
    absent_source = MapSet.difference(registered, source_modules) |> MapSet.to_list()

    failures
    |> require_true(missing == [], "Xaas.Resource modules missing from domains: #{inspect(missing)}")
    |> require_true(absent_source == [], "domain resources missing canonical source modules: #{inspect(absent_source)}")
  end

  defp check_migration_uniqueness(failures) do
    declarations =
      Path.wildcard("priv/repo/migrations/*.exs")
      |> Enum.flat_map(fn path ->
        up_source = path |> File.read!() |> String.split("def down do", parts: 2) |> hd()

        Regex.scan(~r/create\s+table\(:([a-zA-Z0-9_]+)/, up_source, capture: :all_but_first)
        |> Enum.map(fn [table] -> {table, path} end)
      end)

    duplicates =
      declarations
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_table, paths} -> length(Enum.uniq(paths)) > 1 end)

    require_true(failures, duplicates == [], "duplicate migration table creates: #{inspect(duplicates)}")
  end

  defp check_text_integrity(failures, files) do
    files
    |> Enum.filter(&text_file?/1)
    |> Enum.reduce(failures, fn path, acc ->
      case File.read(path) do
        {:ok, content} ->
          acc
          |> require_true(not String.contains?(content, "\0"), "NUL byte in tracked text file #{path}")
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
      case path |> File.read!() |> Jason.decode() do
        {:ok, _} -> acc
        {:error, error} -> ["invalid JSON #{path}: #{Exception.message(error)}" | acc]
      end
    end)
  end

  defp check_shell(failures, files) do
    files
    |> Enum.filter(&String.ends_with?(&1, ".sh"))
    |> Enum.reduce(failures, fn path, acc ->
      case System.cmd("bash", ["-n", path], stderr_to_stdout: true) do
        {_output, 0} -> acc
        {output, status} -> ["bash -n failed #{path} exit=#{status}: #{String.trim(output)}" | acc]
      end
    end)
  end

  defp check_markdown_links(failures, files) do
    files
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.reduce(failures, fn path, acc ->
      source = File.read!(path)

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
    end)
  end

  defp check_stale_claims(failures, files) do
    files
    |> Enum.filter(&text_file?/1)
    |> Enum.reject(&(&1 == "lib/mix/tasks/xaas.release_audit.ex"))
    |> Enum.reduce(failures, fn path, acc ->
      source = File.read!(path)

      Enum.reduce(@stale_claims, acc, fn {label, pattern}, inner_acc ->
        require_true(inner_acc, not Regex.match?(pattern, source), "#{label} remains in #{path}")
      end)
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
    |> require_true(
      String.contains?(File.read!(architecture), "**70**"),
      "architecture overview does not carry the canonical 70-resource total"
    )
  end

  defp check_rpc_alignment(failures) do
    config = File.read!("config/config.exs")
    router = File.read!("lib/kanban_web/router.ex")

    failures
    |> require_true(
      String.contains?(config, ~s(run_endpoint: "/internal-api/rpc/run")),
      "AshTypescript run endpoint is not canonical"
    )
    |> require_true(
      String.contains?(config, ~s(validate_endpoint: "/internal-api/rpc/validate")),
      "AshTypescript validate endpoint is not canonical"
    )
    |> require_true(
      String.contains?(router, ~s(post "/rpc/run", AshTypescriptRpcController, :run)),
      "Phoenix router does not mount the generated run endpoint"
    )
    |> require_true(
      String.contains?(router, ~s(post "/rpc/validate", AshTypescriptRpcController, :validate)),
      "Phoenix router does not mount the generated validate endpoint"
    )
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
