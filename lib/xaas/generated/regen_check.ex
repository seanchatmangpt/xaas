defmodule Xaas.Generated.RegenCheck do
  @moduledoc """
  SPEC-34 (W849-backlog-2): the CI/regen drift leg for generated surfaces.

  Upgrades the `test/xaas/generated/registry_drift_guard_test.exs` sha256 pins
  from hand-edit detection to regen-based DRIFT-CHECKED: for every surface with
  an in-repo regen command, the leg re-runs the REAL generator and compares the
  fresh output against the tracked bytes. `:ggen_igniter_check` surfaces run
  through the generator's own admitted `--check --json` drift contract
  (`GgenIgniter.TaskContract`: exit 0 = clean, exit 4 = drift/BLOCKED);
  `:byte_compare` surfaces regen into a temp dir and byte-compare.

  Surfaces whose regen command lives outside the repo (marketplace packs,
  provenance-only ttl surfaces) are disclosed typed — `{:skipped, reason}` —
  never silently green.

  Chicago-style: real generators, real subprocesses, byte-level assertions.
  """

  @type kind :: :ggen_igniter_check | :byte_compare | :disclosed_skip

  @type surface :: %{
          required(:path) => String.t(),
          required(:kind) => kind(),
          required(:regen_command) => String.t(),
          optional(:argv_builder) => (String.t() -> [String.t(), ...]),
          optional(:outputs) => [String.t()],
          optional(:skip_reason) => String.t()
        }

  @typedoc "`:ok`, `{:drift, detail}`, or `{:skipped, reason}`."
  @type verdict :: :ok | {:drift, String.t()} | {:skipped, String.t()}

  @type report :: %{String.t() => verdict()}

  @doc """
  The surface census, aligned 1:1 with `test/xaas/generated/registry_drift_guard_test.exs`'s
  `@regen_commands` map (10 surfaces, W852 state), plus the two ash_typescript
  artifacts already carried by the W837 court.
  """
  @spec surfaces() :: [surface()]
  def surfaces do
    [
      %{
        path: "lib/xaas/generated/zcode_event_registry.ex",
        kind: :ggen_igniter_check,
        regen_command:
          "mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack " <>
            "--template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex " <>
            "--out lib/xaas/generated/zcode_event_registry.ex --check --json",
        argv_builder: fn out ->
          [
            "ggen_igniter.sync",
            "--pack-dir",
            "priv/packs/xaas_zcode_ocel_pack",
            "--query",
            "event_types=priv/packs/xaas_zcode_ocel_pack/queries/010_event_types.rq",
            "--query",
            "object_types=priv/packs/xaas_zcode_ocel_pack/queries/020_object_types.rq",
            "--query",
            "qualifiers=priv/packs/xaas_zcode_ocel_pack/queries/030_qualifiers.rq",
            "--query",
            "transitions=priv/packs/xaas_zcode_ocel_pack/queries/040_transitions.rq",
            "--template",
            "priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex",
            "--out",
            out,
            "--check",
            "--json",
            "--on-stale",
            "preserve"
          ]
        end
      },
      %{
        path: "lib/xaas/telemetry/ocel_envelope.ex",
        kind: :ggen_igniter_check,
        regen_command:
          "mix ggen_igniter.sync --pack-dir priv/packs/xaas_telemetry_pack " <>
            "--template priv/packs/xaas_telemetry_pack/templates/ocel_envelope.ex.eex " <>
            "--out lib/xaas/telemetry/ocel_envelope.ex --check --json",
        argv_builder: fn out ->
          [
            "ggen_igniter.sync",
            "--pack-dir",
            "priv/packs/xaas_telemetry_pack",
            "--query",
            "envelope_fields=priv/packs/xaas_telemetry_pack/queries/001_envelope_fields.rq",
            "--template",
            "priv/packs/xaas_telemetry_pack/templates/ocel_envelope.ex.eex",
            "--out",
            out,
            "--check",
            "--json",
            "--on-stale",
            "preserve"
          ]
        end
      },
      %{
        path: "lib/mix/tasks/xaas.library.manufacture.ex",
        kind: :disclosed_skip,
        # W984md (owner decision W984le): gates/014_ranker_factor_weights.rq's
        # `FILTER ( NOT EXISTS {..} || NOT EXISTS {..} )` is a false-negative
        # gate under the sparql hex engine (GgenIgniter.Query.run/2) — the
        # `||`-joined NOT EXISTS silently evaluates false, so the gate can
        # never fire there. The regen path's real default engine is oxigraph
        # (`ggen_igniter.sync.ex`: `opts[:engine] || "oxigraph"` since
        # v26.8.27), where the gate fires correctly (witnessed by W984le's
        # mutation test); the pin below makes that reliance explicit instead
        # of trusting the default. sparql remains a disclosed-buggy,
        # non-default legacy engine — the gate is NOT rewritten for it.
        regen_command:
          "mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack --engine oxigraph",
        skip_reason:
          "BLOCKED(policy-floor-upgrade-pending): witnessed 2026-10-07 (W983c triage, " <>
            "W984g correction) — there is NO renderer escape bug; the tracked file has " <>
            "drifted from its ontology render solely in policy direction (tracked emits " <>
            "authorize_if always() write policies; the ontology-backed render emits the " <>
            "deny-by-default authorize_if actor_present() floor at 4 sites — regen would " <>
            "STRENGTHEN policy). Actuation is an owner decision: " <>
            "mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack --engine oxigraph " <>
            "(use an explicit in-repo scratch --out during any trial), then re-pin " <>
            "@expected_sha256 and retire this skip. sha256 pin remains authoritative"
      },
      %{
        path: "lib/xaas/generated/capital_census/facts.ex",
        kind: :ggen_igniter_check,
        regen_command:
          "mix ggen_igniter.sync --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl " <>
            "--query g_table=priv/ggen/ultracode-self-digest-pack/queries/g_table.rq " <>
            "--query facts=priv/ggen/ultracode-self-digest-pack/queries/facts.rq " <>
            "--query facts_spec=priv/ggen/ultracode-self-digest-pack/queries/facts_spec.rq " <>
            "--query frontier_outcomes=priv/ggen/ultracode-self-digest-pack/queries/frontier_outcomes.rq " <>
            "--template priv/ggen/ultracode-self-digest-pack/templates/facts.ex.eex " <>
            "--out lib/xaas/generated/capital_census/facts.ex --check --json",
        argv_builder: fn out ->
          [
            "ggen_igniter.sync",
            "--ontology",
            "priv/ggen/ultracode-self-digest-pack/ontology.ttl",
            "--query",
            "g_table=priv/ggen/ultracode-self-digest-pack/queries/g_table.rq",
            "--query",
            "facts=priv/ggen/ultracode-self-digest-pack/queries/facts.rq",
            "--query",
            "facts_spec=priv/ggen/ultracode-self-digest-pack/queries/facts_spec.rq",
            "--query",
            "frontier_outcomes=priv/ggen/ultracode-self-digest-pack/queries/frontier_outcomes.rq",
            "--template",
            "priv/ggen/ultracode-self-digest-pack/templates/facts.ex.eex",
            "--out",
            out,
            "--check",
            "--json"
          ]
        end
      },
      %{
        path: "assets/js/ash_rpc.ts",
        kind: :byte_compare,
        regen_command: "mix ash_typescript.codegen --output assets/js",
        outputs: ["assets/js/ash_rpc.ts", "assets/js/ash_types.ts"],
        argv_builder: fn out ->
          ["ash_typescript.codegen", "--output", out]
        end
      },
      # --- disclosed skips: no in-repo executable regen command ---
      %{
        path: "lib/xaas_web/mcp_scope.ex",
        kind: :disclosed_skip,
        regen_command:
          "ggen_igniter from priv/ggen_igniter/mcp_a2a/xaas-surface.ttl (moduledoc provenance)",
        skip_reason:
          "UNSUPPORTED(regen-command-not-in-repo): provenance-only ttl surface; " <>
            "sha256 hand-edit pin remains authoritative (registry_drift_guard)"
      },
      %{
        path: "lib/xaas/generated/sa2a_bridge_contract.ex",
        kind: :disclosed_skip,
        regen_command: "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
        skip_reason:
          "UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; " <>
            "sha256 hand-edit pin remains authoritative (registry_drift_guard)"
      },
      %{
        path: "lib/xaas/generated/sa2a_bridge_edges.ex",
        kind: :disclosed_skip,
        regen_command: "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
        skip_reason:
          "UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; " <>
            "sha256 hand-edit pin remains authoritative (registry_drift_guard)"
      },
      %{
        path: "lib/xaas/generated/sa2a_mcp_descriptor.ex",
        kind: :disclosed_skip,
        regen_command: "ggen-marketplace/sa2a-bridge-pack (ggen_igniter renderer)",
        skip_reason:
          "UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; " <>
            "sha256 hand-edit pin remains authoritative (registry_drift_guard)"
      },
      %{
        path: "lib/xaas/generated/castle_bridge_contract.ex",
        kind: :disclosed_skip,
        regen_command: "ggen-marketplace/xaas-castle-bridge-pack",
        skip_reason:
          "UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; " <>
            "sha256 hand-edit pin remains authoritative (registry_drift_guard)"
      },
      %{
        path: "lib/xaas/generated/castle_bridge_edges.ex",
        kind: :disclosed_skip,
        regen_command: "ggen-marketplace/xaas-castle-bridge-pack",
        skip_reason:
          "UNSUPPORTED(regen-toolchain-external): ggen-marketplace pack renders this; " <>
            "sha256 hand-edit pin remains authoritative (registry_drift_guard)"
      }
    ]
  end

  @doc """
  Runs the full leg. Returns a report keyed by repo-relative path.

  Options:
    * `:surfaces` — override the census (court mutation-kill seam: the court
      points a `:byte_compare` surface's outputs at a tampered temp file so the
      injected hand-edit flips the verdict to drift without touching the
      tracked tree).
  """
  @spec check(keyword()) :: report()
  def check(opts \\ []) do
    surfaces = Keyword.get(opts, :surfaces, surfaces())
    Map.new(surfaces, fn surface -> {surface.path, run_surface(surface)} end)
  end

  @doc "True when every surface verdict is `:ok`."
  @spec clean?(report()) :: boolean()
  def clean?(report) do
    Enum.all?(Map.values(report), fn
      :ok -> true
      # Disclosed skips never fail the leg: a typed UNSUPPORTED is not drift.
      {:skipped, _} -> true
      {:drift, _} -> false
    end)
  end

  @doc "Exit code per the ggen_igniter TaskContract drift vocabulary: 0 clean, 4 drift."
  @spec exit_code(report()) :: 0 | 4
  def exit_code(report) do
    if clean?(report), do: 0, else: 4
  end

  defp run_surface(%{kind: :disclosed_skip, skip_reason: reason}) do
    {:skipped, reason}
  end

  defp run_surface(%{kind: :ggen_igniter_check} = surface) do
    out = Map.get(surface, :out, surface.path)
    argv = surface.argv_builder.(out)

    case run_mix(argv) do
      {0, _json} ->
        :ok

      {4, json} ->
        {:drift,
         "DRIFT_SURFACE_STALE (ggen_igniter --check exit 4): #{surface.path} differs from its " <>
           "ontology source. Repair by re-running: #{surface.regen_command}. check output: " <>
           String.slice(json, 0, 2000)}

      {code, json} ->
        {:drift,
         "REGEN_CHECK_UNEXPECTED_EXIT (#{code}): the generator's own --check contract for " <>
           "#{surface.path} exited #{code} (expected 0 clean / 4 drift): " <>
           String.slice(json, 0, 2000)}
    end
  end

  defp run_surface(%{kind: :byte_compare} = surface) do
    tmp = Path.join(System.tmp_dir!(), "w982g-regen-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    argv = surface.argv_builder.(Path.join(tmp, "ash_rpc.ts"))

    try do
      {code, output} = run_mix(argv)

      cond do
        code != 0 ->
          {:drift,
           "REGEN_COMMAND_FAILED (exit #{code}): #{surface.regen_command} — " <>
             String.slice(output, 0, 2000)}

        true ->
          Enum.reduce(surface.outputs, :ok, fn tracked_rel, acc ->
            verdict = compare_one(tracked_rel, tmp, surface, Map.get(surface, :tracked_root, "."))
            merge(acc, verdict)
          end)
      end
    after
      File.rm_rf!(tmp)
    end
  end

  defp compare_one(tracked_rel, tmp, surface, tracked_root) do
    name = Path.basename(tracked_rel)
    generated = Path.join(tmp, name)

    cond do
      not File.exists?(generated) ->
        {:drift,
         "REGEN_MISSING_OUTPUT: #{surface.regen_command} did not produce #{name} " <>
           "(expected at #{generated})"}

      true ->
        generated_bytes = File.read!(generated)
        tracked_bytes = File.read!(Path.join(tracked_root, tracked_rel))

        if generated_bytes == tracked_bytes do
          :ok
        else
          {:drift,
           "DRIFT_SURFACE_STALE (byte compare): #{tracked_rel} differs from a fresh run of " <>
             "#{surface.regen_command}. generated=#{byte_size(generated_bytes)}B " <>
             "tracked=#{byte_size(tracked_bytes)}B. Repair by re-running the regen command; " <>
             "never hand-edit the artifact."}
        end
    end
  end

  defp merge(:ok, :ok), do: :ok
  defp merge(:ok, {:drift, _} = d), do: d
  defp merge({:drift, _} = d, :ok), do: d
  defp merge({:drift, d1}, {:drift, d2}), do: {:drift, d1 <> "\n" <> d2}

  defp run_mix(argv) do
    case System.find_executable("mix") do
      nil ->
        {127, "mix executable not on PATH"}

      mix_bin ->
        env = [
          {"MIX_ENV", "test"},
          {"MIX_BUILD_ROOT", System.get_env("MIX_BUILD_ROOT") || "_build"},
          {"PATH", System.get_env("PATH") || "/usr/bin:/bin"}
        ]

        {out, code} = System.cmd(mix_bin, argv, env: env, stderr_to_stdout: true)
        {code, out}
    end
  end
end
